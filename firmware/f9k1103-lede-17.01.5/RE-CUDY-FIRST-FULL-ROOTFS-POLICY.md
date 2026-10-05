# RE — CUDY-FIRST full-rootfs port policy

## Authoritative goal

Run the **Cudy WR1200E R62 / 2.4.25 firmware userspace** on the Belkin F9K1103 v1 hardware.

The donor is not reduced to a UI overlay. The **complete Cudy root filesystem is the userspace source of truth** unless an exact hardware/kernel incompatibility is demonstrated.

## Default classification

Every donor object starts as:

`NATIVE_CANDIDATE`

It may be downgraded only by evidence to:

- `ADAPTER_REQUIRED` — Cudy semantics remain authoritative; a thin target adapter supplies a missing hardware/runtime contract.
- `HARDWARE_REPLACE` — the object directly belongs to the donor SoC/kernel/flash/radio/switch implementation and cannot represent F9K1103 hardware.
- `EXCLUDE_SAFETY` — destructive factory/calibration/bootloader content that must never overwrite target-owned areas.
- `UNKNOWN` — insufficient evidence. UNKNOWN is not permission to replace Cudy content.

## Cudy-owned by default

Preserve whenever ABI/runtime permits:

- /bin and /sbin userland
- /usr/bin and /usr/sbin
- /usr/lib userspace libraries
- /usr/lib/lua and complete LuCI/Cudy framework
- /www
- /etc/init.d service behavior
- /etc/config schema/default semantics
- /etc/uci-defaults except exact physical board mapping
- Cudy helpers and daemons
- Cudy board/product identity exposed to the web UI
- Cudy network feature semantics, WISP, VPN, DHCP, firewall userspace, diagnostics

Do not replace a Cudy component merely because an OpenWrt equivalent exists.

## Target-owned hardware boundary

The following physical truth remains F9K1103-owned:

- RT3883 kernel / DTS / board support
- kernel modules
- flash partition layout
- U-Boot / image envelope and recovery constraints
- RTL8367R switch physical port mapping
- RT3883/RT309x physical radio drivers
- EEPROM/calibration/factory partitions
- physical MAC source
- sysupgrade target validation

## Existing verified adapter

`mcore.lua` target adapter is **TARGET_VERIFIED / POST_VERIFY PASS** on the physical F9K1103.

It preserves the Cudy mcore contract while replacing only the unsupported target-side shell quoting call.

## Rules

1. Cudy identity may remain WR1200E.
2. Do not cosmetically rename the donor to Belkin.
3. Do not pre-emptively remove Cudy services.
4. Do not substitute stock LEDE files without an exact incompatibility.
5. Donor ELF files require ABI/dependency analysis before inclusion; architecture label alone is not evidence of incompatibility.
6. No donor kernel modules, bootloader/factory/calibration images are ever copied to target.
7. Physical flash requires a separate static image/layout gate and `sysupgrade -T`; this policy does not authorize flashing.
