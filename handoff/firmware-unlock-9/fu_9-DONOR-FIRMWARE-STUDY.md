# FU9 — donor firmware study and porting map

## Purpose

This document answers two questions:

1. Which Cudy firmware families are most useful for continuing LT500D/OpenCudy research?
2. Which Cudy firmware families are most useful for porting the Cudy userspace/UI onto Belkin F9K1103 v1 once a native LEDE 17.01.5 base is physically proven?

## Donor corpus acquisition

A reproducible GitHub Actions audit acquired and compared:

- LT500V2-R25-2.4.16-20250804-150319
- WR1200V2-R26-1.17.4-20240206-085058
- WR1200V2-R26-2.1.1-20240418-092852
- WR1200V2-R26-2.2.8-20241015-160718
- WR1200V2-R26-2.4.12-20250703-144919
- WR1200V2-R26-2.4.23-20251224-145945
- WR1300-R10-1.13.6-20220314-112409
- WR2100-R11-1.14.25-20220730-212246
- OpenWrt 19.07.0 F9K1109 v1
- OpenWrt 19.07.10 F9K1109 v1
- OpenWrt 19.07.10 Cudy WR1000 reference

Audit artifact:
belkin-cudy-donor-firmware-corpus-and-audit

Artifact ID:
11206815616

Artifact digest:
67faaafe219143ec262d06419b815a819e23fb6ae7b67826bf927e096e3ca8b1

The workflow:
- downloads exact firmware
- verifies known hashes where authoritative
- extracts inner BINs
- finds SquashFS
- extracts rootfs
- inventories LuCI, www, init, Cudy framework files
- computes path similarity
- computes byte-identical common-file ratios
- creates feature matrices

## Key conclusion: WR1200 V2 is the most valuable Belkin Cudy UI donor

The initial intuition favored WR1000 because of its 8 MB / 64 MB resource class.

The deeper firmware audit changed that conclusion.

WR1200 V2 R26 2.4.12 and 2.4.23 carry a modern Cudy 2.4.x UI/userspace that is extremely close to LT500D R25 2.4.16 while remaining much smaller/simpler than LT500D.

Observed LT500D-vs-WR1200V2 2.4.x UI relation from the automated corpus:
- UI path similarity approximately 81.5 percent
- approximately 93.7 percent of common UI files are byte-identical
- approximately 445 common UI files

Therefore Belkin UI donor priority:

1. WR1200 V2 / R26 2.4.12 and 2.4.23
2. LT500D R25 2.4.16
3. WR1300 / WR2100
4. WR1000 OpenWrt/resource-class reference

## Why LT500D remains essential

LT500D has by far the deepest reverse-engineering corpus in this project:
- description.lua / gui.lua / forbidden.lua semantics
- dynamic feature resolver
- Dashboard contracts
- Wireless/WISP semantics
- Devices / mcore data model
- Cellular accounting
- VPN domains
- Advanced pages
- hidden/developer routes
- management-plane binaries
- bdinfo/debug/access architecture

So even where WR1200 is the cleaner small-router UI donor, LT500D remains the semantic reference.

## WR1200 lineage value

The WR1200 series gives a historical UI evolution line:
- 1.17.4
- 2.1.1
- 2.2.8
- 2.4.12
- 2.4.23

This is valuable for separating:
- old core Cudy GUI conventions
- new 2.4.x feature organization
- generic router behavior
- model-specific feature additions

For Belkin, the most relevant end is 2.4.12/2.4.23.

## WR1300 / WR2100 value

These are useful for:
- gigabit switch UI/semantics
- VLAN/IPTV
- richer router feature sets
- USB-related UI leads where present
- non-cellular Cudy feature organization

They are not hardware donors for RT3883.

## WR1000 value and limitation

WR1000 was initially attractive because:
- 64 MB class
- 8 MB class
- old ramips/MediaTek generation
- dual-band

However the exact old Cudy OEM WR1000 payload was not recovered in the Wayback step using only evidence-derived exact names.

The corpus contains an OpenWrt 19.07.10 Cudy WR1000 factory reference.
That is useful for resource class and board/reference work but is not a substitute for Cudy OEM userspace.

Do not guess WR1000 OEM filenames beyond evidence-derived names.

## C200P donor value

C200P R74 2.5.14 / 2.5.15 is valuable for:
- new-generation Cudy support/debug architecture
- Lua bytecode control flow
- batch command/service architecture
- cross-generation marker semantics
- public/prepublic delta study

It is not an R25 or Belkin direct donor.

Exact 2.5.14:
outer SHA:
a4f5f6494bcbdf41bfcd8573a22531fbd2115b5cb2769f5f44da213a900a7e98
inner SHA:
8ba6c51d13d72d2871a1b5e8bbcb4318c2fd4234898f8c1e9e6c30502913e0e8

Exact 2.5.15:
outer SHA:
04fe2d3d59de6ee4e66e56fea010038ea033feac50e418148ee2528f5e08ed56
inner SHA:
16a08d1cdf7e4714fc093d19f4fd3f38d1ffa0caa09d08652c885974565b54aa

## P2/R91 donor value

P2 is specifically valuable for:
- cellular lifecycle evolution
- gcom events
- reup/check flows
- 2.4.22 -> 2.4.29 public change analysis
- adjacent 2.4.29 -> 2.4.29b beta analysis

It is NOT a general LT500D donor.

P2 firmware should never be flashed to R25 or Belkin.

## R100/LT300V3 CSP2.5 donor value

R100 donor identity:
LT300V3-R100-2.5.12-20260518-234632

Package SHA:
8cd02de01b9db1caff6046d65768c9ce6f2c8db0913f6f7faa831971b5e46653

Inner SHA:
03641ed863911618155ddb55ed2c45f4c23abd330a4e171bff4491ffcda49a82

Role:
- CSP2.5 mechanics
- naming
- userspace architecture
- cross-generation feature study

Not official R25 firmware.

## Belkin hardware donor hierarchy

For physical F9K1103 hardware:

1. actual F9K1103 evidence / stock-family data
2. F9K1109 v1 OpenWrt source/runtime reference
3. common F9K110x DTSI
4. RT-N56U old RT3883/LEDE platform only as secondary platform reference
5. Cudy firmware only for UI/userspace semantics

Never invert this hierarchy.

## Recommended port decomposition

### Layer 1 — native Belkin base
LEDE 17.01.5
RT3883
F9K1103 DTS
RTL8367R-VB
radios
USB
MAC/calibration
image/recovery

### Layer 2 — generic Cudy framework
theme/assets
LuCI extensions
navigation
resolver
common helper modules

### Layer 3 — generic router features
System
LAN
DHCP
WAN
DNS
firewall
port forwarding
DMZ
Diagnostics

### Layer 4 — hardware adapters
wireless
switch/VLAN
LED
USB
Devices
status
sysupgrade

### Layer 5 — OpenCudy extensions
safe OPKG
Developer read-only
engineering status
theme/branding
snapshot/export

## What not to port

Do not carry over because a firmware happens to contain it:
- R25 cellular
- Cudy bdinfo
- model-specific mcore/gcom assumptions
- cloud identity secrets
- exact support credentials
- Cudy RSA/private provisioning assumptions
- MT7628 kernel modules
- MT7663 drivers
- hardcoded R25 interface identities
- R25 flash layout
- raw maintenance command transports

## Donor evidence rule

A donor can establish:
- lead
- architecture
- common semantics
- UI structure
- possible implementation pattern

Only target-specific source/runtime can establish:
- final target behavior
- hardware compatibility
- physical safety
- bootability
