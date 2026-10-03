# FU9 — teljes projekttörténet és idővonal

Ez az idővonal azért készült, hogy az utód munkamenet ne csak a végállapotot lássa, hanem azt is, hogyan és miért alakult ki a jelenlegi architektúra, evidence-modell és prioritási sorrend.

## 1. Kezdeti LT500D / OpenWrt cél

A projekt kiinduló célja a Cudy LT500D gyári LEDE/Cudy felületének és funkcióinak reprodukálása volt OpenWrt 23.05.5 alatt.

Korai stratégia:
- gyári LEDE/Cudy UI = etalon
- OpenWrt 23.05.5 = runtime target
- donor UI/backend reverse engineering
- standalone frontend irány `/www/cudy-static`
- később külön Developer/engineering oldal
- TR-069/CWMP kizárva

Munkamegosztás alakult ki:
- EM: emulator/web forensics
- RE: firmware/source/binary reverse engineering
- WS: frontend fidelity
- Integration/Boss: backend, adapter, build, merge

## 2. V63–V67 frontend és donor RE korszak

A frontend munka a gyári LT500D donor UI és a Cudy online emulator alapján indult.

Fontos kialakult szabályok:
- ne találjunk ki donor truthot
- donor route/controller/CBI legyen elsődleges
- ami gyáriban működik, ne implementáljuk újra más logikával
- no fake data
- panel-level loading/error isolation
- stale-response protection
- More Details route-ok donor szerint

Wireless/WISP különösen erős donor-evidence-t kapott:
- wlan00 = 2.4 GHz
- wlan1* = 5 GHz
- wlan2* = 6 GHz capability-dependent
- Smart Connect
- channel/mode/width/power/max stations/hidden/separate clients
- WISP General Settings domainban

Ezt később frozen donor-validated állapotként kezeltük.

## 3. Donor RE Snapshot 01–03

A gyári LEDE firmware statikus RE során előkerült:
- description.lua
- gui.lua
- feature registry / resolver
- controller -> CBI -> backend réteg
- rpc/app szerepe
- gcom/mcore/cmagent kapcsolatok
- Dashboard dinamikus panelstruktúra
- Cellular accounting
- Devices / mcore devlist
- WISP
- Advanced routes
- OTA állapotgép

Snapshot 03 fontos lezárásai:
- exact resolver pseudocode
- mcore devlist contract
- Cellular Data exact contract
- OTA state machine
- további controller/model/backend mappingek

Innen alakult ki a szigorú szabály:
SOURCE presence != target capability != UI placement.

## 4. Fizikai R25 engineering ág indulása

A projekt külön fizikai R25 firmware-unlock ágra vált.

Stock target:
LT500V2-R25-2.4.16-20250804-150319-flash.bin
SHA256 57aed945a9f485d178d73a844e420fc2b441e60821e243d3d19d07dd4a3143d6

A stock rootfs közvetlenül igazolta:
- LEDE 17.01.5 / Cudy 2.4.16
- hidden Terminal
- Sandbox/Telnet
- bdinfo dbg gate-ek
- firstboot credential logic
- oem-check
- OTA
- cmagent/cmsd/hcshd
- 4G/gcom/mcore framework

Ez a pont választotta szét végleg a GUI-port és firmware-unlock evidence-domainokat.

## 5. ENG06

ENG06 volt az első komoly stock-alapú engineering image checkpoint.

Tartalma:
- Dropbear gate bypass
- Telnet gate bypass
- engineering root
- root-regeneration neutralizálás
- serial console policy
- username mező láthatóság
- OTA cron suppression
- CWMP auto-enable blokkolás
- hcshd boot suppression ezen a korai ágon
- unsigned standard R25 sysupgrade támogatás
- U-Boot recovery RSA érintetlen

Statikus image-integrity PASS volt.

A későbbi fizikai tapasztalat egyik legfontosabb tanulsága:
STATIC/EMU PASS nem egyenlő PHYSICAL BOOT PASS.

## 6. ENG07–ENG08 és a 4G baseline

A fizikai targeten a modem:
Quectel EC200A-EL
cdc_ether
usb0

A 4G stack működő állapotba került.

Ekkor született meg a fontos ownership-szabály:
- unlock/access ne írja újra a hardverstack-et
- 4G külön domain
- Cellular regression P0
- working 4G frozen baseline

ENG08 lett a későbbi OPKG/Developer/UI módosítások alatti fő működő physical baseline.

## 7. OPKG helyreállítás -> H09

A gyári rootfsben package metadata maradt, de a normál OPKG usability nem.

Lépések:
- exact régi opkg lineage visszaállítása
- LuCI package UI restore
- package DB rekonstrukció
- kmod ownership rekonstrukció
- safe mode
- flash-space policy
- protected packages
- lifecycle self-test

Több Hardened iteráció után H09 lett a frozen baseline.

H09 bizonyított:
- 127 package record
- 86 kmod
- 41 userland
- exact legacy opkg
- install
- list-upgradable
- HOLD
- release HOLD
- named upgrade
- remove
- cleanup/restoration

Ezzel SOURCE + STATIC + TARGET + LIFECYCLE VERIFIED lett.

## 8. H11 branding/theme

H11 cél:
- OpenCudy branding
- Dark Theme
- Developer ownership integráció

H11-02 target install/runtime PASS.

Known visual misses megmaradtak:
- Dashboard System card
- System Status firmware row
- General -> Firmware/Online Update

A fontos tanulság:
runtime correctness és visual fidelity külön evidence layer.

## 9. Developer V2/V3/V4

Korai Developer értelmezés túl sok normál Cudy funkciót kevert engineering kategóriába.

Későbbi stock rootfs RE tisztázta:
- Terminal és Sandbox valódi hidden/maintenance elemek
- sok más route normál child/detail oldal
- 54 native/provenance feature
- source presence nem automatikus Developer feature

Developer V2 READONLY-02:
- fixed allowlist
- no arbitrary shell
- read-only state/reporting
- target probe PASS
- verifier PASS
- command selftest PASS
- watched network/service state unchanged

Developer V3:
- 24 core feature
- 54 native catalog

Developer V4 CLEAN:
- normal UI ne legyen duplikálva
- Developer csak valódi engineering/internal domain
- System/Kernel log maradhat
- raw AT/reset/MTD/GPIO blocked
- raw hcshd/cmagent generic execution tilos
- Factory Debug külön high-risk domain

## 10. Cumulative-24 -> C27

A kumulatív installable runtime vonal fokozatosan összefésülte:
- engineering unlock
- működő 4G
- H09 OPKG
- H11
- Developer
- OTA/CWMP policy

C27 target verifier:
- services PASS
- auto_upgrade=0
- CWMP off
- OPKG 127/127/86
- watchdog
- 4G usb0
- Developer V4 CLEAN-06

C27 runtime package fizikai targeten működött.

## 11. Candidate47

C27-ből sysupgrade/fullflash candidate készült.

Sysupgrade:
SHA 8d51bc017a3e275c0ce3a5c05a659a4a3c4f55bb96370d0fabc81f3d1470a060
size 12,058,779

Proof:
- stock GUI accept
- sysupgrade -T PASS
- image format valid

Nem történt/igazolt:
- flash
- boot
- lifecycle

Ezért Candidate47 mindig TARGET_REQUIRED actual boot szinten.

## 12. R25 CSP2.5 kutatás

A projekt célzottan kereste, létezett-e újabb CSP2.5 R25 firmware.

Megtalált:
- CSP2.5 support plan
- request mechanics
- R100/LT300V3 donor
- staging/production metadata
- private beta precedensek

Nem talált:
- exact public R25 2.5.x payload

Szabály:
nincs random suffix/UUID/timestamp spraying.

## 13. R100 / R125 CSP2.5 hybrid

A felhasználó külön hibrid irányt próbált:
R25 hardware + CSP2.5 userspace.

Korai Candidate-02 később revoked/superseded.

Későbbi R125 physical truth:
- R25 hardware lineage
- CSP2.5 userspace nagy része
- R25 gui.lua
- R25 gcom/4G
- R25 libbdinfo
- külön CSP2.5 libbdinf2
- 5G/LTE működik
- crypt ABI fix után MQTT/TLS connect
- cloud bind nem lezárt
- Portal HOLD
- web auth working/frozen
- Wireless carousel issue

R125_2 külön incident archive.

## 14. FU7 donor firmware recovery

FU7-ben nagy donor corpus gyűlt össze.

Külön értékes:
- C200P
- P2/R91
- RG500
- CellularUpgrade
- WR3000 beta/adblock
- TR3000 firmware
- OpenWrt intermediary corpus

FU7 clean master artifact:
11068611598

Ez később FU8 workflow-k forrása lett.

## 15. FU8 — célzott statikus P0 program

FU8 tudatosan elkerülte a már lezárt RE újrakezdését.

Fő irányok:
- exact R25 debug/access chain
- C200P Rosetta stone
- P2 cellular delta
- support/private-beta lineage
- hcshd/cmagent/cmsd management plane
- trust boundaries
- exposure

## 16. FU8 CP09

CP09 több donor/beta/P2/C200P kutatási eredményt konszolidált:
- C200P public successor
- P2 adjacent/public generation deltas
- private beta precedens
- static P0 status

## 17. FU8 CP10

Exact R25/C200P engineering correlation.

Lezárta:
- R25 access architecture
- exact Factory Debug token semantics
- older R25-family support maintenance runtime sequence
- C200P newer support SSH architecture
- credential policy non-universality

Kulcs:
C200P formula nem R25 formula.

## 18. FU8 CP11

Caller topology.

Szétvált:
- LuCI RPC
- cmagent
- hcshd

Direkt cmagent/RPC -> hcshd bridge nem került elő.

## 19. FU8 CP12

Management dependency map.

Négy plane:
- LuCI RPC
- cmagent
- cmsd
- hcshd

cmsd explicit cloud-binding layer default OFF.

## 20. FU8 CP13

Auth/trust boundary.

Megállapítások:
- Mosquitto JWT/ACL/cert layer
- auth_plugin_jwt -> libbdinfo
- cmsd native MQTT/TLS/ubus/Lua
- hcshd/libbdinfo shared RSA public trust anchor
- crypto gate precedes hcshd command sink passive testben

## 21. FU8 CP14

Exposure/internal caller audit.

Stock firewall:
- WAN input REJECT
- WAN forward REJECT

No explicit MQTT/hcshd WAN allow.

cmagent command/config first-party internal callers:
- sync_command
- sync_config
- mesh/admin sync

Ez korrigálta a korábbi leegyszerűsített „hidden backdoor” narratívát:
a command-capable framework egy része normál vendor management/mesh infrastructure.

## 22. Belkin F9K1103 külön portprojekt

A Belkin project kezdetben OpenWrt/Immortal/LEDE natív portot célzott.

OpenWrt 23.05.5:
build success/static validation.

ImmortalWrt 18.06:
build success/static.

LEDE 17.01.5:
hosszabb ideig build failure a historical lzma-loader/host toolchain problémák miatt.

## 23. Fontos Belkin korrekció

A felhasználó tisztázta:
a fizikai F9K1103-on használt OpenWrt 19 image valójában F9K1109 v1 build.

Ezért:
- F9K1109 OpenWrt19 = practical hardware reference
- F9K1103 native port = külön target
- a kettőt nem szabad azonosnak nevezni

## 24. Cudy donor study Belkinhez

Először WR1000 tűnt a legjobb Cudy donornak a 8/64 resource class miatt.

Automated rootfs/UI donor audit után a prioritás változott:
WR1200 V2 2.4.x sokkal jobb modern Cudy UI/userspace donor.

Különösen:
WR1200V2 2.4.12/2.4.23 <-> LT500D 2.4.16 nagyon magas UI közösség.

## 25. 2026-10-02 — LEDE breakthrough

Több korábbi LEDE failure után három külön branch SUCCESS lett:

- clean direct-LZMA
- direct-LZMA
- minimal boot

Mindhárom static validation PASS.

Elsődleges:
run 36964886797
head ee79c687cffee78d274a3da63a3bec53a34ed19b
sysupgrade SHA b78106c7509a31f886682e9d071f6d41fdaee7bd6f209add4a4aa6b61a9f0622

Ez a handoff legfontosabb friss állapota.

## 26. Handoff pillanat

A chat elérte a maximális hossz közelét.

A felhasználó ezért elrendelte:
- teljes 100%-os dokumentáció
- FU9 successor prompt
- documentation ZIP
- külön all-firmware ZIP
- semmilyen projektág ne vesszen el

Firmware Unlock 9 első feladata:
a LEDE SUCCESS build physical truth felé vitele, majd Cudy userspace port.
