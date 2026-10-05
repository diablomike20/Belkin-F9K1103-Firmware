# RE — Cudy donor base selection 02

## Decision

**PRIMARY USERSPACE BASE: Cudy WR1200E R62 / CSP 2.4.25**

Exact stock artifact:

- `WR1200E-R62-2.4.25-20260114-184136-flash.zip`
- ZIP SHA-256: `2e9a8dafc930a2070d45f706ec5d362428475044dcd791232f86eee7b9f4ef21`
- flash BIN SHA-256: `086055b0227910f9ddabbb13bfa6b06a3850105bd46a3572b76116bf5a3043fa`
- LEDE 17.01.5
- Cudy 2.4.25
- ramips/mt7628
- mipsel_24kc

This supersedes the preliminary WR1200V2-primary decision from Selection-01.

## Why WR1200E wins

1. Same resource class as the Belkin port target: 8 MiB NOR / 64 MiB RAM class.
2. Native dual-band Cudy firmware, therefore the Cudy runtime already owns both 2.4 GHz and 5 GHz GUI/runtime semantics.
3. Newer stable 2.4.25 Cudy branch.
4. Very close to the already reverse-engineered WR1200V2 2.4.23:
   - 447 common LuCI/www paths
   - 427 byte-identical
   - **95.53% identical common UI**
5. Exact shared core files with WR1200V2 and WR300S include:
   - `/bin/config_generate`
   - `/etc/uci-defaults/01_network`
   - `/etc/uci-defaults/30_wlan`
   - `/etc/uci-defaults/40_luci-wireless`
   - `luci.model.network`
   - `luci.tools.status`
   - `description.lua`
6. It carries both Cudy radio wrappers:
   - `lib/wifi/radio0-mt7628.sh`
   - `lib/wifi/radio1-mt7663e.sh`
7. Unlike WR300S 2.4.25, the audited rootfs does not add `cmagent` or `mosquitto` runtime baggage.
8. Its stock image/rootfs size class is essentially the same as WR1200V2 and comfortably below the much larger WR300S stock rootfs segment.

## WR300S result

WR300S R93 / 2.4.25 is a much stronger donor than initially assumed.

Exact stock evidence:

- ZIP SHA-256: `812e43fdacb0e4c90f86f62f7118a7685ec3b35081064534926cb7d5466c2685`
- BIN SHA-256: `f6c98113c32cb28c0133cfc6f8f88c5ac1b5b358c6474d519924fd0dbe370795`
- 95.24% byte-identical common LuCI/www paths with WR1200V2.
- 505 runtime-relevant files identical to WR1200V2; only 23 different in the audited subset.
- `30_wlan`, `40_luci-wireless`, wireless controller and almost all wireless CBI models are byte-identical.
- `30_wlan` contains full `radio1` / `wlan10` / `wlan12` / 5 GHz handling despite the physical WR300S being single-band.
- WR300S `99_oem` explicitly creates `wireless.radio1` with `hwmode=11anac` when absent.
- `wds_config.lua` bytecode contains both `wlan10` and `wlan00`.

Therefore WR300S is not a single-band-only software fork.

However it loses to WR1200E as primary because:
- its physical/runtime profile does not expose 5 GHz in the stock emulator;
- its `gui.lua` differs and the token scan does not expose the WR1200-style `wireless_5g` descriptor;
- it adds `cmagent`, `mosquitto` and mesh/runtime components;
- its stock SquashFS segment is materially larger;
- choosing it would require an unnecessary 5 GHz visibility/identity adapter when WR1200E 2.4.25 already provides native dual-band behavior.

Classification: **SECONDARY 2.4.25 FRAMEWORK / PORT-METADATA DONOR**.

## WR1200V2 result

WR1200V2 R26 / 2.4.23 remains the most valuable proven reference donor because:
- its exact Dashboard stack and resolver have already been deeply reverse-engineered;
- it is native dual-band;
- the target mcore adapter was developed/physically validated against this lineage;
- its stock compressed SquashFS is known at 5,242,960 bytes.

Classification: **REFERENCE / FALLBACK DONOR**, not primary base.

## Target ownership

The donor identity does not have to match the physical Belkin.

Preserve from Belkin / target-native layer:
- kernel and RT3883 platform
- DTS/board support
- flash layout and safe image envelope
- RTL8367R switch mapping
- physical radio drivers and calibration
- MAC/factory data ownership
- sysupgrade/recovery safety

Preserve from WR1200E 2.4.25 unless a proven hardware dependency requires adaptation:
- Cudy userspace
- LuCI controller/model/view
- Cudy UCI schema/default semantics
- Dashboard/Setup/Wizard
- VPN/WISP/network feature framework
- local Cudy web assets
- Cudy runtime scripts and services that are platform-independent

Belkin adapter must override the WR1200E board metadata where physical topology differs:
- target has 5 Ethernet ports (1 WAN + 4 LAN)
- WR1200E donor reports 4 ports (1 WAN + 3 LAN)
- switch/VLAN physical mapping is target-owned

Do not port donor kernel modules, bootloader, factory/calibration or MT7628/MT7663 hardware drivers as target hardware truth.

## Next build architecture

```
Belkin F9K1103 boot/image envelope
+ Belkin RT3883 kernel / drivers / switch / calibration
+ WR1200E R62 2.4.25 Cudy userspace
+ minimal target-native compatibility adapters
  - mcore adapter (already TARGET_VERIFIED)
  - bdinfo compatibility
  - exact board/network/radio identity translation where required
```

No physical flash is authorized by this document.
A future build must pass static image/layout validation and `sysupgrade -T` before any flash request.
