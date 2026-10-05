# F9K1103 TARGET-TEST-01 — sanitized findings

Physical target: Belkin F9K1103 Version 1.0

## Identity

- board_name: `f9k1103`
- LEDE: 17.01.5 r3919-38e704be71
- kernel: 4.4.140
- target: ramips/rt3883
- arch: mipsel_74kc

## Flash layout

Physical `/proc/mtd`:

```
mtd0 00030000 00001000 u-boot
mtd1 00010000 00001000 uboot-env
mtd2 00010000 00001000 factory
mtd3 007a0000 00001000 firmware
mtd4 0015119e 00001000 kernel
mtd5 0064ee62 00001000 rootfs
mtd6 0042e000 00001000 rootfs_data
mtd7 00010000 00001000 user-cfg
```

The physical layout therefore confirms the F9K1103 DTS/image assumptions:
- firmware begins at 0x050000
- physical firmware partition size is 0x7a0000
- separate user-cfg occupies the final 0x10000

## Upgrade preflight

The WIP02 image passed native LEDE validation on the physical target:

```
SYSUPGRADE_T_RC=0
SYSUPGRADE_T=PASS
```

No force option was used and no flash was performed.

## Switch

Physical swconfig evidence confirms:
- VLAN 1: ports 0 1 2 3 + CPU 5 tagged
- VLAN 2: WAN port 4 + CPU 5 tagged
- CPU port 5 link up at 1000/full

This matches the current board network definition.

## Wireless — IMPORTANT correction

Physical UCI / iwinfo evidence proves the actual LEDE enumeration:

- `radio0`
  - path: PCI `0000:01:00.0`
  - Ralink RT3091/3092
  - 2.4 GHz
- `radio1`
  - path: `platform/10180000.wmac`
  - RT3883 integrated WMAC
  - 5 GHz

Therefore the Cudy mapping must be:

```
radio0 -> wlan00 -> 2.4 GHz
radio1 -> wlan10 -> 5 GHz
```

Earlier WIP02/WIP03 assumptions that reversed radio0/radio1 are superseded.

Both radio drivers load EEPROM data from the `factory` MTD partition.

## USB

Physical dmesg confirms:
- EHCI controller initialized
- OHCI controller initialized
- USB buses created successfully

## Switch silicon

Physical dmesg confirms:
- RTL8367R-VB detected by rtl8367b driver.

## Recovery evidence from the physical target U-Boot dump

The actual target U-Boot contains:
- `reset button detected.....entering mini web`
- `Recovering Tool (N750)`
- firmware upload form / HTTP recovery code
- `ipaddr=10.10.10.123`
- `serverip=10.10.10.3`

This proves the physical unit contains the Belkin mini-web recovery implementation.
Exact human timing for entering recovery should still be verified before relying on it as the sole recovery path.

## Stream parser note

The first V2 collection parser failed only because the dynamically-created split
MTD block devices `kernel` and `rootfs` returned slightly fewer bytes than their
nominal `/proc/mtd` sizes. Physical top-level partitions were recovered intact.
This was a host-side framing assumption, not an image/preflight failure.
