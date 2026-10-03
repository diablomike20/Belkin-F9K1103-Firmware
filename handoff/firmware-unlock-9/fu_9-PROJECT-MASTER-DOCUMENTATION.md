# Firmware Unlock 9 — teljes projekt master dokumentáció

Dátum: 2026-10-03
Projekt: Cudy LT500D / OpenCudy / Firmware Unlock + Belkin F9K1103 v1 LEDE port
Utód munkamenet neve: Firmware Unlock 9

---

# 1. A projekt célja és jelenlegi iránya

A projekt eredeti és továbbra is élő fő célja a Cudy LT500D V2.0 / R25 platform teljes feltárása, engineering/unlock rétegének kontrollált kialakítása, a gyári Cudy/LEDE felület és funkciók megőrzése, valamint OpenCudy néven egy stabil, dokumentált, visszaállítható rendszer létrehozása.

A projekt az idők során négy egymással összefüggő, de külön bizonyítási ágra vált szét:

1. Cudy LT500D R25 fizikai router / firmware-unlock ág.
2. Cudy donor/UI/backend reverse engineering ág.
3. OpenWrt 23.05.5 frontend/integration ág, V67–V69 Truth/Workspace/RE/EM szervezéssel.
4. Új Belkin F9K1103 v1 ág, amelyen a cél egy natív LEDE 17.01.5 alap létrehozása, majd arra Cudy userspace/UI port.

A handoff pillanatában a FELHASZNÁLÓ KIFEJEZETT ELSŐDLEGES PRIORITÁSA:

**F9K1103 v1 natív LEDE 17.01.5 build stabilizálása és fizikai boot bizonyítása.**

A Cudy UI/userspace Belkinre portolása csak ezután következik.

Az OpenWrt 19.07 F9K1109 v1 image fontos hardveres referencia, mert a felhasználó F9K1103 v1 eszközén jelenleg nem natív F9K1103 OpenWrt build futott, hanem F9K1109 v1-hez készült OpenWrt 19.07 image. Ezt a tényt minden utód munkamenetnek meg kell őriznie.

---

# 2. Projektmunkamódszer és bizonyítási filozófia

A projekt során többször előfordult, hogy egy statikusan helyesnek látszó módosítás célhardveren másképp viselkedett, egy emulator PASS nem jelentett fizikai boot PASS-t, vagy egy GUI-integráció váratlanul LuCI regressziót okozott.

Ezért a jelenlegi bizonyítási lánc:

SOURCE / PROVENANCE
-> STATIC_VERIFIED
-> TARGET_VERIFIED
-> LIFECYCLE_VERIFIED

Külön állapotok:

- SOURCE_PRESENT: a fájl vagy route jelen van.
- SOURCE_VERIFIED: a viselkedés forrásból/control-flow-ból bizonyított.
- STATIC_VERIFIED: a kész artifact struktúrája, CRC/hash/image contractja ellenőrzött.
- TARGET_VERIFIED: fizikai célhardveren ténylegesen ellenőrzött.
- LIFECYCLE_VERIFIED: hosszabb tranzakciós vagy teljes funkcionális életciklus fizikailag végigment.
- TARGET_REQUIRED: statikusan kész, de célhardveres proof hiányzik.
- CROSS_DONOR_CORROBORATED: más Cudy modell erősen alátámasztja, de nem önmagában R25 truth.
- CROSS_DONOR_ONLY: csak másik modellen látható.
- UNKNOWN / SOURCE_GAP / BINARY_REQUIRED: nincs elég bizonyíték.

A státuszokat tilos összemosni.

---

# 3. Cudy LT500D fizikai target — authoritative truth

Eszköz:
- Cudy LT500D V2.0
- devtype / board: R25
- régió: EU / DE
- SoC: MediaTek MT7628AN
- CPU: MIPS 24KEc
- kernel: Linux 4.4.140
- RAM: 128 MiB
- flash: 16 MiB SPI NOR
- fizikai MTD struktúra tartalmaz U-Boot, env, factory, debug, backup, bdinfo, firmware, kernel/rootfs és dinamikus rootfs_data elemeket.

Cellular:
- modem: Quectel EC200A-EL
- modem FW: EC200AELV1LAR02A03M08
- USB driver: cdc_ether
- adat interface: usb0
- network.4g működőképes
- 4G működés több ponton fizikailag bizonyított regressziós baseline.

A fizikai R25 truth elsőbbséget élvez emulatorral és más donor modellel szemben.

---

# 4. Gyári R25 firmware — stock truth

Stock firmware:
LT500V2-R25-2.4.16-20250804-150319-flash.bin

SHA-256:
57aed945a9f485d178d73a844e420fc2b441e60821e243d3d19d07dd4a3143d6

Rootfs:
LEDE 17.01.5 / Cudy 2.4.16 / ramips-mt7628.

A stock rootfs exact auditja 2637 bejegyzést mutatott.

A gyári hozzáférési és karbantartási modell bizonyított elemei:

- Dropbear startup gate: bdinfo dbg.
- Telnet ugyanazt a debug-state gate-et használja.
- /lib/preinit/99_00_console retail/debug viselkedést választ.
- /usr/libexec/login.sh debug állapotban közvetlen shell utat tartalmaz.
- gyári rejtett Terminal route: admin/system/terminal.
- luci.forbidden tiltja a Terminal normál megjelenítését.
- Terminal CBI képes luci.util.exec hívásra.
- Sandbox/Telnet oldal jelen van.
- első boot retail root credential FUUID/HMAC függő.
- platform upgrade útban oem-check szerepel.
- cron/autoupgrade vendor OTA mechanika jelen van.
- package metadata jelentős része jelen volt akkor is, amikor a normál opkg bináris hiányzott.
- bdinfo checkuuid több provisioning/management útvonalon szerepel.
- cmagent, cmsd, hcsh/hcshd és más vendor framework elemek jelen vannak.

Stock feature catalog:
- 54 provenance/native feature-entry került azonosításra.
- 53/54 hivatkozott donor source path ténylegesen jelen van.
- SNMP az ismert source-residue kivétel.
- Source presence nem jelenti automatikusan R25 runtime capabilityt vagy Developer UI helyet.

---

# 5. bdinfo, identity, debug és firmware-integrity szétválasztása

A projekt egyik fontos eredménye, hogy a korábban összemosott „tamper/debug protection” több külön réteg:

1. bdinfo authenticity / provisioning
2. device identity consistency
3. debug/access policy
4. firmware authenticity / upgrade validation

Külön kezelendő:

- bdinfo check / md5
- bdinfo checkuuid
- bdinfo dbg
- bdinfo factory
- /etc/rom_develop
- /etc/rom_release
- /etc/rom_dbg
- OpenCudy Developer UI
- hcshd
- debug MTD
- Linux debugfs

Ezek nem ugyanazok.

Nagyon fontos projekt-szabály:
**BDINFO partíciót vagy mezőket nem írunk.**

---

# 6. Exact R25 Factory Debug mechanizmus

Az exact R25 2.4.16 /usr/lib/libbdinfo.so SHA-256:
dc2ac9f10739eb1f690acf3fbd9e17d8f824673f7faa7173db3894faa4cfc15b

A statikusan visszafejtett bdinfo_check_dbg lényegi adatfolyama:

- raw fread /proc/sys/dev/flash_uuid
- a procfs newline megmarad
- bdinfo hmac
- literal @2025
- SHA256
- lowercase hex
- pontosan 64 hex byte /etc/rom_dbg
- strcmp validáció

A /etc/rom_release külön retail gate:
- jelenléte debug-token elfogadás előtt retail elutasítást okoz.
- hiánya a maintenance/debug állapot egyik szükséges feltétele.

Ez R25 2.4.16 SOURCE_VERIFIED, nem C200P-ből átvett formula.

---

# 7. Engineering/unlock történeti lineage

## ENG06

Első tisztított engineering-image checkpoint a stock R25 full-flashből.

Fő változtatások:
- Dropbear bdinfo dbg startup gate eltávolítása.
- Telnet startup gate eltávolítása.
- stabil engineering root credential.
- FUUID/HMAC root-password replacement neutralizálása.
- serial askconsole elérhetőbbé tétele.
- web username láthatósági javítás.
- automatikus cron autoupgrade kikapcsolás.
- pingcheck OTA report trigger kikapcsolás.
- CWMP default OFF.
- hcshd boot init tiltás ezen a korai engineering ágon.
- standard R25 legacy-uImage sysupgrade elfogadás OEM RSA nélkül; OEM full-flash út külön maradt.
- U-Boot recovery RSA nem módosult.

ENG06 sysupgrade hash:
f9a9d8ae1419df115804fcafc752de45f3cd240c3652fe1f24aa4b935d3408b8

Korai tanulság: emulator/static PASS nem volt elég; fizikai boot külön gate.

## ENG07 / ENG08

A 4G hardver kezelésnél világossá vált, hogy az unlock és a cellular port külön domain.

Későbbi projekt-döntés:
- stock Cudy hardware/service truth az alap.
- unlock csak azt módosítsa, amit az access/persistence ténylegesen megkövetel.
- 4G, antenna, Wi-Fi vagy más hardver funkció ne legyen fölöslegesen újraírva.

ENG08 lett a működő fizikai 4G regressziós baseline.

---

# 8. H09 OPKG — frozen verified baseline

A H09 OPKG Manager az egyik legerősebben bizonyított projektág.

Státusz:
- SOURCE_VERIFIED: YES
- STATIC_VERIFIED: YES
- TARGET_VERIFIED: YES
- LIFECYCLE_VERIFIED: YES

Exact OPKG lineage:
9f61f7acf3845d2e09675b49fec5d783d57eb780
2017-12-08
mipsel_24kc

Exact /bin/opkg SHA:
48332ad1dcbeb3bcdc3ceac968b85eef57cab0476bb77f21cb48b8d8d0c93cdf

Reconstructed package state:
- 127 package record
- 86 stock-ROM kmod
- 41 userland

Bizonyított teljes lifecycle:
feed metadata
-> candidate selection
-> Installed-Size
-> dry-run
-> flash-space/safety policy
-> install
-> list-upgradable
-> HOLD
-> release HOLD
-> named upgrade
-> payload update
-> remove
-> cleanup/restoration

Hat core package továbbra is LOCKED:
- rpcd
- uclient-fetch
- libuclient
- libubox
- luci-base
- libblobmsg-json

Nincs Upgrade All.
Nincsenek veszélyes force flag-ek.
A H09 backendet csak konkrét regressziós bizonyíték esetén szabad átírni.

---

# 9. H11 branding/theme és Developer réteg

H11-02:
- install/runtime TARGET_VERIFIED
- LT500D-family + R25 identity gate verified
- H09 integrity unchanged
- JFFS2 overlay verified
- 4G preservation verified

Viszont vizuális branding nem teljes:
- Dashboard System card: részleges / 2.4.16 DE előfordult
- System Status firmware sor: nyers 2.4.16-20250804-150319 maradhat
- General -> Firmware / Online Update: nyers ROM identity maradhat
- footer OpenCudy branding működött

Dark Theme runtime működött; pixel-level fidelity külön munkaréteg.

Developer V2 READONLY-02:
- target probe PASS
- install/verifier PASS
- non-mutating command selftest PASS
- network/wireless/firewall/ROM/OPKG state hashes unchanged
- watched services unchanged

Developer V3:
- 8 categories
- 24 core engineering feature
- 54 native catalog entry
- production ownership szándékosan szűk:
  - /usr/lib/lua/luci/controller/re_developer.lua
  - /usr/lib/lua/luci/view/system/developer.htm

V3 nem veheti át:
- H09 OPKG ownership
- theme
- branding
- network
- wireless
- firewall
- cellular/4G
- kernel
- DTB
- bootloader
- firmware image

Developer V4 CLEAN:
- normal Cudy UI funkciók ne duplikálódjanak Developerbe.
- System Log + Kernel Log maradhat.
- Cudy Factory Debug külön high-risk maintenance domain.
- OpenCudy SSH/Telnet unlock külön domain.
- raw AT / modem reset / MTD write / GPIO write / arbitrary shell / arbitrary ubus / arbitrary path nem általános Developer API.

TR-069/CWMP végleg kizárt.

---

# 10. Cumulative-24 / C27 runtime baseline

A projekt későbbi kumulatív installable runtime vonala eljutott C27-ig.

Fizikailag bizonyított cumulative runtime lineage:
RE-LT500V2-R25-OPENCUDY-CUMULATIVE-27-TARGET-INSTALLABLE.tar.gz

C27 target verifier tartalma:
- service state PASS
- auto_upgrade=0
- CWMP policy OFF
- OPKG 127/127/86
- watchdog
- 4G usb0
- Developer V4 CLEAN-06

C27 runtime package, nem automatikusan végleges flash image.

---

# 11. Candidate47 — nagyon fontos státusz

Sysupgrade candidate:
RE-OPEN-CUDY-LT500V2-R25-C27-SYSUPGRADE-CANDIDATE-47.bin

SHA-256:
8d51bc017a3e275c0ce3a5c05a659a4a3c4f55bb96370d0fabc81f3d1470a060

Méret:
12,058,779 byte

Bizonyított:
- unchanged stock R25 uImage kezdet
- stock GUI upload identity elfogadta
- sysupgrade -T PASS
- image-format gate TARGET_VERIFIED

NEM bizonyított:
- actual flash
- actual boot
- long-term lifecycle

Full-flash archival/structural candidate:
RE-OPEN-CUDY-LT500V2-R25-C27-FULLFLASH-CANDIDATE-47.bin
SHA-256:
7118cfd798da459fc7d5ea0350501ec4a5bd088e0449d953dabf15929f89694f

Soha nem szabad Candidate47-et „booted” vagy production-ready állapotúnak nevezni új fizikai bizonyíték nélkül.

---

# 12. Unlock delta ledger — mi szükséges és mi nem

UNLOCK_REQUIRED:
- Dropbear local bdinfo-dbg startup gate bypass
- Telnet startup-gate bypass az OpenCudy policy szerint
- stabil engineering root access
- installed sysupgrade unlock
- root-password regeneration neutralizálása ahol az adott lineage igényli

UNLOCK_PERSISTENCE:
- scheduled vendor automatic OTA suppression

POLICY:
- TR-069/CWMP excluded

NEM automatikusan unlock-követelmény:
- hcshd eltávolítása
- cmagent/cmsd/Mosquitto teljes tiltása
- 4G script rewrite
- antenna GPIO rewrite
- minden cloud komponens tiltása

A későbbi RE bizonyította, hogy cmagent/cmsd/Mosquitto több normál Cudy dependencyben részt vesz.

---

# 13. R125 / R100 CSP2.5 hibrid ág

Ez egy külön kísérleti vonal, nem szabad összemosni a stock R25 2.4.16 vagy C27 baseline-nal.

A felhasználó kívánt iránya:
**R100 CSP2.5 userspace teljes R25-ösítése**
- R25 kernel/hardware
- R25 Wi-Fi/LTE/switch/provisioning
- CSP2.5 userspace/app/framework
- SSH initial extra
- TR-069 excluded

Egy korai Candidate-02:
RE-R100-R25-CSP25-SYSUPGRADE-CANDIDATE-02.bin
SHA-256:
47290d1c168c7991decdbedfdf1a12821a5fe9df237b1510960c00eac5311a52
méret 12,320,923
STATIKUSAN kész volt, de a felhasználó később REVOCÁLTA / SUPERSEDED állapotba tette.
Nem használható jelenlegi base-ként.

Későbbi authoritative hybrid truth:
- R25 gui.lua
- exact R25 gcom/4G stack
- R25 libbdinfo.so
- külön CSP2.5 libbdinf2.so
- R100/CSP2.5 userspace nagy része jelen
- R25 5 GHz és LTE működött
- crypt ABI javítás után Mosquitto/cmagent MQTT/TLS connect
- bdinfo check/checkuuid identity PASS
- optional bdinfo_read warningok maradtak
- Wireless 5G carousel frontend/data-binding probléma
- Cloud bind nem lezárt
- Portal HOLD

Egy korábbi full-ROM összevetés szerint R125 /rom:
- 615 exact R100 file
- 502 exact R25 file
- 1430 shared file
- csak 3 R100 path hiányzott

Ez erős userspace-hibrid bizonyíték.

Cloud:
- stock cmsd elérte a backendet, de „Not user bind me” állapot maradt
- autocloud=1 restart-loopot okozott; visszavonva/rollback
- ne tekintsük cloud bindet késznek

Captive Portal:
- külön domain
- TR3000 CoovaChilli donor lead
- exact R125-ben nincs installed chilli/Portal payload
- Candidate-01 parser failure
- Candidate-02 revoked
- Candidate-03 nem bizonyítottan települt és backup sem készült
- Portal HOLD, amíg web admin login stabil

Web admin auth:
- a működő Native SAuth repair állapotot fagyasztott baseline-ként kell kezelni
- auth/login regresszió elfogadhatatlan

R125_2:
- negatív/incident archive
- nem decision source

---

# 14. Firmware Unlock 8 — kutatási program áttekintése

FU8 célja nem újraépíteni az egész projektet, hanem a maradék statikus P0 kérdések lezárása volt:
- R25 access/debug architecture
- Cudy donor firmware lineage
- CSP2.5/beta hunt
- C200P support/debug architecture
- P2/R91 cellular lifecycle
- hcshd/cmagent/cmsd management-plane decomposition

FU8 artifact prefix:
fu_8-

FU8 során routerhez csak akkor kellett volna nyúlni, ha a statikus munka elfogy. A CP09–CP14 kör teljesen statikus/reproducible RE volt.

---

# 15. C200P „Rosetta stone” kutatás

C200P R74:
- 2.5.14-20260618-150931
- 2.5.15-20260629-160214

2.5.14 outer SHA:
a4f5f6494bcbdf41bfcd8573a22531fbd2115b5cb2769f5f44da213a900a7e98

2.5.14 inner BIN SHA:
8ba6c51d13d72d2871a1b5e8bbcb4318c2fd4234898f8c1e9e6c30502913e0e8

2.5.15 canonical outer SHA:
04fe2d3d... (lásd firmware inventory / source artifact)
2.5.15 inner SHA:
16a08d1c... (lásd firmware inventory / source artifact)

A CN alias exact UUID first-party bizonyított és byte-identical a canonical 2.5.15-tel.

2.5.14 -> 2.5.15 rootfs diff:
- ADDED 1
- REMOVED 0
- CHANGED 62
- UNCHANGED 2464
- egyetlen új file: /lib/functions/curl.sh

Instruction-level C200P support SSH flow:
- local client id marker 000000000000
- reads mac/hmac/fuuid/model
- support root password derivation C200P-specifikus
- removes /etc/rom_release
- /tmp/rom_dbg debug state
- Dropbear restart
- disable oldalon release marker vissza, rom_dbg remove, Dropbear stop

NAGYON FONTOS:
A C200P exact credential formula NEM vihető át automatikusan R25-re.
A C200P csak comparative Rosetta stone.

---

# 16. P2 / R91 kutatási ág

Exact firmware-ek:
- P2-R91-2.4.22-20251204-184925-sysupgrade.bin
  SHA 592c494eb5f44beabb427907003801845ea0d47d51db50b1d5b97d40e3166b58
- P2-R91-2.4.29-20260421-190344-sysupgrade
  stable lineage
- P2-R91-2.4.29b-20260422-101502-sysupgrade.bin
  SHA 3f8dae3d42ad6ba7d1314022eac6bc007d03fac274196b2c802f2835ab21c3f9
- P2_RG500_A09.bin
  SHA 7402449ddc19db64e42e41031d35b4a36f01e4d8b19219fcf3c4c6def897f52b
- R91-2.4.23b-20251208-CellularUpgrade.bin
  SHA 9d27fb4535dff565cd8bb632933dc8a583f514bfcb2a027c740ddee0bc4f5f13

2.4.22 -> 2.4.29 public rootfs diff:
- explicit gcom event/reup layer additions
- régi generic WWAN stack jelentős eltávolítása
- public release note szerint 4-hour cellular fix
- literal 4h timer nem került izolálásra
- causal mechanism plausible, de nem teljesen isolated

Adjacent stable/beta:
- 2380 vs 2381 entry
- unchanged 2371
- changed common 9
- beta-only /etc/rom_research

P2 soha nem automatikus R25 donor.
Hardware-specific cellular code transplant tiltott bizonyítás nélkül.

---

# 17. R25 CSP2.5 / beta hunt

Publikus R25 legújabb stock a vizsgált időszakban továbbra is:
LT500V2-R25-2.4.16-20250804-150319

A CSP2.5 support plan LT500/LT500D modelleket tartalmazott, de exact public R25 2.5.x artifact nem került elő.

A projekt kipróbált evidence-backed CSP2.5 request shape-eket.
Negatív válasz csak az exact próbált request shape-re bizonyít negatívumot.
Nem bizonyítja általában, hogy privát R25 2.5.x nincs.

TILOS:
- random UUID guessing
- random timestamp guessing
- suffix/version spraying
- brute-force firmware filename enumeration

Privát beta/support precedens:
- WR11000 exact 2.5.10b first-party comment
- WR3000S 2.5.16b thread
- LT500/LT500D családnál first-party private beta/email distribution precedent
- exact R25 CSP2.5 továbbra is UNKNOWN / NOT FOUND

---

# 18. FU8 CP10 — R25/C200P engineering correlation

CP10 kimondott cél:
identity -> FUUID/HMAC -> derivation -> debug marker/state -> Dropbear/Telnet/login -> support backend

Fő R25 2.4.16 következtetések:
- Dropbear/Telnet bdinfo dbg gate
- console/login debug gate
- hidden Terminal
- Sandbox/Telnet CBI
- exact bdinfo_check_dbg formula
- /etc/rom_release retail gate

R25-family 2.1.1 runtime log tényleges maintenance sequence-t mutatott:
- release marker eltávolítás
- flash_uuid olvasás
- bdinfo hmac
- rom_dbg írás
- root password módosítás
- Telnet/Dropbear indítás

Ez same R25 hardware family, de 2.1.1, nem exact 2.4.16 runtime proof.

hcshd statikus kép:
- RSA-authenticated command transport
- recvfrom/sendto
- RSA_public_decrypt
- system/popen command sinks
- generic Developer API-ként kitenni TILOS

Fontos credential non-equivalence:
- R25 retail firstboot: FUUID/HMAC-derived
- R25-family 2.1.1 support event: admin
- C200P support SSH: más formula

Tehát credential policy generation/product specific.

---

# 19. FU8 CP11 — caller topology

Exact R25 source alapján három külön admin/maintenance plane vált szét:

1. LuCI session-authenticated RPC
   - rpc/sys
   - rpc/app
   - rpc/sysupgrade

2. cmagent control plane

3. hcshd maintenance plane

Nem talált direct:
- cmagent -> hcshd
- rpc/app -> hcshd
- rpc/sys -> hcshd

Helyes státusz:
DIRECT_BRIDGE_NOT_FOUND_IN_EXACT_STATIC_CORPUS
nem pedig ABSENT.

---

# 20. FU8 CP12 — management dependency map

Négy réteg bizonyítható:

1. LuCI/local RPC
2. cmagent
3. cmsd
4. hcshd

Kulcstétel:
cmagent != cmsd != hcshd

És:
bdinfo checkuuid != bdinfo dbg

cmagent:
- MQTT
- ubus
- admin mode
- service_call handler ABI
- router/command
- router/config
- router/upgrade
- router/sysreport
- router/clients
- timer/ledctl stb.

cmsd:
- explicit cloud-binding layer
- stock default OFF
- luci.apprpc.system bind flow engedélyezheti
- cmsd.apprpc JSON-RPC -> luci.app proxy

hcshd:
- külön procd service
- külön RSA-gated network daemon

---

# 21. FU8 CP13 — auth/trust boundary

Stock MQTT broker:
- anonymous access nem megengedett
- JWT/ACL/certificate policy
- broker auth külön a cmagent opcionális JWT flagtől

auth_plugin_jwt.so:
- közvetlen libbdinfo.so dependency
- JWT verify
- HMAC related capability

Ebből:
a provisioning/device identity nem csak startup gate, hanem a local management broker authentication boundary része is.

cmsd exact static run:
- MQTT
- TLS/SSL
- ubus
- Lua module loader
- service_call
- direct jwt_* implementation nem került igazolásra

CMSD exact pre-Lua auth:
BINARY_PARTIAL

hcshd/libbdinfo közös RSA public trust anchor:
e68b3ce363587e59fa1cb3bccd445e395b2a1e52e6fff936b495e393106d9d60

Ez vendor trust-domain kapcsolatot bizonyít, nem direct call kapcsolatot.

Malformed/passive hcshd emulation:
receive -> RSA decrypt -> fail
command sink előtt
HCSHD_CRYPTO_GATE_PRECEDES_COMMAND_SINK = PASSIVE_EMULATION_CORROBORATED

---

# 22. FU8 CP14 — exposure és internal callers

Stock firewall:
- LAN input ACCEPT
- WAN input REJECT
- WAN forward REJECT

Nincs explicit stock MQTT WAN allow.
Nincs hcshd maintenance WAN allow.

Ezért:
- 0.0.0.0 bind önmagában NEM jelent WAN exposure-t.
- MQTT_WAN_DEFAULT = STATIC_POLICY_BLOCKED
- HCSHD_WAN_DEFAULT = STATIC_POLICY_BLOCKED
- runtime packet path = NOT TARGET MEASURED

cmagent command/config handlerhez first-party caller került elő:
- /usr/sbin/sync_command
- /usr/sbin/sync_config
- mesh/LuCI stack kapcsolatok

Következtetés:
CMAGENT_COMMAND_HANDLER_HAS_FIRST_PARTY_CALLERS = SOURCE_VERIFIED
CMAGENT_COMMAND_PLANE_PURPOSE = INTERNAL_MESH / ADMIN_SYNC CORROBORATED

Tehát cmagentet nem szabad vakon eltávolítani, és raw command runnert sem szabad Developer API-ként kitenni.

---

# 23. OpenWrt 23.05.5 frontend/integration ág

Ez külön ág a fizikai R25 unlocktól.

Target:
OpenWrt 23.05.5
ramips/mt76x8 cudy_lt500-v2

UI target:
standalone /www/cudy-static
LEDE/Cudy donor-fidelity

Szerepek:
- WS = frontend/UI/UX
- RE = donor firmware/source/binary truth
- EM = donor web/emulator evidence
- Integration/Boss = backend/adapters/build/merge

TR-069 excluded.

Wireless/WISP:
- donor-validated V67 General Settings
- config_general.lua / config_combine.lua
- wlan00 2.4G
- wlan1* 5G
- wlan2* 6G capability-dependent
- Smart Connect semantics megőrzendő
- ne rewrite-oljuk konkrét audit hiba nélkül

V69 current known cumulative frontend/integration baseline:
RE-LT500D-V69-WIP-LEDE-DASHBOARD-TRUTH-04.zip

SHA-256:
e8e2f65fedb5d30a445a221f6f868c4fc50b861a9c441693d9ea4bf5932c36e0

WS overlay:
728640dbce53590df9cbf4953656f37ccf7314600dc5a37df2f3c31492f411aa

WS big bundle:
0a0c8bbf2bcafaeb3ca43b33377740a504ca611b760f95936393c626f9459fe8

WISP/SMS/WAN/Devices UI jelentős része implementálva.
Diagnostics deep DOM korábban BLOCKED_BY_EM.
Backend blockerek között szerepelt:
- Cellular/WISP ownership
- wan2 payload
- Devices controlled-write
- wireless status CGI

Ne keverjük a V69 OpenWrt23 frontend truthot a fizikai R25 Firmware Unlock evidence státuszokkal.

---

# 24. Belkin F9K1103 v1 — hardver truth

A Belkin ág külön projekt repo:
diablomike20/Belkin-F9K1103-Firmware

Eszköz:
Belkin F9K1103 v1 / N750 DB

Ismert hardware class:
- Ralink RT3883
- kb. 500 MHz
- 64 MB RAM
- 8 MB flash
- RTL8367R-VB switch
- dual-band
- RT3091/RT3092 PCI radio family
- 2x USB 2.0
- SPI NOR
- common F9K110x family traits

NAGYON FONTOS KORREKCIÓ:
A felhasználó F9K1103 v1 eszközén használt OpenWrt 19 nem natív F9K1103 target volt.
A tényleges image:
openwrt-19.07.0-ramips-rt3883-belkin_f9k1109v1-squashfs-sysupgrade.bin

Ezért:
- F9K1109 v1 OpenWrt 19 = működő hardver-reference
- F9K1103 saját LEDE port = jelenlegi cél
- soha ne állítsuk, hogy az OpenWrt 19 image natív F9K1103 build volt

---

# 25. Belkin saját F9K1103 LEDE 17.01.5 port

A repo már nem üres ötletet tartalmaz, hanem konkrét portot:

firmware/f9k1103-lede-17.01.5/

Tartalom:
- F9K1103.dts
- build-lede-17.01.5.sh
- host-glibc compatibility patch-ek
- README
- custom image recipe / board-detection módosítások

Board evidence:
- RT3883
- 8 MiB SPI NOR
- U-Boot 0x000000..0x02ffff
- env 0x030000..0x03ffff
- factory 0x040000..0x04ffff
- firmware 0x050000..
- user-cfg 0x7f0000..
- RTL8367R-VB
- SMI GPIO 1/2
- LAN 0..3
- WAN 4
- CPU switch link 5
- Reset GPIO 25
- WPS GPIO 26
- Power GPIO 0
- LAN GPIO 13
- WAN GPIO 12
- USB GPIO 9
- factory + 0x0000 SoC radio calibration
- factory + 0x8000 PCI radio calibration
- stock-family uImage name N750F9K1103VB
- stock evidence HW_WAN_MAC / HW_LAN_MAC

Ez nem RT-N56U binary rename.

---

# 26. LEDE 17.01.5 build — handoff pillanatának legfrissebb állapota

Korábbi build sorozat több lzma-loader/platform hibán elbukott.

2026-10-02-én a helyzet megváltozott:
TÖBB SUCCESS build készült.

## Clean direct-LZMA candidate — jelenlegi elsődleges statikus jelölt

Workflow run:
36964886797

Head:
ee79c687cffee78d274a3da63a3bec53a34ed19b

Artifact:
F9K1103-v1-LEDE-17.01.5-PORT-WIP

Artifact ID:
11210566323

Artifact digest:
c65093267c986af949aab7071c4e4c5d4b021454d249862579509e0b9344b4c6

LEDE source commit:
248b35890339d70d7b43e3b40fba0281f854ed9a

Sysupgrade:
lede-ramips-rt3883-f9k1103-squashfs-sysupgrade.bin

SHA-256:
b78106c7509a31f886682e9d071f6d41fdaee7bd6f209add4a4aa6b61a9f0622

Méret:
3,670,185 byte

Initramfs SHA:
ec8c0d181804c27f2ceda71f6110a82b1dcd1e6c0cd178cc2c3f0e93787af1da

Static validation:
- uImage magic 0x27051956
- uImage name N750F9K1103VB
- outer compression LZMA
- load 0x80000000
- entry 0x80000000
- header CRC PASS
- payload CRC PASS
- SquashFS found
- fits upstream image limit
- fits physical partition
- VALIDATION PASS

STATUS:
STATIC_VERIFIED
PHYSICAL_BOOT = TARGET_REQUIRED

## Direct-LZMA candidate

Run:
36964149495

Head:
7ce3aa38ab4781bbe9a7f24885879702c1fe6bc1

Artifact ID:
11210308702

Sysupgrade SHA:
67c4b54e108256a38a879873c7c2f267b3ec945413b53b10e0361b06c2170444

Initramfs SHA:
829b0e19a5140d27d0c90b2d75d04a8eb438f6a7bf1870689e6b0dcb0e35fa09

Méret:
3,670,185 byte

STATUS:
STATIC_VERIFIED
TARGET_REQUIRED

## Minimal boot baseline

Run:
36964690258

Head:
2bf62b1ee82246b9ea59d6f904427f2048d74e28

Artifact ID:
11210213174

Sysupgrade SHA:
a918447c22de77e2e446d0950cc119a5b47bfe14f3af43962df4d787b9f328c9

Méret:
3,342,505 byte

Initramfs SHA:
784cb062e6d238712469b4d3bb61295ab0cd735ffa725d24b5cd10f9ff1bf592

STATUS:
STATIC_VERIFIED
TARGET_REQUIRED

A három firmware fizikailag még nincs boot-verified.

---

# 27. Belkin más build ágak

OpenWrt 23.05.5 F9K1103 port:
- BUILD SUCCESS
- STATIC VALIDATION PASS
- hardware runtime nem igazolt
- repo workflow run 36031900371 / current migrated run
- artifact F9K1103-v1-OpenWrt-23.05.5-PORT-WIP

ImmortalWrt 18.06 F9K1103 port:
- BUILD SUCCESS
- STATIC BUILD
- hardware runtime nem igazolt
- workflow run 36031917929
- artifact F9K1103-v1-ImmortalWrt-18.06-PORT-WIP

Ezek fontos fallback/reference ágak, de a felhasználó most a LEDE 17.01.5 irányt tette elsődlegessé.

---

# 28. Miért LEDE 17.01.5 az elsődleges Belkin base

A donor firmware audit szerint a vizsgált Cudy stock firmware-ek jelentős része ugyanarra a LEDE 17.01.5 userspace lineage-re épül.

Vizsgált donorok:
- LT500D R25 2.4.16
- WR1200 V2 / R26 1.17.4
- WR1200 V2 / R26 2.1.1
- WR1200 V2 / R26 2.2.8
- WR1200 V2 / R26 2.4.12
- WR1200 V2 / R26 2.4.23
- WR1300 R10 1.13.6
- WR2100 R11 1.14.25

Ezért Cudy LuCI/Lua/UCI/init semantics szempontból LEDE 17.01.5 sokkal természetesebb port target, mint OpenWrt 19.

Viszont hardware truth:
F9K1109/OpenWrt 19 referenciát továbbra is használni kell board/switch/radio/USB/boot viselkedéshez.

A javasolt architektúra:

F9K1103 hardware
-> natív LEDE 17.01.5
-> Belkin board/hardware adapter
-> Cudy userspace/UI layer
-> Cudy-specific binary hardware assumptions kiszűrése

---

# 29. Cudy donor firmware audit a Belkin porthoz

A donor acquisition/audit SUCCESS lett.

Artifact:
belkin-cudy-donor-firmware-corpus-and-audit

Artifact ID:
11206815616

Artifact digest:
67faaafe219143ec262d06419b815a819e23fb6ae7b67826bf927e096e3ca8b1

Corpus tartalom:
- LT500V2-R25-2.4.16 stock
- WR1200V2-R26 1.17.4
- WR1200V2-R26 2.1.1
- WR1200V2-R26 2.2.8
- WR1200V2-R26 2.4.12
- WR1200V2-R26 2.4.23
- WR1300 R10 1.13.6
- WR2100 R11 1.14.25
- OpenWrt 19.07.0 F9K1109
- OpenWrt 19.07.10 F9K1109
- OpenWrt 19.07.10 Cudy WR1000

A rootfs összehasonlítás alapján különösen erős donor:
WR1200 V2 2.4.12 / 2.4.23.

LT500D 2.4.16-hoz viszonyítva a korábbi auditból:
- UI path similarity körülbelül 81.5%
- a common UI file-ok körülbelül 93.7%-a byte-identical
- common UI file count körülbelül 445

Ezért a Belkin Cudy port elsődleges UI/userspace donor stratégiája:

1. WR1200 V2 2.4.x — kis flash / egyszerűbb router / modern Cudy UI
2. LT500D R25 2.4.16 — mélyen reverse-engineered Cudy backend/UI semantics
3. WR1300/WR2100 — gigabit/switch/router-feature referencia
4. WR1000 — 8MB/64MB OpenWrt resource-class reference, de az exact régi OEM Cudy payloadot a Wayback körben nem sikerült biztosan visszaszerezni

---

# 30. Belkin portnál mit szabad és mit nem

PORTOLHATÓ:
- Cudy HTML/CSS/JS
- LuCI view-k jelentős része
- navigation / dashboard
- általános System UI
- LAN/DHCP/WAN
- DNS/firewall/NAT/DMZ/port forwarding
- Diagnostics/logs
- megfelelő OpenWrt package rendelkezésre állás esetén VPN UI
- Developer read-only koncepció
- OpenCudy branding/theme
- feature registry semantics

ADAPTEREZENDŐ:
- wireless data source
- switch/VLAN
- WAN/LAN interface identity
- Devices client list
- LED/button
- USB
- hardware status
- firmware updater
- sysupgrade
- package management
- service state

NEM SZABAD VAKON ÁTVINNI:
- MT7628/MT7663 Cudy driver/binary stack
- R25 bdinfo device identity
- R25 MTD layout assumptions
- EC200A cellular stack
- gcom/mcore hardverfüggő részek
- Cudy-specific kernel modules
- hcshd raw maintenance interface
- cmagent raw command executor
- cmsd cloud credentials/provisioning
- Cudy hardware binaryk pusztán azonos MIPS miatt

A Belkin RT3883/OpenWrt target ABI és a Cudy 24kc binaries kompatibilitása nem feltételezhető automatikusan.

---

# 31. Belkin flash méret és resource constraint

F9K1103:
- 8 MiB flash
- 64 MiB RAM

Ez a Cudy port legfontosabb korlátja.

Nem reális:
„teljes LT500D rootfs + teljes OpenWrt/LEDE base” egyszerű összeöntése.

Reális:
minimal LEDE base
+ kiválasztott Cudy frontend/userspace
+ kisméretű adapter backend
+ csak szükséges package-ek

A WR1200 V2 fontos donor, mert modernebb Cudy UI-t visz kisebb firmware footprintben.

---

# 32. A projekt felhasználói munkastílus-szabályai

A felhasználó magyarul dolgozik.
Rövid parancsok:
- hajrá
- mehet
- csináld
- folytasd

jelentése:
**ténylegesen folytasd a munkát, ne csak tervet írj.**

Ne kérdezz újra olyat, amit már tudunk.
Komplex tasknál best effort végrehajtás kell.

Rendszeresen készíts letölthető checkpointot, mert a chat/session hosszkorlát problémát okozott.

Router command heading, ha szükséges:
**SSH terminálba:**

BusyBox/ash kompatibilitás.

Reboot:
- ne ismételjük feleslegesen
- csak konkrét okkal
- read-only probe előnyben
- major physical test előtt külön gate

Fizikai flash:
- ne legyen automatikus
- Candidate47 csak explicit user choice
- Belkin LEDE physical test is explicit user choice
- statikus build success nem flash-engedély

---

# 33. Tiltások és invariánsok

- TR-069/CWMP nem kerül vissza.
- bdinfo-t nem írjuk.
- nem brute-force-olunk firmware UUID/timestamp/suffix kombinációkat.
- nem random scan.
- más modell firmware-ét nem nevezzük target truthnak.
- nem írjuk újra Wireless/WISP részt konkrét audit hiba nélkül a 23.05.5 UI ágban.
- nem piszkáljuk az R25 működő 4G baseline-t mellékesen.
- H09 OPKG backend frozen.
- Developerben nincs generic arbitrary shell/ubus/path/service/MTD/GPIO/AT endpoint.
- raw hcshd nem lesz általános Developer feature.
- raw cmagent command runner nem lesz általános Developer feature.
- normal Cudy feature nem lesz mesterségesen Developernek átminősítve.
- no fake data.
- OpenWrt23 frontend backend blocker esetén Integration required, nem frontend workaround.
- R125 Portal HOLD auth stabilitásig.
- R125_2 incident archive, nem decision truth.
- Candidate-02 R100-R25 CSP2.5 superseded/revoked.

---

# 34. Handoff utáni legelső munka — kötelező prioritás

1. A három SUCCESS LEDE 17.01.5 candidate forrás- és image-diffjének lezárása.
2. Clean direct-LZMA candidate legyen elsődleges static baseline, amíg ellenkező bizonyíték nincs.
3. Készíts fizikai F9K1103 boot-test missiont, de NE flash-elj automatikusan.
4. Első fizikai proof lehetőleg recovery/initramfs/rollback-tudatos és minimális kockázatú legyen.
5. Fizikai boot után ellenőrizendő:
   - bootloader acceptance
   - kernel boot
   - flash/MTD layout
   - LAN/WAN switch
   - RTL8367R-VB
   - 2.4 GHz
   - 5 GHz
   - MAC extraction
   - LEDs/buttons
   - USB
   - LuCI/login
   - sysupgrade semantics
   - recovery path
6. Csak PHYSICAL_BOOT_VERIFIED LEDE base után kezdődjön a Cudy userspace beemelése.
7. Cudy port első donorja WR1200 V2 2.4.x + LT500D 2.4.16 semantics.
8. Cudy integration rétegeket egyenként, regressziós gate-ekkel:
   - base theme/assets
   - LuCI framework
   - navigation
   - dashboard
   - system
   - LAN/DHCP
   - wireless adapter
   - WAN
   - Devices
   - Advanced
   - optional USB
   - Developer/OpenCudy extensions
9. Minden nagy lépés után build + static diff + fizikai target gate, amikor a user engedélyezi.

---

# 35. Párhuzamosan megőrzendő ágak

A Belkin prioritás miatt NEM szabad elveszíteni:

A) Cudy R25 FU8 management-plane RE
- CP10–CP14
- hcshd provenance nyitott
- cmagent inbound parser utolsó részletei nyitottak

B) R25 CSP2.5 / support-private-beta hunt
- exact R25 public 2.5.x továbbra sem talált
- no spray

C) R125 CSP2.5 hybrid
- auth frozen
- Portal HOLD
- Cloud bind unresolved
- Wireless 5G UI/data-binding issue
- hardware/userland hybrid truth megőrzendő

D) OpenWrt 23.05.5 V69 frontend/integration
- Truth-04 + WS bundles
- separate evidence domain

E) Candidate47
- image format verified
- physical boot not done

---

# 36. Kulcs GitHub repository-k

Belkin firmware:
https://github.com/diablomike20/Belkin-F9K1103-Firmware

Cudy/forensic workflow repo:
https://github.com/diablomike20/Website-downloader

Router Emulator:
https://github.com/diablomike20/Router-Emulator

FirmAE upstream:
https://github.com/pr0v3rbs/FirmAE

Belkin új fejlesztés:
KIZÁRÓLAG a Belkin-F9K1103-Firmware repóban.
Router-Emulator régi Belkin munkákhoz csak read-only evidence lehet.

---

# 37. Fontos firmware/hash rövidlista

R25 stock:
57aed945a9f485d178d73a844e420fc2b441e60821e243d3d19d07dd4a3143d6

Candidate47 sysupgrade:
8d51bc017a3e275c0ce3a5c05a659a4a3c4f55bb96370d0fabc81f3d1470a060

Candidate47 fullflash:
7118cfd798da459fc7d5ea0350501ec4a5bd088e0449d953dabf15929f89694f

R100-R25 Candidate-02, revoked:
47290d1c168c7991decdbedfdf1a12821a5fe9df237b1510960c00eac5311a52

V69 Truth-04:
e8e2f65fedb5d30a445a221f6f868c4fc50b861a9c441693d9ea4bf5932c36e0

Belkin LEDE clean direct sysupgrade:
b78106c7509a31f886682e9d071f6d41fdaee7bd6f209add4a4aa6b61a9f0622

Belkin LEDE minimal sysupgrade:
a918447c22de77e2e446d0950cc119a5b47bfe14f3af43962df4d787b9f328c9

Belkin LEDE direct-LZMA sysupgrade:
67c4b54e108256a38a879873c7c2f267b3ec945413b53b10e0361b06c2170444

P2 stable 2.4.22:
592c494eb5f44beabb427907003801845ea0d47d51db50b1d5b97d40e3166b58

P2 beta 2.4.29b:
3f8dae3d42ad6ba7d1314022eac6bc007d03fac274196b2c802f2835ab21c3f9

P2 RG500:
7402449ddc19db64e42e41031d35b4a36f01e4d8b19219fcf3c4c6def897f52b

R91 CellularUpgrade:
9d27fb4535dff565cd8bb632933dc8a583f514bfcb2a027c740ddee0bc4f5f13

C200P 2.5.14 package:
a4f5f6494bcbdf41bfcd8573a22531fbd2115b5cb2769f5f44da213a900a7e98

R25 libbdinfo:
dc2ac9f10739eb1f690acf3fbd9e17d8f824673f7faa7173db3894faa4cfc15b

hcshd/libbdinfo shared RSA trust anchor:
e68b3ce363587e59fa1cb3bccd445e395b2a1e52e6fff936b495e393106d9d60

---

# 38. Mikor nevezhető a Belkin Cudy port valóban sikeresnek

Nem akkor, amikor a firmware lefordul.

Minimum acceptance:

Phase A — native LEDE:
- build reproducible
- static validation PASS
- physical boot PASS
- recovery PASS
- LAN/WAN PASS
- Wi-Fi 2.4/5 PASS
- MAC/calibration correct
- USB PASS
- LuCI login PASS
- sysupgrade lifecycle PASS

Phase B — Cudy UI:
- Cudy login/UX stable
- no fake data
- navigation complete
- system/LAN/DHCP live
- wireless live
- WAN live
- Devices live
- error states stable

Phase C — Cudy feature adaptation:
- Advanced functions evidence-driven
- USB only if hardware/runtime supports
- VPN only with actual packages/backend
- Developer engineering layer safe
- package manager resource-safe
- no Cudy R25 hardware binaries used blindly

Phase D — final:
- reboot persistence
- upgrade persistence
- config backup/restore
- recovery path
- regression matrix
- full artifact/hash manifest

---

# 39. Jelenlegi végső állapot egy mondatban

A Cudy LT500D R25 projekt már mély, több rétegben fizikailag és statikusan bizonyított engineering rendszerrel rendelkezik; a FU8 a vendor management/debug architecture jelentős részét lezárta; közben a Belkin F9K1103 v1 natív LEDE 17.01.5 port 2026-10-02-án végre több SUCCESS buildet produkált, ezért a Firmware Unlock 9 elsődleges feladata most ennek a LEDE baseline-nak a fizikai bizonyítása, majd a WR1200/LT500D-alapú Cudy userspace kontrollált portolása.
