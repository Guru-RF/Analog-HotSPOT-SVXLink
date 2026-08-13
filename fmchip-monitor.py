#!/usr/bin/python3
#
# fmchip-monitor — workaround for a firmware bug on SA818 v1.0 chips
# that sometimes leaves the audio path in a bad state after a
# transmit. The workaround is to re-issue chip configuration whenever
# svxlink logs "Turning the transmitter OFF", which "pokes" the chip
# out of the bad state.
#
# fmchip-monitor is enabled ONLY on chips whose sa818-version reports
# exact name "SA818" at firmware V1.0 (see the fmchip-monitor enable
# gate in hotspot-config-online chip-detect block). SA818PRO and
# SA868 don't need it.
#
# We re-apply the `sa818 … filters …` line from /usr/sbin/hotspot
# VERBATIM — not a hardcoded value. An older version of this script
# unconditionally issued `filters --emphasis disable --highpass
# disable --lowpass disable` on every TX-off, which happened to match
# the old default for non-DTMF non-4th-gen boxes but silently
# destroyed the emphasis chain in the new DTMF-mode design (where
# hotspot-config-online writes chip filters ENABLED and svxlink
# DEEMPHASIS=0/PREEMPHASIS=0 — the chip then does emphasis and
# svxlink stays out of the audio path). Force-disabling chip filters
# in that mode leaves no emphasis anywhere in the chain, producing
# flat/dead-toned RX audio that persists until reboot (svxlink only
# runs /usr/sbin/hotspot once via ExecStartPre).

import shlex
import subprocess

HOTSPOT_SCRIPT = "/usr/sbin/hotspot"


def _reset_chip():
    """Re-apply the configured `sa818 … filters …` line from
    /usr/sbin/hotspot. Any parse error or missing filter line falls
    back to running the whole hotspot script end-to-end — same
    chip-poke effect, always safe."""
    try:
        with open(HOTSPOT_SCRIPT) as fh:
            for raw in fh:
                stripped = raw.strip()
                if stripped.startswith("sa818 ") and " filters " in stripped:
                    subprocess.run(shlex.split(stripped))
                    return
    except Exception:
        pass
    subprocess.run([HOTSPOT_SCRIPT])


f = subprocess.Popen(
    ["tail", "-n", "0", "-F", "/var/log/svxlink"],
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)
while True:
    line = f.stdout.readline()
    if "Turning the transmitter OFF" in str(line):
        print("Reset FM Chip")
        _reset_chip()
