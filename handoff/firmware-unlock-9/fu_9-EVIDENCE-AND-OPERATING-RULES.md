# FU9 — evidence és működési szabályok

## Evidence hierarchy

A projektben mindig a legközvetlenebb bizonyíték nyer.

Prioritás általában:
1. physical target runtime evidence
2. exact target source/binary evidence
3. exact firmware static analysis
4. same-board/same-family runtime evidence
5. cross-model Cudy donor evidence
6. emulator/web evidence
7. architecture inference
8. hypothesis

Egy alacsonyabb szintű evidence nem írhat felül magasabbat magyarázat nélkül.

## Required labels

### SOURCE_PRESENT
A fájl/route/symbol jelen van, de viselkedés nincs bizonyítva.

### SOURCE_VERIFIED
Control-flow/source alapján a viselkedés bizonyított.

### STATIC_VERIFIED
Artifact/image/package statikusan validált.

### TARGET_VERIFIED
Fizikai targeten ténylegesen igazolt.

### LIFECYCLE_VERIFIED
Teljes életciklus/tranzakció végigment.

### TARGET_REQUIRED
Statikusan kész, physical proof hiányzik.

### CROSS_DONOR_CORROBORATED
Más modell erősen megerősít egy mintát.

### CROSS_DONOR_ONLY
Csak más modellen ismert.

### UNKNOWN
Nincs elég evidence.

### NOT_FOUND_STATIC
A vizsgált corpusban nem került elő.
Nem azonos az ABSENT állítással.

### REVOKED / SUPERSEDED
Korábbi artifactot a felhasználó vagy későbbi truth érvénytelenített.
Nem használható base-ként.

## Never silently upgrade status

Tilos:
- BUILD SUCCESS -> BOOTED
- sysupgrade -T -> PHYSICAL FLASH PASS
- emulator PASS -> target PASS
- donor file presence -> target feature
- same SoC family -> board compatibility
- same MIPS class -> binary compatibility
- listener 0.0.0.0 -> WAN reachable
- hidden route -> safe Developer feature

## Source vs handoff

Handoff leírhat egy állítást.
SOURCE_VERIFIED csak akkor használható, ha az exact source/artifact ténylegesen ellenőrizve lett.

Ha handoff és source ellentmond:
SOURCE nyer.

Ha donor és target eltér:
jelöld a különbséget; ne automatikusan „javítsd”.

## Physical action policy

Fizikai flash/reboot:
- explicit user choice
- exact artifact/hash
- recovery route
- preflight
- minimal risk
- rollback awareness

Read-only measurement előnyben.

Candidate47:
ne bootold automatikusan.

Belkin LEDE:
ne flash-eld automatikusan.

bdinfo:
soha ne írj.

## Security-sensitive engineering policy

Developer UI nem lehet generikus privileged API.

Tilos generic endpoint:
- arbitrary shell
- arbitrary path
- arbitrary service name
- arbitrary ubus object
- arbitrary native route
- arbitrary AT
- arbitrary GPIO
- arbitrary MTD write/erase

hcshd:
forensic/architecture evidence, nem generic Developer remote shell.

cmagent command:
normal first-party mesh/admin caller evidence van; ne távolítsd el vakon, és ne tedd raw Developer API-vá.

TR-069/CWMP:
project policy szerint excluded.

## Firmware discovery policy

Firmware huntban:
- exact first-party URLs
- official metadata
- archived exact references
- evidence-derived filenames

Tilos:
- random UUID
- random timestamp
- suffix spraying
- high-volume guessing

Negatív exact probe csak az exact probe-ra negatív.

## Donor policy

Másik modell:
LEAD/CORROBORATION.

Nem lehet automatikusan:
TARGET_TRUTH.

C200P:
Rosetta stone.

P2:
cellular evolution donor.

WR1200:
Belkin Cudy UI/userspace primary donor.

LT500D:
deep semantic donor.

F9K1109:
Belkin hardware/runtime reference.

## Ownership rules

Egy feature-nek egy authoritative owner.

R25:
- Cellular hardware/session: existing cellular stack
- OPKG: H09
- Theme/branding: H11 owner
- Developer: narrow Developer controller/view
- Wireless: donor/native wireless owner
- Firewall: firewall owner

OpenWrt23:
- frontend nem barkácsol backend workaroundot
- backend blocker -> Integration required

Belkin:
- board/hardware -> native LEDE/F9K1103 adapter
- Cudy UI -> donor userspace layer
- no R25 hardware binary ownership

## Regression rules

Frozen componenthez csak:
- concrete failing evidence
- target regression
- source mismatch

miatt nyúlj.

Különösen:
- ENG08 4G
- H09 OPKG
- Developer V2 read-only
- Native SAuth repair
- V67 Wireless/WISP donor semantics

## User interaction rules

Nyelv:
magyar.

"hajrá", "mehet", "csináld", "folytasd":
azonnali execution.

Ne kérj vissza már ismert adatot.

Ne ígérj background workot.

Hosszú tasknál:
- időnként checkpoint
- letölthető artifact
- ne veszíts session state-et

Router parancs fejléc:
SSH terminálba:

BusyBox/ash compatible.

## Documentation rules

Minden fontos artifact:
- filename
- SHA256
- size ha ismert
- source/provenance
- evidence status
- risk/status
- next action

Unknown ne legyen kitöltve találgatással.

## File naming

FU9 saját research/handoff:
fu_9-

A successor prompt kivétel:
FIRMWARE-UNLOCK-9-PROMPT.txt

Runtime/source fájlokat ne nevezd át csak a prefix miatt.
