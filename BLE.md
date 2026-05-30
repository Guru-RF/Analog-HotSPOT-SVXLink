# HotSpot Bluetooth DTMF — BLE Protocol

Reference for building iOS / macOS / Android / Linux clients that talk to the
hotspot's Bluetooth DTMF service (`/usr/sbin/hotspot-bluetooth`, systemd unit
`hotspot-bluetooth.service`).

The service exposes two writable characteristics and two notify
characteristics:

- **DTMF** — turns a BLE write into `echo <payload> | nc -N 127.0.0.1 10000`
  on the hotspot, which is SVXLink's DTMF command socket.
- **Command** — a small fixed set of device-level actions (reboot, poweroff,
  start/stop svxlink, enable/disable the 4G uplink).
- **Status** — notify channel confirming DTMF/command writes.
- **Feed** — notify stream of the hotspot's live state (callsign, frequency,
  talkgroup, current / last talker, TX/RX flags). Built by tailing
  `/var/log/svxlink` inside `hotspot-bluetooth` itself, so it works on
  hotspots that don't have an OLED attached.

## Client-side tips for stability

- **Prefer write-without-response** for both the DTMF and command
  characteristics. Both advertise `write` and `write-without-response`; the
  phone can pick. With-response means the client waits for an ATT ACK and
  will drop the link if it doesn't come in time. Without-response is
  fire-and-forget — you still get your logical confirmation via the status
  notify.
- **Keep the status characteristic subscribed** for the lifetime of the
  connection. The server uses it to report results; re-subscribing on every
  write is wasted round-trips.
- **Don't open/close the GATT connection per command.** Connect once, keep
  it, write whenever. BLE connection setup is expensive (1–2 s) and some
  centrals rate-limit reconnections.
- On iOS, if the app is backgrounded without the `bluetooth-central`
  background mode, iOS will tear down the BLE connection with reason 0x13
  ("Remote User Terminated") — this looks like a server-side drop but it
  isn't.

## Transport

- **BLE GATT** (Bluetooth Low Energy). Not classic Bluetooth / RFCOMM / SPP.
  iOS only exposes BLE to non-MFi apps, so this is the only portable option.
- **No pairing / bonding required** by default. Link is open; anyone in radio
  range with the service UUID can write DTMF. Add `encrypt-write` /
  `encrypt-authenticated-write` flags on the write characteristic in
  `hotspot-bluetooth` if you want to force bonding.
- Advertised locally as the device hostname (truncated to 20 bytes).

## UUIDs

| Role | UUID | Properties |
| --- | --- | --- |
| Service | `6b1d6a10-c50f-4d86-a7f3-7f2a3a1b2c3d` | advertised |
| DTMF write | `6b1d6a11-c50f-4d86-a7f3-7f2a3a1b2c3d` | `write`, `write-without-response` |
| Status notify | `6b1d6a12-c50f-4d86-a7f3-7f2a3a1b2c3d` | `notify` |
| Command write | `6b1d6a13-c50f-4d86-a7f3-7f2a3a1b2c3d` | `write`, `write-without-response` |
| Feed notify | `6b1d6a14-c50f-4d86-a7f3-7f2a3a1b2c3d` | `notify` |

On iOS these become `CBUUID` values; on Android `UUID.fromString(...)`.

## Scanning / discovery

- **iOS / macOS (CoreBluetooth):** you must scan filtering by the service UUID
  (`centralManager.scanForPeripherals(withServices: [svcUUID], options: nil)`).
  The device will not appear in the system Bluetooth settings panel — that
  panel shows classic + HID devices, not GATT peripherals. Discovery happens
  inside your app.
- **Android (BluetoothLeScanner):** scan with a `ScanFilter` on the service
  UUID. Works from Android 5.0+. Needs runtime `BLUETOOTH_SCAN` +
  `BLUETOOTH_CONNECT` permissions on Android 12+.

## DTMF write characteristic

- UUID: `6b1d6a11-c50f-4d86-a7f3-7f2a3a1b2c3d`
- Properties: `write`, `write-without-response`
- Payload: ASCII string, e.g. `"91"`, `"D#"`, `"*1234"`.
- Allowed characters: `0-9`, `A-D`, `a-d`, `*`, `#`. Anything else → write
  fails with `org.bluez.Error.Failed` ("invalid DTMF characters").
- Max length: **64 bytes**. Longer writes are rejected.
- Leading/trailing whitespace is stripped server-side.
- An empty payload after stripping is silently ignored.

The server shells out to `/usr/sbin/hotspot_dtmf <payload>`, which pipes the
string into SVXLink's DTMF socket on `127.0.0.1:10000`. The whole payload is
handed to SVXLink at once, so multi-digit commands work as one sequence.

## Command write characteristic

Device-level actions beyond DTMF (power, service control, uplink switching).

- UUID: `6b1d6a13-c50f-4d86-a7f3-7f2a3a1b2c3d`
- Properties: `write`, `write-without-response`
- Payload: one of a fixed set of lowercase ASCII command names (whitespace
  stripped, case-insensitive). Anything else → write fails with
  `org.bluez.Error.Failed` ("unknown command").
- Max length: **64 bytes**.
- Result: notified on the status characteristic as `ok <name>` or
  `err <name> …`.

Accepted commands:

| Command | Effect | Notes |
| --- | --- | --- |
| `reboot` | `systemctl reboot` | notifies `ok reboot`, fires 1 s later so the notify flushes |
| `poweroff` | `systemctl poweroff` | same pattern as `reboot` |
| `svxlink-start` | `systemctl start svxlink` | synchronous |
| `svxlink-stop` | `systemctl stop svxlink` | synchronous |
| `svxlink-restart` | `systemctl restart svxlink` | synchronous |
| `4g-enable` | `systemctl start --no-block hotspot-4g` | returns immediately; 4G bring-up runs in the background |
| `4g-disable` | `systemctl stop hotspot-4g` + `ip link set wlan0 up` | brings Wi-Fi back up so you don't get locked out |

`reboot` and `poweroff` are "fire and forget" — the server notifies `ok <name>`
before actually exec'ing the action so the phone sees the acknowledgement.
After that the BLE link will drop; there is no "back online" notification,
the client has to re-scan when the device comes back.

## Status notify characteristic

- UUID: `6b1d6a12-c50f-4d86-a7f3-7f2a3a1b2c3d`
- Properties: `notify`
- Subscribe to receive confirmation of each write on either the DTMF or
  command characteristic.
- Payload: UTF-8 text, ≤512 bytes. Examples:
  - `ok 91` — DTMF accepted, helper exited 0
  - `ok reboot` — command accepted (link will drop shortly)
  - `ok svxlink-restart` — command completed successfully
  - `err rc=1 <stderr>` — DTMF helper returned non-zero
  - `err timeout` — helper did not finish within 5 s
  - `err unknown <name>` — command not in the whitelist
  - `err <name> rc=N <stderr>` — command failed
  - `err <repr of exception>` — unexpected failure

The notify stream is a server → client confirmation channel only. Nothing is
pushed unless the client has a pending `CCCD` subscription.

## Feed notify characteristic

Live snapshot of what the hotspot is doing — the same information the OLED
would show, streamed as JSON. Works even on units that have no OLED.

- UUID: `6b1d6a14-c50f-4d86-a7f3-7f2a3a1b2c3d`
- Properties: `notify`
- Payload: one compact JSON object per notification, no trailing newline,
  UTF-8. Fields:

  | Key | Type | Meaning |
  | --- | --- | --- |
  | `ip` | string | device's outbound IP (best-effort) |
  | `cs` | string | callsign from `/etc/svxlink/svxlink.conf` |
  | `fq` | string | frequency parsed from `/usr/sbin/hotspot` |
  | `tg` | string | current talkgroup number |
  | `tk` | string | callsign of the active talker (empty if none) |
  | `ltk` | string | callsign of the last talker that finished |
  | `tx` | 0 / 1 | SVXLink transmitter on |
  | `rx` | 0 / 1 | local squelch open (RF carrier present) |
  | `sg` | int / 0 / null | 4G signal in dBm (Current / RSSI from `qmicli --nas-get-signal-strength`). Tri-state — see below. |
  | `rf` | string | SVXLink reflector domain (`DNS_DOMAIN` from svxlink.conf), e.g. `be.svx.link` |
  | `mt` | string | Monitored talkgroups (`MONITOR_TGS`), raw — e.g. `8++, 23+, 50, 51, 52, 53, 54, 55`. `+` suffixes are SVXLink priority levels. |
  | `ct` | string | Switchable talkgroups via CTCSS tone (`CTCSS_TO_TG`), raw — e.g. `67.0:8400,69.3:8,71.9:23,74.4:9000`. Format is `tone:tg,tone:tg,…` |

  `sg` semantics, so the app can tell "no modem" apart from "modem but no signal":

  | Value | Meaning | Suggested UI |
  | --- | --- | --- |
  | `null` (JSON null) | no 4G hardware on this hotspot (`/dev/cdc-wdm0` missing, qmicli not installed) | hide the 4G section entirely |
  | `0` | 4G hardware present but not registered, qmicli timed out, or output unparseable | show "no signal" / "searching" |
  | negative int (e.g. `-78`) | live signal in dBm | render bars from value |

  Example with 4G online:

  ```json
  {"ip":"10.0.0.42","cs":"ON7F","fq":"434.200","tg":"91","tk":"PD0CWM","ltk":"PD0CWM","tx":1,"rx":0,"sg":-78,"rf":"be.svx.link","mt":"8++, 23+, 50, 51","ct":"67.0:8400,69.3:8,71.9:23"}
  ```

  Example with no 4G module installed:

  ```json
  {"ip":"10.0.0.42","cs":"ON7F","fq":"434.200","tg":"91","tk":"","ltk":"","tx":0,"rx":0,"sg":null,"rf":"be.svx.link","mt":"8++, 23+, 50, 51","ct":"67.0:8400,69.3:8,71.9:23"}
  ```

  Note: `mt` and `ct` are read once from `/etc/svxlink/svxlink.conf` at
  service start. After running `hotspot-config` to change them, restart
  `hotspot-bluetooth` (or reboot) for the new values to appear on the
  feed. The auto-update flow in `hotspot-config-online` already ends
  with a reboot, so no extra step needed there.

  Rough buckets the app can use for a "bars" indicator:

  | dBm range | Signal |
  | --- | --- |
  | ≥ −70 | excellent |
  | −70 … −85 | good |
  | −85 … −100 | fair |
  | −100 … −110 | weak |
  | < −110 | very poor / unreliable |

  Note: `sg` is the modem's `Current` / `RSSI` reading (general signal), not
  LTE `RSRP`. RSRP runs ~30 dB lower than RSSI on LTE and would make a
  perfectly fine link look poor in a "bars" UI. Read via `qmicli -p` so it
  shares the modem cleanly with `hotspot-4g` (which holds a CID with
  `--client-no-release-cid`).

- Cadence: one notification on every state change, plus a keepalive every
  ~3 s even when nothing changed. Subscribing immediately replays the last
  known snapshot so the UI is never blank after a reconnect.

### MTU — important for the feed

The feed payload is typically 90–140 bytes. BLE's default ATT MTU is 23
bytes (20 bytes of payload), which would truncate it.

- **iOS / macOS** — CoreBluetooth auto-negotiates MTU ≈ 185. No action needed.
- **Web Bluetooth** — negotiates MTU 247 automatically. No action needed.
- **Android** — defaults to 23. **Immediately after `onServicesDiscovered`,
  call `gatt.requestMtu(247)`** and wait for `onMtuChanged` before
  subscribing to the feed characteristic. Without this, every feed
  notification arrives truncated.

## Example session

1. Client scans filtering for `6b1d6a10-...`, finds the hostname advertisement.
2. Client connects, discovers services, finds the DTMF service.
3. Client subscribes (enables notifications) on the status characteristic.
4. Client writes bytes `0x39 0x31` (`"91"`) to the write characteristic.
5. Server forwards `91` to SVXLink, then notifies `ok 91`.
6. Repeat step 4 for the next command. The link can stay connected for a
   conversation's worth of commands.

## iOS / Swift sketch

```swift
import CoreBluetooth

let svcUUID     = CBUUID(string: "6b1d6a10-c50f-4d86-a7f3-7f2a3a1b2c3d")
let writeUUID   = CBUUID(string: "6b1d6a11-c50f-4d86-a7f3-7f2a3a1b2c3d")
let statusUUID  = CBUUID(string: "6b1d6a12-c50f-4d86-a7f3-7f2a3a1b2c3d")
let commandUUID = CBUUID(string: "6b1d6a13-c50f-4d86-a7f3-7f2a3a1b2c3d")

// In centralManagerDidUpdateState(.poweredOn):
central.scanForPeripherals(withServices: [svcUUID])

// After connect + discovery, assume `writeChar`, `commandChar` and
// `statusChar` are located:
peripheral.setNotifyValue(true, for: statusChar)

func sendDTMF(_ s: String) {
    guard let data = s.data(using: .ascii) else { return }
    // .withoutResponse is fastest; use .withResponse to get a CB ack.
    peripheral.writeValue(data, for: writeChar, type: .withoutResponse)
}

func sendCommand(_ name: String) {
    // name ∈ reboot, poweroff, svxlink-start, svxlink-stop,
    //        svxlink-restart, 4g-enable, 4g-disable
    guard let data = name.data(using: .ascii) else { return }
    peripheral.writeValue(data, for: commandChar, type: .withoutResponse)
}

// peripheral(_:didUpdateValueFor:error:) on statusChar delivers the "ok …" / "err …" string.
```

Add `NSBluetoothAlwaysUsageDescription` to `Info.plist`.

## Android / Kotlin sketch

```kotlin
val svcUUID     = UUID.fromString("6b1d6a10-c50f-4d86-a7f3-7f2a3a1b2c3d")
val writeUUID   = UUID.fromString("6b1d6a11-c50f-4d86-a7f3-7f2a3a1b2c3d")
val statusUUID  = UUID.fromString("6b1d6a12-c50f-4d86-a7f3-7f2a3a1b2c3d")
val commandUUID = UUID.fromString("6b1d6a13-c50f-4d86-a7f3-7f2a3a1b2c3d")

val filter = ScanFilter.Builder().setServiceUuid(ParcelUuid(svcUUID)).build()
scanner.startScan(listOf(filter), ScanSettings.Builder().build(), scanCallback)

// After connectGatt + discoverServices:
val svc     = gatt.getService(svcUUID)
val write   = svc.getCharacteristic(writeUUID)
val command = svc.getCharacteristic(commandUUID)
val status  = svc.getCharacteristic(statusUUID)

gatt.setCharacteristicNotification(status, true)
val cccd = status.getDescriptor(UUID.fromString("00002902-0000-1000-8000-00805f9b34fb"))
cccd.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
gatt.writeDescriptor(cccd)

fun sendDTMF(s: String) {
    write.writeType = BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
    write.value = s.toByteArray(Charsets.US_ASCII)
    gatt.writeCharacteristic(write)
}

fun sendCommand(name: String) {
    // name ∈ reboot, poweroff, svxlink-start, svxlink-stop,
    //        svxlink-restart, 4g-enable, 4g-disable
    command.writeType = BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
    command.value = name.toByteArray(Charsets.US_ASCII)
    gatt.writeCharacteristic(command)
}
// onCharacteristicChanged(statusChar) → String(value, US_ASCII) == "ok …" / "err …"
```

Manifest: `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT` (Android 12+);
`ACCESS_FINE_LOCATION` on older versions.

## Debugging on the hotspot

```sh
systemctl status hotspot-bluetooth
journalctl -u hotspot-bluetooth -f

# Send a DTMF write from another Linux box for sanity:
gatttool -b <MAC> -I
> connect
> char-write-req <write-handle> 3931     # "91" in hex
```

Or use [nRF Connect](https://www.nordicsemi.com/Products/Development-tools/nRF-Connect-for-mobile)
on iOS / Android — scan, connect, write, observe notifications. No app code
required for a round-trip test.

## Security considerations

- Both write characteristics are open by default. Anyone in radio range with
  the service UUID can send DTMF **or** issue `reboot` / `poweroff` /
  `4g-disable`. If the hotspot is mobile / in public, switch the
  characteristic flags in `hotspot-bluetooth` to
  `encrypt-authenticated-write` and bond the phone.
- Server-side validation:
  - **DTMF char** restricts payload chars to `0-9 A-D a-d * #`.
  - **Command char** is a strict whitelist (`reboot`, `poweroff`,
    `svxlink-start`, `svxlink-stop`, `svxlink-restart`, `4g-enable`,
    `4g-disable`); anything else is rejected with `err unknown`.
  In neither case can the wire inject arbitrary shell or network traffic.
- `hotspot-bluetooth` runs as root (needs the BlueZ system bus and
  `systemctl`). It does not expose anything beyond the two characteristic
  writes → DTMF socket / whitelisted systemctl paths.
