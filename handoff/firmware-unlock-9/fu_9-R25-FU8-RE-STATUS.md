# FU9 — R25 Firmware Unlock / FU8 reverse-engineering status

## Scope

This document freezes the R25/FU8 state so Firmware Unlock 9 does not repeat solved reverse engineering.

Target:
Cudy LT500D V2.0 / R25
Stock firmware:
LT500V2-R25-2.4.16-20250804-150319-flash.bin
SHA256:
57aed945a9f485d178d73a844e420fc2b441e60821e243d3d19d07dd4a3143d6

## Physical baseline

- MT7628AN
- MIPS24KEc
- Linux 4.4.140
- 128 MiB RAM
- 16 MiB NOR
- EU / DE
- Quectel EC200A-EL
- modem FW EC200AELV1LAR02A03M08
- cdc_ether -> usb0
- network.4g works

4G is frozen regression-sensitive truth.

## Stock access architecture

Exact stock evidence proves:
- Dropbear uses bdinfo dbg gate
- Telnet uses bdinfo dbg gate
- preinit console behavior depends on debug state
- login.sh has debug direct-shell path
- hidden admin/system/terminal exists
- luci.forbidden blocks Terminal
- Terminal CBI can call luci.util.exec
- Sandbox/Telnet CBI exists
- stock firstboot root credential is FUUID/HMAC-derived
- platform upgrade uses OEM validation path
- OTA/autoupgrade exists
- provisioning services use bdinfo checkuuid

## Exact Factory Debug

libbdinfo SHA:
dc2ac9f10739eb1f690acf3fbd9e17d8f824673f7faa7173db3894faa4cfc15b

Exact bdinfo_check_dbg:
- raw /proc/sys/dev/flash_uuid read
- newline retained
- HMAC
- literal @2025
- SHA256
- lowercase hex
- exactly 64 bytes
- /etc/rom_dbg
- strcmp validation

Retail gate:
- /etc/rom_release

Never write bdinfo.

## CP10 — R25/C200P correlation

Established:
- exact R25 debug/access chain
- R25-family older runtime support sequence exists
- C200P provides architecture corroboration
- credential formulas are not universal

Older R25-family 2.1.1 log showed a real maintenance sequence including release-state change, identity/HMAC reads, debug-state creation, support root credential adjustment and shell-service starts.

This is runtime evidence for the R25 family, not proof that exact 2.4.16 support session is byte-for-byte identical.

## CP11 — caller topology

Separated:
- LuCI RPC plane
- cmagent plane
- hcshd plane

Direct source bridge not found:
- cmagent -> hcshd
- rpc/app -> hcshd
- rpc/sys -> hcshd

Correct classification:
DIRECT_BRIDGE_NOT_FOUND_IN_EXACT_STATIC_CORPUS

Do not upgrade that to ABSENT.

## CP12 — four-plane management model

1. LuCI/local RPC
2. cmagent
3. cmsd
4. hcshd

cmagent:
- MQTT
- ubus
- service_call handler system
- router command/config/upgrade/sysreport/clients/timer/ledctl etc.

cmsd:
- stock default disabled
- explicit cloud-binding role
- cmsd.apprpc bridges JSON-RPC toward luci.app

hcshd:
- independent procd daemon
- UDP/socket
- RSA-gated processing

Key distinctions:
cmagent != cmsd != hcshd
bdinfo checkuuid != bdinfo dbg

## CP13 — authentication/trust boundary

Broker:
- anonymous false
- JWT/ACL/certificate layer
- auth_plugin_jwt.so present

auth_plugin_jwt:
- libbdinfo dependency
- JWT verify
- HMAC-capable path

Interpretation:
device identity/provisioning is integrated into management-broker auth, not only boot/service startup.

cmsd:
- MQTT/TLS/ubus/Lua native transport/dispatcher
- no direct jwt_* implementation established
- exact pre-Lua auth remains BINARY_PARTIAL

hcshd:
- passive malformed-input emulation shows crypto gate before command sink
- no valid request reproduction is required for architecture proof

Shared RSA public trust anchor:
e68b3ce363587e59fa1cb3bccd445e395b2a1e52e6fff936b495e393106d9d60

Found in hcshd and libbdinfo trust inventory.

This proves common vendor trust domain, not a direct runtime call.

## CP14 — exposure/internal callers

Stock firewall static state:
- LAN input ACCEPT
- WAN input REJECT
- WAN forward REJECT

No explicit stock MQTT/hcshd WAN opening was found.

Therefore:
- a 0.0.0.0 listener is not evidence of WAN reachability
- MQTT_WAN_DEFAULT = STATIC_POLICY_BLOCKED
- HCSHD_WAN_DEFAULT = STATIC_POLICY_BLOCKED
- runtime packet-path remains separate target evidence

cmagent command/config has first-party callers:
- sync_command
- sync_config
- mesh/admin synchronization paths

Therefore:
- cmagent command support is not an orphan hidden function
- do not blindly remove cmagent
- do not expose raw command runner as Developer API

## H09 / Developer / C27 relationship

FU8 does not replace the proven OpenCudy target baseline.

H09 OPKG:
TARGET + LIFECYCLE VERIFIED

Developer V2 read-only:
TARGET VERIFIED

Developer V4 CLEAN-06:
C27 target verified

C27:
physically verified cumulative runtime package lineage

Candidate47:
format accepted / sysupgrade -T target verified
boot unproven

## C200P correlation rule

C200P is a Rosetta stone:
- useful for architectural corroboration
- useful for support/debug control-plane evolution
- useful for identifying recurring marker semantics

Never copy C200P exact credential/debug formulas into R25 unless R25 itself proves them.

## Remaining FU8 gaps

Keep open unless later evidence closes them:

1. exact R25 2.4.16 hcshd legitimate upstream sender/controller provenance
2. exact cmagent native inbound parser/control-flow completion
3. exact 2.4.16 support-session credential policy
4. full bdinfo_check_uuid algorithm and failure semantics if no later exact disassembly closes it
5. exact relation of hcsh/hcshd/rpc/app/rpc/sys/cmagent support controller paths
6. runtime firewall reachability only if a future read-only physical measurement is justified

## Do-not-repeat list

Do not:
- re-reverse stock access gates from zero
- redo known C200P comparison from scratch
- brute-force R25 CSP2.5 UUID/timestamps
- random firmware suffix spray
- write bdinfo
- turn architecture analysis into a generic remote command recipe
- classify listener binding as external exposure without firewall/routing proof
