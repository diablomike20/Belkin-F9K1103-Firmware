# F9K1103 Cudy port policy — FU8-derived

## Target
Belkin F9K1103 v1, native LEDE 17.01.5 rt3883/mipsel_74kc hardware base.

## Primary Cudy donor
WR1200V2 R26 2.4.23.

FU8 comparison against LT500D R25 2.4.16:
- 445 common selected UI paths
- 417 byte-identical common UI files
- byte-identical common UI ratio: 0.937079
- UI path Jaccard: 0.815018

WR1200V2 is preferred because it is a normal dual-band router donor. LT500D is only corroboration for Cudy-common framework/UI semantics.

## Keep from F9K1103
- kernel 4.4.140 / native LEDE target
- DTS / flash layout
- RTL8367R-VB switch integration
- RT3883/RT3092 radio drivers and calibration
- USB host support
- board detection and MAC handling
- native sysupgrade image envelope

## Port from Cudy only after dependency review
- LuCI controllers/models/views
- Cudy theme/static assets
- JavaScript/CSS/images
- router-common shell scripts
- UCI semantics for normal router functions
- dashboard/system/tools/router UX

## Hard exclusions
- cellular / 3G / 4G / 5G
- SMS / SIM
- gcom and modem scripts
- MT7628 kernel modules
- MT7628 vendor Wi-Fi stack
- direct replacement of F9K1103 network/wireless hardware configuration
- TR-069
- opaque donor ELF binaries without explicit ABI/runtime proof

## ABI rule
WR1200V2/LT500D donor binaries are mipsel_24kc while the F9K1103 target is mipsel_74kc.
No opaque ELF is copied merely because both are MIPS little-endian.

## Build philosophy
Cudy userspace semantics -> source/portable layer -> F9K1103 adapter -> native LEDE package/image build.

The final product must be a normal F9K1103 sysupgrade image, not a renamed Cudy vendor image.
