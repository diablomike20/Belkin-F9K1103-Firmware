# RE — F9K1103 Cudy source-first recovery evidence

## Scope

This branch repairs the Belkin F9K1103 Cudy port from source evidence only.

It is **not** based on a historically working Cudy-on-F9K1103 firmware. No such functional baseline existed.
The physical WIP03 RADIOFIX is used only as the exact booted/broken target source point.

## Exact target source

- Repository: `diablomike20/Belkin-F9K1103-Firmware`
- Physical repack source point: `eff1b55f6b9399c7c85e6208a8aa295a6fbe7e61`
- Base WIP03 build source identified by the repack script: `8aca39b3a52e037ad530ee14f03cf6ef82ecdc7e`
- Physically flashed image SHA-256: `1c5418cb11093c368e7b519f375533277803c1d0225e4ad680626aef57a27560`
- Physical result: boot/LAN/SSH PASS, full Cudy runtime FAIL/UNVERIFIED.

## Exact functional donor

Primary Cudy donor:

- WR1200V2 R26 2.4.23
- donor ZIP SHA-256: `def1d4b8472b5fef4d0f13d337d6c2f11127d14ef6bd7100780dbac0115aa35c`
- donor flash BIN SHA-256: `b9842ca6d6b54d4d2b8bb4d13457ee674ba2d13540443af1cf1ce82708ea02cd`

Secondary donor LT500D R25 2.4.16 is only for deeper Cudy semantics where WR1200 evidence is insufficient.

## Proven target architecture mismatch

The WIP03 build imports almost all donor `/usr/lib/lua/luci` and `/www` content while deliberately retaining/replacing several target-native runtime layers:

- donor `*.so` LuCI modules excluded;
- donor CGI launcher excluded;
- donor dispatcher replaced with `dispatcher-lede-cudy.lua`;
- donor auth JavaScript replaced with `sysauth-lede-cudy.js`;
- donor network defaults not imported;
- donor opaque/vendor runtime binaries not imported;
- target-native `mcore.lua` and `bdinfo` compatibility shims used.

Therefore the original port was a hybrid donor-UI / target-LEDE runtime and was never functionally verified.

## Proven login incompatibility 1 — password DOM field

Exact broken target adapter used `#luci_password_login` / `#luci_password_create`.

The donor login template actually uses `#luci_password2`.

Minimal source fix:
`$('#luci_password_login, #luci_password2').first()`

Recovery commit:
`53fe431f7b2d0be087828ee0135039490bc3dfdc`

Status: **CAUSE_VERIFIED / MINIMAL_DELTA_APPLIED**

## Proven login incompatibility 2 — language metadata

Physical firstboot log recorded:

- failed `themes/bootstrap/sysauth`;
- `bad argument #1 to 'find' (string expected, got nil)`.

Donor template resolves `conf.languages[lang]` and then calls `string.find(lang, "%(")` without checking nil.

Minimal compatibility delta:
`if lang and string.find(lang, "%(") then`

Status: **CAUSE_VERIFIED / MINIMAL_DELTA_APPLIED**

## Proven login incompatibility 3 — broker metadata

The donor template expects `cmagent.mqtt.broker`; the target compatibility environment does not guarantee a value.

Minimal compatibility delta:
`local broker = uci:get("cmagent", "mqtt", "broker") or ""`

Status: **DIFF_VERIFIED / TARGET_COMPATIBILITY_APPLIED**

## Proven bootstrap index contract mismatch

LEDE `view/indexer.htm` includes `themes/<theme>/indexer`.

The Cudy bootstrap theme supplies its Dashboard as `themes/bootstrap/index.htm`.

Minimal bridge:
`themes/bootstrap/indexer.htm -> <% include("themes/bootstrap/index") %>`

Status: **CAUSE_VERIFIED / MINIMAL_DELTA_APPLIED**

The build script now gates all four compatibility deltas both before build and in the emitted rootfs.

Recovery commit:
`3da9bb9f93974052a02d3e95387dfb75e74a7ba2`

## Auth contract

Correct source contract:

`admin web identity -> root password verifier -> admin session identity`

Do not convert the LuCI session identity to root.

A later FU9 livefix did so. Captured live evidence then showed an active `user=root` session while the donor `gui.lua` registry is keyed by `admin`; `show_section(authuser, section)` directly indexes that registry. This is sufficient to explain the captured top-level Dashboard nil-index during that experimental state.

Status: historical root-session failure **CAUSE_VERIFIED**.

The remaining post-AUTH-RESTORE white Dashboard is a separate current-target question.

## Current runtime gate

No modifying Dashboard patch may be added until the post-AUTH-RESTORE target is re-captured with the read-only Dashboard forensic collector.

Required evidence includes:

- current dispatcher/sysauth/indexer hashes;
- current ubus session user;
- `gui.show_section("admin","carousel")`;
- `gui.show_section("admin","status")`;
- main Dashboard HTTP result;
- each visible carousel/status fragment result;
- current LuCI/uhttpd error log;
- helper/package/UCI dependency state.

Current status: **TARGET_REQUIRED**

## WAN and Wi-Fi firstboot gaps

Physical firstboot evidence proves:

- WAN network exists as target LEDE `network.wan`, but the donor visibility resolver also expects Cudy mode metadata;
- radio mapping is physically correct:
  - `radio0 -> wlan00 -> 2.4 GHz`
  - `radio1 -> wlan10 -> 5 GHz`
- both target radios were `disabled='1'`, so no AP was advertised.

No WAN-mode or radio-enable source change is allowed on this branch until the exact working donor network/wireless file and hash are available and diffed against the target.

Current status: **SOURCE_GAP**

## Branch rule

Never merge the accumulated root-session / `auth_allowed` / uhttpd-Lua-handler livefix experiments into this branch.

Every future runtime change must satisfy:

`exact current source -> exact working donor -> diff -> proven cause -> minimal port/adapter -> verify`


## Probe-03 current-target closure — mcore/Devices

Current physical target capture:

- `/usr/lib/lua/mcore.lua` SHA-256:
  `8978851ee5d90afd332843268eac287522a1952116a3a56ccfd043006d45dec0`
- `/usr/lib/lua/luci/util.lua` SHA-256:
  `780115cf7d9daadc94a301d564928f02b52bc43c24a0541e9f0b92ffac51e196`
- runtime:
  `util.shellquote=nil`
- runtime:
  `mcore.devlist.ok=false`
- exception:
  `/usr/lib/lua/mcore.lua:93: attempt to call field 'shellquote' (a nil value)`

Exact Dashboard stack evidence proves the donor and WIP03 Devices consumer files are byte-identical and both consume `mcore.devlist()`.
The exact donor/WIP03 `luci.util` contract does not provide `shellquote`.

The target adapter accepts wireless interface names only through:
`^([%w%._%-]+)%s+ESSID:`

Therefore removing the two nonexistent `util.shellquote()` calls changes no donor-facing contract and closes the observed runtime exception without introducing a helper or wrapper.

Minimal source fix commit:
`dd2648d8d7645fadae768254778778a4451e5394`

Build/rootfs regression gate commit on the verified recovery branch:
`e38b651528a429d925a2369c89756766bcf57fb4`

Status:
**CURRENT_SOURCE_VERIFIED / DONOR_CONTRACT_VERIFIED / DIFF_VERIFIED / CAUSE_VERIFIED / MINIMAL_DELTA_ONLY**

Physical post-fix runtime verification is still required before TARGET_VERIFIED status.

## Probe-03 limitations

Probe-03 successfully established the RAM ubus session value `user=admin` and current live hashes.

Its direct CGI harness did not reproduce uhttpd cookie/session propagation: each route rendered sysauth despite the valid RAM session. Therefore the CGI route outputs are **HARNESS_INVALID** and must not be classified as Dashboard failures.

The old `sysauth lang=nil` messages in logread are historical. The current captured `sysauth.htm` already contains the language guard, broker guard, password-field adapter and bootstrap indexer bridge.

## Exact donor network/Wi-Fi files now inspected

WR1200V2 R26 2.4.23:

- `/etc/uci-defaults/30_wlan`
  SHA-256 `afc224d991472e5f3eba394bae084a88db4b96da1141541185fe602b41ed273a`
- `/etc/uci-defaults/01_network`
  SHA-256 `f66eb8824f2d9555bd1fc74386598113d3fbfd233a21afe3ad7b292843bc0015`

Exact flashed WIP03 runtime adapter:

- `/etc/uci-defaults/95-f9k1103-cudy-runtime`
  SHA-256 `bf6360eff4cc55cca131e7f520bfb525dc2c087c3d67c59ed84afdec21825c5d`

Findings:

- donor `30_wlan` proves Cudy primary SSID/security defaults for `wlan00/wlan10`;
- donor `30_wlan` does **not** prove deleting `wireless.radio0.disabled` or `wireless.radio1.disabled`;
- donor `01_network` creates WISP metadata and WAN metric but does **not** write `network.wan.mode='wan'`.

Therefore the parallel WAN/Wi-Fi runtime commits that added those writes are not accepted into the verified recovery branch yet.

Status:
**SOURCE_GAP** for the exact donor writer of WAN role metadata and for the exact donor rule responsible for primary-radio enabled state.

## Branch contamination event

The earlier branch `re-f9k1103-cudy-source-first-recovery` received six parallel commits after `dd2648...`, including WAN/Wi-Fi runtime changes. One build-gate commit (`f4c3eab...`) also malformed the build script by concatenating shell lines and duplicating a large section.

That branch is no longer an authoritative recovery source.

Authoritative continuation branch:

`re-f9k1103-cudy-source-first-recovery-verified`

Base:
`dd2648d8d7645fadae768254778778a4451e5394`

Only proven mcore regression gating has been added after that base.
