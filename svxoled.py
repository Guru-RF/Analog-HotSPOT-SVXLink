#!/usr/bin/env python3
"""
SVXLink OLED status UI (SSD1306)

OPERATION layout:
TOP:    USERCALL               FREQ
        -----------------------------
MID:    ANNOUNCE  OR  TG (left) + TALKER (right; scrolls if too long)
        -----------------------------
BOTTOM: RX|TX                  LASTCALL

Startup screen:
- IP centered (top)
- RF-Guru centered (big)
- ----------- (same length as the RF-Guru / HotSPOT word width)
- HotSPOT centered (big, bottom)

Rules:
- ANNOUNCE only if TX stays ON for >= ANNOUNCE_GRACE seconds and no talker starts
- No ANNOUNCE during talker (incl. talker hangtime)
- No ANNOUNCE for POST_TALKER_SUPPRESS seconds after talker stops (tail TX)
- Drain log lines each loop to avoid intermediate redraw states

Extras:
- Detect local squelch OPEN/CLOSED from log ("Rx1: The squelch is OPEN/CLOSED ...")
- When local squelch is OPEN: blink "RX-T" instead of "RX"
- Fix mid-line vertical alignment: scrolling and non-scrolling talker use the same Y anchor

Fixes added:
- Log rotation handling (rename+newfile AND copytruncate): reopen/seek as needed
- Talker hangtime (configurable): keep talker visible after "talker stop" to match audio buffer.
  Also: if TX goes OFF, clear talker immediately (guaranteed no one is talking).
"""

import time
import socket
import re
import os

from luma.core.interface.serial import i2c
from luma.oled.device import ssd1306
from PIL import Image, ImageDraw, ImageFont

# ---------- CONFIG ----------
LOGFILE = "/var/log/svxlink"

SVXLINK_CONF = "/etc/svxlink/svxlink.conf"
HOTSPOT_SCRIPT = "/usr/sbin/hotspot"

IDLE_DIM_TIME = 30.0
REDRAW_INTERVAL = 0.05
POLL_INTERVAL = 0.05
TX_BLINK_PERIOD = 0.5

BRIGHT_CONTRAST = 255
DIM_CONTRAST = 8

# ANNOUNCE timing
ANNOUNCE_GRACE = 1.0  # >= 1 seconds between TX ON and showing ANNOUNCE (if still no talker)
POST_TALKER_SUPPRESS = 2.5  # block ANNOUNCE during tail TX right after talker stop

# TALKER hangtime (UI only)
# Keeps the talker name on-screen a bit after "talker stop" (audio tail/buffer).
# If a new talker starts, hangtime is canceled immediately.
# If TX turns OFF, talker is cleared immediately.
TALKER_HANGTIME = 0.6  # seconds; tweak to taste (e.g. 0.3 .. 1.5)

# Scrolling (talker field only)
SCROLL_STEP_PX = 20
SCROLL_INTERVAL = 0.05
SCROLL_GAP_PX = 20

# Layout tweaks
MID_TEXT_Y_SHIFT = 4  # move TG+TALKER slightly higher within the mid band
ANNOUNCE_Y_SHIFT = 4  # move ANNOUNCE slightly higher within the mid band
DIVIDER_MARGIN = 1  # vertical spacing around divider lines

# Spleen fonts (pixel-perfect)
FONT_MONO = "/usr/share/fonts/opentype/spleen/spleen-8x16.otf"
FONT_BOLD = "/usr/share/fonts/opentype/spleen/spleen-12x24.otf"
FONT_MID = "/usr/share/fonts/opentype/spleen/spleen-16x32.otf"

# ---------- OLED ----------
serial = i2c(port=1, address=0x3C)
oled = ssd1306(serial, width=128, height=64)

# ---------- FONTS ----------
try:
    font_ui = ImageFont.truetype(FONT_MONO, 16)  # top + bottom lines + TG
    font_mid = ImageFont.truetype(FONT_MID, 32)  # talker / announce
    font_logo = ImageFont.truetype(FONT_BOLD, 24)  # startup logo text
    font_ip = ImageFont.truetype(FONT_MONO, 16)
except OSError:
    font_ui = font_mid = font_logo = font_ip = ImageFont.load_default()

# ---------- MID FONT METRICS (constant height anchor) ----------
_tmp_img = Image.new("1", (oled.width, oled.height))
_tmp_draw = ImageDraw.Draw(_tmp_img)
_mid_l, _mid_t, _mid_r, _mid_b = _tmp_draw.textbbox((0, 0), "Ag", font=font_mid)
MID_REF_H = _mid_b - _mid_t

# ---------- STATE ----------
state = {
    "ip": "0.0.0.0",
    "callsign": "---",
    "freq": "---",
    "tg": "",
    "active_call": "---",
    "last_call": "---",
    "tx_active": False,
    "blink_phase": 0,
    # local squelch open/close
    "local_rx_open": False,
    # ANNOUNCE control
    "announce_active": False,
    "announce_pending_until": 0.0,
    "suppress_announce_until": 0.0,
    "talker_active": False,
    # display / dim
    "started": False,
    "dirty": True,
    "dimmed": False,
    "last_activity": time.monotonic(),
    # talker scrolling (right field only)
    "talker_key": "",
    "talker_scroll_off": 0,
    "talker_scroll_last": 0.0,
    # talker UI hold
    "talker_hold_until": 0.0,
}

last_redraw = 0.0


# ---------- HELPERS ----------
def get_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "no-ip"


def read_callsign(conf_path: str) -> str:
    callsign = ""
    try:
        with open(conf_path, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                m = re.match(r'^\s*CALLSIGN\s*=\s*"?([^"\s]+)"?\s*$', line)
                if m:
                    callsign = m.group(1).strip()
    except Exception:
        return "---"
    return callsign or "---"


def read_frequency(script_path: str) -> str:
    try:
        with open(script_path, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                if "--frequency" in line:
                    m = re.search(r'--frequency\s+([0-9]+(?:\.[0-9]+)?)', line)
                    if m:
                        return m.group(1)
    except Exception:
        return "---"
    return "---"


def text_wh(draw, text, font):
    b = draw.textbbox((0, 0), text, font=font)
    return b[2] - b[0], b[3] - b[1]


def fit_text(draw, text, font, max_w):
    while text and text_wh(draw, text, font)[0] > max_w:
        text = text[:-1]
    return text or ""


def touch(now):
    state["last_activity"] = now
    if state["dimmed"]:
        oled.contrast(BRIGHT_CONTRAST)
        state["dimmed"] = False
    state["started"] = True
    state["dirty"] = True


def update_dim(now):
    if not state["dimmed"] and (now - state["last_activity"]) >= IDLE_DIM_TIME:
        oled.contrast(DIM_CONTRAST)
        state["dimmed"] = True


def mode_text():
    # TX has priority
    if state["tx_active"]:
        return "TX" if state["blink_phase"] == 0 else ""

    # local squelch open => blink RX-T
    if state["local_rx_open"]:
        return "RX-T" if state["blink_phase"] == 0 else ""

    return "RX"


# ---------- LOG FOLLOW (handles logrotate + copytruncate) ----------
def open_logfile(path: str, seek_end: bool) -> tuple:
    """
    Returns (fileobj, inode).
    seek_end=True for initial startup (tail).
    seek_end=False when a fresh file appears (post-rotate) so we don't miss early lines.
    """
    f = open(path, "r", encoding="utf-8", errors="replace")
    f.seek(0, 2 if seek_end else 0)
    ino = os.fstat(f.fileno()).st_ino
    return f, ino


def check_log_reopen(path: str, f, ino: int, *, on_rotate_seek_end: bool = False) -> tuple:
    """
    Detect:
      - rename/create rotation (inode change) => reopen
      - copytruncate (same inode, file shrank) => seek(0)
    Returns (f, ino, reopened_bool).
    """
    try:
        st = os.stat(path)
    except FileNotFoundError:
        # logrotate might briefly remove file; keep old handle and try again later
        return f, ino, False
    except Exception:
        return f, ino, False

    try:
        cur_pos = f.tell()
    except Exception:
        cur_pos = 0

    # inode changed => file was rotated (rename + new file created)
    if st.st_ino != ino:
        try:
            f.close()
        except Exception:
            pass
        try:
            nf, nino = open_logfile(path, seek_end=on_rotate_seek_end)
            return nf, nino, True
        except Exception:
            # if open fails, keep old f and retry next loop
            return f, ino, False

    # same inode but truncated (copytruncate)
    if st.st_size < cur_pos:
        try:
            f.seek(0, 0)
            return f, ino, True
        except Exception:
            return f, ino, False

    return f, ino, False


# ---------- DRAW ----------
def draw_startup(draw):
    # IP (top)
    ip = fit_text(draw, state["ip"], font_ip, oled.width)
    w_ip, _ = text_wh(draw, ip, font_ip)
    draw.text(((oled.width - w_ip) // 2, 0), ip, font=font_ip, fill=255)

    # RF-Guru (big)
    rf = "RF-Guru"
    w_rf, h_rf = text_wh(draw, rf, font_logo)
    x_rf = (oled.width - w_rf) // 2
    y_rf = 15
    draw.text((x_rf, y_rf), rf, font=font_logo, fill=255)

    # HotSPOT (big, bottom)
    hs = "HotSPOT"
    w_hs, h_hs = text_wh(draw, hs, font_logo)
    x_hs = (oled.width - w_hs) // 2
    y_hs = max(0, oled.height - h_hs - 10)
    draw.text((x_hs, y_hs), hs, font=font_logo, fill=255)

    # Divider line between RF-Guru and HotSPOT
    line_w = min(oled.width - 10, max(w_rf, w_hs))
    x1 = (oled.width - line_w) // 2 - 4
    x2 = x1 + line_w + 8

    rf_bottom = y_rf + h_rf
    hs_top = y_hs + 5
    y_line = (rf_bottom + hs_top) // 2

    y_line = min(max(0, y_line), oled.height - 1)
    draw.line((x1, y_line, x2, y_line), fill=255)


def text_bbox(draw, text, font):
    return draw.textbbox((0, 0), text, font=font)


def draw_talker_field(image, y_mid, mid_area_h, x0, avail_w, talker, now):
    """
    Draw TALKER right-field in font_mid inside [x0 .. x0+avail_w).
    If it fits: right-aligned. If not: scroll inside that region.

    Fixes:
    - Use bbox offsets in the strip to avoid clipped glyph pixels.
    - Use constant MID_REF_H for vertical centering so scrolling/non-scrolling sit at the same Y.
    """
    if avail_w <= 0:
        return

    d = ImageDraw.Draw(image)
    talker = talker or ""

    l, t, r, b = text_bbox(d, talker, font_mid)
    w_txt = r - l
    h_txt = b - t

    # Constant vertical anchor (prevents "scrolling sits higher")
    y_txt = y_mid + max(0, (mid_area_h - MID_REF_H) // 2 + MID_TEXT_Y_SHIFT)

    if w_txt <= avail_w:
        state["talker_scroll_off"] = 0
        x_bbox = x0 + (avail_w - w_txt)  # right-aligned bbox
        d.text((x_bbox - l, y_txt - t), talker, font=font_mid, fill=255)
        return

    # advance scroll
    if now - state["talker_scroll_last"] >= SCROLL_INTERVAL:
        state["talker_scroll_last"] = now
        state["talker_scroll_off"] = (state["talker_scroll_off"] + SCROLL_STEP_PX) % (w_txt + SCROLL_GAP_PX)
        state["dirty"] = True

    # render to strip using bbox offsets so nothing gets clipped
    strip_w = w_txt + SCROLL_GAP_PX + w_txt
    strip_h = max(1, h_txt)
    strip = Image.new("1", (strip_w, strip_h))
    sd = ImageDraw.Draw(strip)

    # place bbox at (0,0) => draw at (-l, -t)
    sd.text((-l, -t), talker, font=font_mid, fill=255)
    sd.text((w_txt + SCROLL_GAP_PX - l, -t), talker, font=font_mid, fill=255)

    off = state["talker_scroll_off"]
    view = strip.crop((off, 0, off + avail_w, strip_h))
    image.paste(view, (x0, y_txt))


def draw_screen(now):
    image = Image.new("1", oled.size)
    draw = ImageDraw.Draw(image)

    # STARTUP
    if not state["started"]:
        draw_startup(draw)
        oled.display(image)
        return

    # geometry
    top_h = text_wh(draw, "Ag", font_ui)[1]
    bot_h = text_wh(draw, "Ag", font_ui)[1]

    top_y = 0
    bottom_y = oled.height - bot_h - 2

    # divider lines (operation screen)
    line1_y = min(max(0, top_y + top_h + DIVIDER_MARGIN), oled.height - 1)
    line2_y = min(max(0, bottom_y - DIVIDER_MARGIN), oled.height - 1)

    # MID band area (between lines)
    mid_top = line1_y + 1 + DIVIDER_MARGIN
    mid_bottom = line2_y - 1 - DIVIDER_MARGIN
    mid_area_h = max(0, mid_bottom - mid_top)

    # TOP: callsign + freq
    cs = fit_text(draw, state["callsign"], font_ui, oled.width)
    fq = fit_text(draw, state["freq"], font_ui, oled.width)
    w_fq, _ = text_wh(draw, fq, font_ui)
    draw.text((0, top_y), cs, font=font_ui, fill=255)
    draw.text((oled.width - w_fq, top_y), fq, font=font_ui, fill=255)

    draw.line((0, line1_y, oled.width - 1, line1_y), fill=255)

    # MID: ANNOUNCE or TG(left) + TALKER(right; scroll)
    if state["announce_active"]:
        txt = "ANNOUNCE"
        l, t, r, b = text_bbox(draw, txt, font_mid)
        w_txt = r - l

        # same vertical anchor logic as talker
        y_txt = mid_top + max(0, (mid_area_h - MID_REF_H) // 2 + ANNOUNCE_Y_SHIFT)

        x_bbox = (oled.width - w_txt) // 2
        # bbox-anchored draw (matches talker behavior)
        draw.text((x_bbox - l, y_txt - t), txt, font=font_mid, fill=255)

    elif state["talker_active"] and state["active_call"] not in ("---", ""):
        tg = state["tg"] or ""
        w_tg, h_tg = text_wh(draw, tg, font_ui)
        y_tg = mid_top + max(0, (mid_area_h - h_tg) // 2 + MID_TEXT_Y_SHIFT)
        draw.text((0, y_tg), tg, font=font_ui, fill=255)

        spacing = 6 if tg else 0
        x0 = w_tg + spacing
        avail = oled.width - x0

        key = f"{tg}|{state['active_call']}"
        if key != state["talker_key"]:
            state["talker_key"] = key
            state["talker_scroll_off"] = 0
            state["talker_scroll_last"] = now
            state["dirty"] = True

        draw_talker_field(image, mid_top, mid_area_h, x0, avail, state["active_call"], now)

    draw.line((0, line2_y, oled.width - 1, line2_y), fill=255)

    # BOTTOM: RX/TX + lastcall
    mode = mode_text()
    draw.text((0, bottom_y), mode, font=font_ui, fill=255)

    last = fit_text(draw, state["last_call"], font_ui, oled.width)
    w_last, _ = text_wh(draw, last, font_ui)
    draw.text((oled.width - w_last, bottom_y), last, font=font_ui, fill=255)

    oled.display(image)


# ---------- MAIN ----------
def main():
    global last_redraw

    oled.contrast(BRIGHT_CONTRAST)
    state["ip"] = get_ip()
    state["callsign"] = read_callsign(SVXLINK_CONF)
    state["freq"] = read_frequency(HOTSPOT_SCRIPT)

    # Tail the current logfile on startup
    f, log_ino = open_logfile(LOGFILE, seek_end=True)

    while True:
        now = time.monotonic()

        # Blink phase during TX or local squelch-open
        if state["tx_active"] or state["local_rx_open"]:
            phase = int(now / TX_BLINK_PERIOD) & 1
            if phase != state["blink_phase"]:
                state["blink_phase"] = phase
                state["dirty"] = True
        else:
            if state["blink_phase"] != 0:
                state["blink_phase"] = 0
                state["dirty"] = True

        # Drain log lines
        had_line = False
        while True:
            line = f.readline()
            if not line:
                break
            had_line = True
            l = line.lower()

            # Local squelch open/close (exact wording from your logs)
            if "rx1: the squelch is open" in l:
                if not state["local_rx_open"]:
                    state["local_rx_open"] = True
                    touch(now)

            elif "rx1: the squelch is closed" in l:
                if state["local_rx_open"]:
                    state["local_rx_open"] = False
                    touch(now)

            if "selecting tg #" in l:
                m = re.search(r"tg\s*#(\d+)", l)
                if m and state["tg"] != m.group(1):
                    state["tg"] = m.group(1)
                    touch(now)

            if "talker start on tg #" in l:
                m = re.search(r"tg\s*#(\d+)", l)
                if m:
                    state["tg"] = m.group(1)

                state["active_call"] = line.rsplit(":", 1)[1].strip()
                state["talker_active"] = True
                state["talker_hold_until"] = 0.0  # cancel any pending clear

                state["announce_active"] = False
                state["announce_pending_until"] = 0.0
                touch(now)

            elif "talker stop on tg #" in l:
                # keep showing the talker for a bit (audio tail/buffer)
                if state["active_call"] not in ("---", ""):
                    state["last_call"] = state["active_call"]
                    state["talker_active"] = True
                    state["talker_hold_until"] = now + TALKER_HANGTIME
                else:
                    state["talker_hold_until"] = 0.0
                    state["talker_active"] = False

                # suppress ANNOUNCE during tail right after talker stop
                state["suppress_announce_until"] = now + POST_TALKER_SUPPRESS
                state["announce_active"] = False
                state["announce_pending_until"] = 0.0
                touch(now)

            elif "turning the transmitter on" in l:
                state["tx_active"] = True

                if (not state["talker_active"]) and (now >= state["suppress_announce_until"]):
                    state["announce_pending_until"] = now + ANNOUNCE_GRACE
                else:
                    state["announce_pending_until"] = 0.0
                    state["announce_active"] = False

                touch(now)

            elif "turning the transmitter off" in l:
                state["tx_active"] = False

                # guarantee: when TX is OFF, no one is talking -> clear talker immediately
                if state["active_call"] not in ("---", ""):
                    state["last_call"] = state["active_call"]
                state["active_call"] = "---"
                state["talker_active"] = False
                state["talker_hold_until"] = 0.0

                state["announce_active"] = False
                state["announce_pending_until"] = 0.0
                touch(now)

        # Handle logrotate/copytruncate (after draining, old FD can go quiet)
        f, log_ino, reopened = check_log_reopen(LOGFILE, f, log_ino, on_rotate_seek_end=False)
        if reopened:
            state["dirty"] = True

        if not had_line:
            time.sleep(POLL_INTERVAL)

        # Commit talker hangtime clear
        if state["talker_hold_until"] and now >= state["talker_hold_until"]:
            state["talker_hold_until"] = 0.0
            state["active_call"] = "---"
            state["talker_active"] = False
            state["dirty"] = True

        # Commit pending ANNOUNCE after grace period
        if state["announce_pending_until"] and now >= state["announce_pending_until"]:
            state["announce_pending_until"] = 0.0
            if state["tx_active"] and (not state["talker_active"]) and (now >= state["suppress_announce_until"]):
                state["announce_active"] = True
                state["dirty"] = True

        update_dim(now)

        if state["dirty"] and (now - last_redraw) > REDRAW_INTERVAL:
            draw_screen(now)
            state["dirty"] = False
            last_redraw = now


if __name__ == "__main__":
    main()
