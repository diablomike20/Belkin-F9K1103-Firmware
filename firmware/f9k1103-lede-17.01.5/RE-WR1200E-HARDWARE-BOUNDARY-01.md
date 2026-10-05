# RE — WR1200E → F9K1103 hardware boundary 01

## Source evidence already closed

### Keep Cudy unchanged

The exact WR1200E R62 / 2.4.25 donor contains the same hashes as WR1200V2 for:

- `/bin/config_generate`
- `/etc/uci-defaults/01_network`
- `/etc/uci-defaults/30_wlan`
- `/etc/uci-defaults/40_luci-wireless`

These are treated as Cudy behavior truth.

`01_network` creates the Cudy WISP interface and WAN/WISP metrics.

`30_wlan` owns the Cudy dual-band defaults:
- `radio0` / `wlan00` = 2.4 GHz
- `radio1` / `wlan10` = 5 GHz
- Cudy SSID naming
- Cudy encryption/password defaults
- guest sections
- country/channel semantics

Do not rewrite these scripts for F9K1103 unless an exact target incompatibility is demonstrated.

### Thin adapter required

WR1200E board code R62 is a four-port product. The exact donor `98-board` and `99_oem` set:

`system.board.ports=4`

The physical F9K1103 is:

`1 WAN + 4 LAN = 5 ports`

Therefore the target adapter overrides only:

`system.board.ports=5`

Physical VLAN/switch placement remains target-owned by the RTL8367R board layer.

### Hardware replace

The following donor objects encode MT7628/MT7663 physical hardware and are not target truth:

- `/lib/modules`
- `/lib/firmware`
- `/lib/wifi/radio0-mt7628.sh`
- `/lib/wifi/radio1-mt7663e.sh`
- donor board.d physical switch/radio mapping
- donor flash/upgrade platform implementation

F9K1103 uses RT3883 + RT309x + RTL8367R and must retain its boot-verified kernel/driver/calibration layer.

### Physical radio contract already target-verified

Real F9K1103 enumeration:

- `radio0` = PCI RT3091/3092 = 2.4 GHz
- `radio1` = RT3883 WMAC = 5 GHz

The Cudy userspace contract remains:

- `wlan00` = 2.4 GHz main AP
- `wlan10` = 5 GHz main AP

The new adapter maps only these physical identities; it does not change donor SSID/security settings.

## bdinfo

WR1200E stock defaults consume at least:

- `bdinfo board`
- `bdinfo mac`
- `bdinfo hmac`
- `bdinfo pin`
- `bdinfo country`
- `bdinfo fuuid`
- `bdinfo checkuuid`
- `bdinfo dbg`

The historical minimal shim does not implement the complete contract and is **not accepted as the new default**.

The exact donor `bdinfo` remains `NATIVE_CANDIDATE` until its ELF ABI and physical MTD/factory dependencies are audited.

If the donor binary cannot operate on F9K1103 factory layout, build a contract adapter that preserves the full Cudy-facing API. Do not return arbitrary fake cloud identity as donor truth.

## Authentication

No new auth patch is authorized by this boundary document.

The Cudy stock authentication/password path is preserved until exact runtime evidence proves a target incompatibility.

Access-safety changes, if needed for the first physical candidate, must be isolated and documented separately from the Cudy userspace port.

## Status

- Cudy behavior layer: **SOURCE_VERIFIED**
- F9K1103 radio mapping: **TARGET_VERIFIED**
- mcore adapter: **TARGET_VERIFIED**
- WR1200E donor ELF ABI as a complete set: **AUDIT_PENDING**
- donor bdinfo on F9K1103 factory layout: **TARGET_REQUIRED**
- full rootfs candidate: **NON_FLASHABLE**
