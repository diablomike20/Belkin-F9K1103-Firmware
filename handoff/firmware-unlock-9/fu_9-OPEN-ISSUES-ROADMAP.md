# FU9 — nyitott kérdések és roadmap

## P0 — jelenlegi elsődleges: Belkin native LEDE physical proof

### B-P0-01 — Candidate diff
Hasonlítsd össze a három SUCCESS LEDE candidate-et:
- clean direct-LZMA
- direct-LZMA
- minimal boot

Output:
- kernel/image delta
- config/package delta
- patch/source delta
- expected boot-risk delta

A clean direct-LZMA legyen default primary, amíg nincs ellene bizonyíték.

### B-P0-02 — Recovery contract
Fizikai test előtt dokumentáld:
- bootloader/recovery mód
- ismert working F9K1109/OpenWrt19 recovery route
- exact IP/path
- rollback firmware
- milyen image formátumot fogad
- config preservation policy

Ne építs fizikai tesztet recovery proof nélkül.

### B-P0-03 — Physical boot
Csak explicit user choice után.

Külön outcome:
- BOOTLOADER_ACCEPTED
- KERNEL_STARTED
- ROOTFS_MOUNTED
- LAN_REACHABLE
- FULL_RUNTIME_PASS

Egy részleges bootot ne nevezz teljes PASS-nak.

### B-P0-04 — Hardware matrix
Boot után:
- MTD
- switch
- WAN
- LAN
- 2.4G
- 5G
- calibration
- MAC
- LED
- buttons
- USB
- LuCI
- reboot persistence
- sysupgrade
- recovery

### B-P0-05 — Native baseline freeze
Csak teljes hardware/runtime gate után nevezz ki:
F9K1103-LEDE-17.01.5-NATIVE-BASELINE-01

## P1 — Belkin Cudy userspace port

### B-P1-01 — Footprint budget
8 MiB flash miatt:
- kernel size
- rootfs size
- overlay reserve
- package budget
- Cudy asset budget

Minden portfázis után mérni.

### B-P1-02 — Cudy framework extraction
Elsődleges donor:
WR1200 V2 2.4.x

Másodlagos semantic donor:
LT500D R25 2.4.16

Különítsd:
- byte-identical generic UI
- model feature registry
- hardware backend
- cloud/provisioning
- cellular

### B-P1-03 — Login/auth
Port legelső Cudy rétegén:
- LuCI auth ne törjön
- local admin stable
- semmilyen cloud dependency ne legyen kötelező
- recovery login legyen dokumentált

### B-P1-04 — Core UI
Sorrend:
1. theme/assets
2. shell/navigation
3. dashboard static structure
4. System
5. LAN/DHCP
6. WAN

### B-P1-05 — Hardware adapters
- wireless
- switch/VLAN
- Devices
- LEDs
- USB
- status
- sysupgrade

Minden adapter Belkin-native source-ból dolgozzon.

### B-P1-06 — Optional features
VPN/USB/etc csak akkor, ha:
- package fits
- backend exists
- target supports
- resource budget allows

### B-P1-07 — OpenCudy extensions
Csak core Cudy UI stabilitás után:
- safe OPKG
- Developer read-only
- branding/theme
- engineering snapshot

## P1 — R25 FU8 maradék statikus RE

Nem elsődleges, de megőrzendő:

### R-P1-01
hcshd legitimate upstream sender/controller provenance.

### R-P1-02
cmagent exact native inbound parser completion.

### R-P1-03
bdinfo_check_uuid exact algorithm/failure semantics, ha még nincs teljes disassembly proof.

### R-P1-04
exact 2.4.16 support-session credential policy.

### R-P1-05
hcsh/hcshd/rpc/app/rpc/sys/cmagent exact support-controller relationship.

Mindez static/provenance irányban; ne készíts generikus hozzáférési receptet.

## P1 — R25 CSP2.5 hunt

### C-P1-01
Evidence-backed exact R25 beta/public firmware leads.

Tilos:
- random suffix
- random timestamp
- UUID spray
- brute force

### C-P1-02
Official/support channels és archived first-party evidence.

UNKNOWN marad UNKNOWN, ha payload nincs.

## P2 — R125 CSP2.5 hybrid

### H-P2-01 — Wireless UI
5G carousel/data binding.

### H-P2-02 — Cloud binding
Csak stabil auth/runtime mellett.
Az autocloud restart-loop regressziót ne ismételd.

### H-P2-03 — Portal
HOLD, amíg web login/auth teljesen frozen stable.
No blind chilli import.

### H-P2-04 — R125 cleanup
R125_2 incidentből csak lessons learned, ne merge source.

## P2 — OpenWrt23 frontend/integration

### O-P2-01
V69 Truth-04 marad authoritative latest known integration baseline.

### O-P2-02
Backend blockers:
- Cellular/WISP ownership
- wan2
- Devices controlled-write
- wireless status

### O-P2-03
WS visual/route completion folytatható, de ne keverd a Belkin prioritással.

## Frozen baselines — csak regresszió esetén nyúlj

- R25 working 4G / ENG08
- H09 OPKG backend
- Developer V2 read-only
- H11 target install/runtime
- Native SAuth repair R125
- Wireless/WISP donor semantics a 23.05.5 UI ágon

## Release discipline

Minden új mérföldkőn:
- source commit
- artifact ID
- SHA256
- file size
- build log/run
- static validation
- target status
- rollback
- unresolved list

Külön jelöld:
BUILD_SUCCESS
STATIC_VERIFIED
TARGET_VERIFIED
LIFECYCLE_VERIFIED
