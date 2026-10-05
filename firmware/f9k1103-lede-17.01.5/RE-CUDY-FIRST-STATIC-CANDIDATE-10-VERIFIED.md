# RE — CUDY-FIRST Static Candidate-10 verified checkpoint

## Result

Workflow: `RE Cudy-first static candidate 10`

Run: `37387319154`

Workflow head SHA: `19dbcc8dfb00cfd5e7b40cc139472d05f0ca9dd8`

Result: **SUCCESS**

This checkpoint records the first complete statically validated CUDY-FIRST WR1200E → F9K1103 sysupgrade candidate.

## Candidate image

`RE-F9K1103-CUDY-FIRST-WR1200E-STATIC-CANDIDATE-01-sysupgrade.bin`

SHA-256:

`8d687d1cdf37329a095df9e6f82f71586232e2b856289bddd218db734f10dd28`

Size:

`6083172 bytes`

Static image validation:

- uImage name: `N750F9K1103VB`
- header CRC: PASS
- payload CRC: PASS
- SquashFS offset: `1380799`
- SquashFS bytes used: `4701712`
- fwtool record size: `165`
- 7224 KiB image limit: PASS
- validation: **PASS**

## Cudy invariants

The following selected donor files are byte-pinned in the final packed image:

- `/bin/busybox`
  - SHA-256 `d51f999786c660cd6f4c671b72fcf8aae8f3060e753b15973cca2e96dac837b8`
  - policy: **CUDY_PINNED / NEVER_REPLACE**
- `/usr/bin/bdinfo`
  - SHA-256 `40e9f9ccdd22fe39d340d799ee4ae3c2ebe8c09c6d8b1f55ef5b72e58fd22763`
  - policy: **CUDY_PINNED / ORIGINAL**
- `/usr/lib/libbdinfo.so`
  - SHA-256 `dc2ac9f10739eb1f690acf3fbd9e17d8f824673f7faa7173db3894faa4cfc15b`
  - policy: **CUDY_PINNED / ORIGINAL**

Also preserved:

- Cudy `/sbin/wandetect`
- Cudy WAN hotplug logic
- Cudy `11_fix_passwd` byte-identical
- Cudy high-level network/wireless defaults

No fake `bdinfo checkuuid=OK` contract is used.

Unprovisioned Cudy fallback behavior is retained.

## Target WAN kernel ABI

Workflow: `RE wan_detect build and wireless gate 06`

Successful run: `37387180812`

Workflow head SHA: `7878f6230539b3eb502faf6cbacb0099d0fb4faa`

Target module:

`re_wandetect_compat.ko`

SHA-256:

`80b79344e8c81ad2946f6f32e4b2b3bfc953edb6e1046c4508e6d073d9c3eecc`

ELF:

`ELF 32-bit LSB relocatable, MIPS, MIPS32 rel2`

Kernel release:

`4.4.140`

Toolchain:

`EXACT_LEDE_17.01.5_RAMIPS_RT3883_SDK`

The module supplies only the target-side Cudy procfs ABI. The donor Cudy WAN userspace remains unchanged.

## Current limitations

The candidate status deliberately records:

`WAN_AUTO_PROTOCOL_DETECT=NOT_YET_PARITY_VERIFIED`

and

`BDINFO_BACKING=UNPROVISIONED_NO_FAKE_CHECKUUID`

These are not permission to replace Cudy userspace.

## Safety status

`FLASH_AUTHORIZATION=NO`

This checkpoint does **not** authorize physical flashing.

Before physical installation:

1. current candidate source must remain frozen;
2. final static/rootfs invariant gate must remain PASS;
3. target-side `sysupgrade -T` must PASS;
4. destructive installation requires explicit approval;
5. never use `-F`;
6. bootloader/factory/calibration partitions remain protected.
