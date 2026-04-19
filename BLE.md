# HotSpot Bluetooth DTMF — BLE Protocol

Reference for building iOS / macOS / Android / Linux clients that talk to the
hotspot's Bluetooth DTMF service (`/usr/sbin/hotspot-bluetooth`, systemd unit
`hotspot-bluetooth.service`).

The service turns a BLE write into `echo <payload> | nc -N 127.0.0.1 10000` on
the hotspot, which is SVXLink's DTMF command socket.

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
|---|---|---|
| Service | `6b1d6a10-c50f-4d86-a7f3-7f2a3a1b2c3d` | advertised |
| DTMF write | `6b1d6a11-c50f-4d86-a7f3-7f2a3a1b2c3d` | `write`, `write-without-response` |
| Status notify | `6b1d6a12-c50f-4d86-a7f3-7f2a3a1b2c3d` | `notify` |

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

## Status notify characteristic

- UUID: `6b1d6a12-c50f-4d86-a7f3-7f2a3a1b2c3d`
- Properties: `notify`
- Subscribe to receive confirmation of each write.
- Payload: UTF-8 text, ≤512 bytes. Examples:
  - `ok 91` — command accepted, helper exited 0
  - `err rc=1 <stderr>` — helper returned non-zero
  - `err timeout` — helper did not finish within 5 s
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

let svcUUID    = CBUUID(string: "6b1d6a10-c50f-4d86-a7f3-7f2a3a1b2c3d")
let writeUUID  = CBUUID(string: "6b1d6a11-c50f-4d86-a7f3-7f2a3a1b2c3d")
let statusUUID = CBUUID(string: "6b1d6a12-c50f-4d86-a7f3-7f2a3a1b2c3d")

// In centralManagerDidUpdateState(.poweredOn):
central.scanForPeripherals(withServices: [svcUUID])

// After connect + discovery, assume `writeChar` and `statusChar` are located:
peripheral.setNotifyValue(true, for: statusChar)

func sendDTMF(_ s: String) {
    guard let data = s.data(using: .ascii) else { return }
    // .withoutResponse is fastest; use .withResponse to get a CB ack.
    peripheral.writeValue(data, for: writeChar, type: .withoutResponse)
}

// peripheral(_:didUpdateValueFor:error:) on statusChar delivers the "ok …" / "err …" string.
```

Add `NSBluetoothAlwaysUsageDescription` to `Info.plist`.

## Android / Kotlin sketch

```kotlin
val svcUUID    = UUID.fromString("6b1d6a10-c50f-4d86-a7f3-7f2a3a1b2c3d")
val writeUUID  = UUID.fromString("6b1d6a11-c50f-4d86-a7f3-7f2a3a1b2c3d")
val statusUUID = UUID.fromString("6b1d6a12-c50f-4d86-a7f3-7f2a3a1b2c3d")

val filter = ScanFilter.Builder().setServiceUuid(ParcelUuid(svcUUID)).build()
scanner.startScan(listOf(filter), ScanSettings.Builder().build(), scanCallback)

// After connectGatt + discoverServices:
val svc    = gatt.getService(svcUUID)
val write  = svc.getCharacteristic(writeUUID)
val status = svc.getCharacteristic(statusUUID)

gatt.setCharacteristicNotification(status, true)
val cccd = status.getDescriptor(UUID.fromString("00002902-0000-1000-8000-00805f9b34fb"))
cccd.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
gatt.writeDescriptor(cccd)

fun sendDTMF(s: String) {
    write.writeType = BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
    write.value = s.toByteArray(Charsets.US_ASCII)
    gatt.writeCharacteristic(write)
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

- The write characteristic is open by default. On open air, anyone nearby can
  send any DTMF sequence that SVXLink accepts (including reflector changes,
  reboot macros, etc.). If the hotspot is mobile / in public, switch the
  write flag to `encrypt-authenticated-write` and bond the phone.
- Server-side validation restricts payload chars to `0-9 A-D a-d * #`, so the
  wire can't be used to inject arbitrary shell or network traffic — it can
  only send DTMF strings to the local SVXLink socket.
- `hotspot-bluetooth` runs as root (needs the BlueZ system bus). It does not
  expose anything beyond the single characteristic write → helper script path.
