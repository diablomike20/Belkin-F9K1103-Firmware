# F9K1103 LEDE 17.01.5 Cudy Firmware — WIP01

## Goal

Build a flashable Belkin F9K1103 v1 firmware with:
- native F9K1103 LEDE 17.01.5 hardware support,
- Cudy router UI/userspace semantics,
- no cellular/3G/4G/5G stack.

## Authoritative layers

### Hardware / boot / kernel — BELKIN F9K1103
Keep the native F9K1103 port authoritative for:
- RT3883 kernel and DTB,
- SPI flash partitions,
- RTL8367R-VB switch,
- 2.4 GHz / 5 GHz radios and calibration,
- USB,
- LEDs/buttons,
- MAC address retrieval,
- sysupgrade format.

### Cudy UI donor — WR1200 V2 / R26 2.4.23
Firmware Unlock 8 selected WR1200V2 2.4.12/2.4.23 as the strongest modern non-cellular Cudy router UI donor.

WIP01 imports only:
- /usr/lib/lua/luci
- /www

The build explicitly rejects ELF content in the imported overlay.

### Excluded
Do not import from the donor:
- kernel or kmods,
- bootloader,
- flash layout,
- factory/calibration data,
- network defaults,
- opaque vendor ELF binaries,
- bdinfo identity/provisioning binaries,
- hcshd,
- modem/cellular/3G/4G/5G code,
- SMS,
- raw AT,
- DTU.

Explicit common-tree residues removed in WIP01:
- luci/apprpc/cellular.lua
- luci/model/cbi/network/dtu.lua

## Donor provenance

WR1200V2-R26-2.4.23-20251224-145945-flash.zip

SHA-256:
def1d4b8472b5fef4d0f13d337d6c2f11127d14ef6bd7100780dbac0115aa35c

Official Cudy download asset is fetched by the build and the hash is checked before extraction.

## Compatibility identity

Cudy UI feature resolution is supplied a compatibility type R26 while the real kernel/board identity remains F9K1103.

This is a temporary userspace adapter for WIP01 and is not allowed to alter:
- /tmp/sysinfo/board_name,
- DT compatible/model,
- MTD layout,
- radio calibration,
- upgrade target.

## Gate

WIP01 is not approved for physical flashing until:
1. GitHub build succeeds.
2. Image size/static CRC checks pass.
3. Built rootfs audit proves no donor ELF or cellular files entered the image.
4. LuCI startup dependencies are checked.
5. User explicitly approves the first physical test.
