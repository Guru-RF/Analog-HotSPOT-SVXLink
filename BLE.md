# HotSpot Bluetooth DTMF — BLE Protocol

Reference for building iOS / macOS / Android / Linux clients that talk to the
hotspot's Bluetooth DTMF service (`/usr/sbin/hotspot-bluetooth`, systemd unit
`hotspot-bluetooth.service`).

The service exposes two writable characteristics:

- **DTMF** — turns a BLE write into `echo <payload> | nc -N 127.0.0.1 10000`
  on the hotspot, which is SVXLink's DTMF command socket.
- **Command** — a small fixed set of device-level actions (reboot, poweroff,
  start/stop svxlink, enable/disable the 4G uplink).

## Transport

- **BLE GATT** (Bluetooth Low Energy). Not classic Bluetooth / RFCOMM / SPP.
  iOS only exposes BLE to non-MFi apps, so this is the only portable option.
- **No pairing / bonding required** by default. Link is open; anyone in radio
  range with the service UUID can write DTMF. Add `encrypt-write` /
  `encrypt-authenticated-write` flags on the write characteristic in
  `hotspot-bluetooth` if you want to force bonding.
- Advertised locally as `HotSpot-<hostname>` (truncated to 20 bytes).

## UUIDs

| Role | UUID | Properties |
| --- | --- | --- |
| Service | `6b1d6a10-c50f-4d86-a7f3-7f2a3a1b2c3d` | advertised |
| DTMF write | `6b1d6a11-c50f-4d86-a7f3-7f2a3a1b2c3d` | `write`, `write-without-response` |
| Status notify | `6b1d6a12-c50f-4d86-a7f3-7f2a3a1b2c3d` | `notify` |
| Command write | `6b1d6a13-c50f-4d86-a7f3-7f2a3a1b2c3d` | `write`, `write-without-response` |

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

## Example session

1. Client scans filtering for `6b1d6a10-...`, finds `HotSpot-myhost`.
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
