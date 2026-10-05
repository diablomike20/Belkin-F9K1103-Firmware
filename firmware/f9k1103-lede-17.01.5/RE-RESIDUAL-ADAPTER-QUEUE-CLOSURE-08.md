# RE — Residual adapter queue closure 08

## Authoritative result

The WR1200E R62 / 2.4.25 userspace remains Cudy-owned unless a physical
F9K1103 hardware boundary requires otherwise.

| Path | Final classification | Decision |
|---|---|---|
| `etc/hotplug.d/gmac/08-wan-detect` | CUDY_PINNED_USERSPACE | Preserve exact donor file; target supplies missing wan_detect kernel ABI. |
| `etc/hotplug.d/gmac/10-odhcp6c` | CUDY_NATIVE_INERT_UNLESS_GMAC_EVENT | Preserve exact donor file. It acts only on the Cudy gmac hotplug contract; absence of that event is not grounds to replace the file. |
| `etc/hotplug.d/wandetect/08-wan-detect` | CUDY_PINNED_USERSPACE | Preserve exact donor file; target supplies missing wan_detect kernel ABI. |
| `lib/ramips.sh` | HARDWARE_REPLACE | Physical board/MTD detection is F9K1103-owned. |
| `sbin/smp.sh` | CUDY_NATIVE_INERT_ON_SINGLE_CPU_TARGET | Preserve exact donor file. It exits before MT7621/ra*/rai* logic when fewer than two CPUs are present. |
| `sbin/wandetect` | CUDY_PINNED_USERSPACE | Preserve exact donor file. |
| `usr/bin/bdinfo` | CUDY_PINNED_ORIGINAL | Never substitute historical shim in CUDY-FIRST build. |
| `usr/lib/libbdinfo.so` | CUDY_PINNED_ORIGINAL | Preserve exact vendor library; backing data contract is target-side. |
| `usr/lib/lua/luci/apprpc/eth.lua` | CUDY_NATIVE_PASS | Exact donor and boot-proven target hashes are identical. |
| `usr/lib/lua/mcore.lua` | TARGET_VERIFIED_ADAPTER | Existing thin adapter physically validated on F9K1103. |

## Exact evidence

WR1200E donor SHA-256 values:

- `gmac/08-wan-detect`: `541b534368fdae1b801be48700004f9984f633ae0b6a02a045a8a0cead4f0c8f`
- `gmac/10-odhcp6c`: `7105b4ee0de291a0202d0f686355931a9a2d5c71e4cc697bd3ffe72c44ebc01c`
- `wandetect/08-wan-detect`: `dcb473751fb171d0b9cabd5bf481e84f9a7bdf65b87cf979f96688768816a912`
- `lib/ramips.sh`: `c85e430b98a7698d9625f0c7d0a3d5bb4c5115ef9ca9ffefdc1e9bed8c9ac327`
- `sbin/smp.sh`: `5c9d85e35aa73dbe15a9c486a9a168efcee5b26f8639d2676377b5e07129a785`
- `sbin/wandetect`: `1a0444766bab552b305d29dc9218aba61a8cc01a9c4a53ea6f913a89edc625d8`
- `usr/bin/bdinfo`: `40e9f9ccdd22fe39d340d799ee4ae3c2ebe8c09c6d8b1f55ef5b72e58fd22763`
- `usr/lib/libbdinfo.so`: `dc2ac9f10739eb1f690acf3fbd9e17d8f824673f7faa7173db3894faa4cfc15b`
- `usr/lib/lua/luci/apprpc/eth.lua`: `37ebf4b4d0bbcb4246af2a207214ab887fe88de24780ff6173e9a62e07870a5b`
- donor `usr/lib/lua/mcore.lua`: `014e1fd5a2297f03af01f9a6ee1f84088f6fd8e6fe79dd4893a14a52a66cbc8b`

The exact `eth.lua` target hash is also
`37ebf4b4d0bbcb4246af2a207214ab887fe88de24780ff6173e9a62e07870a5b`.

## smp.sh

The donor script derives the CPU count from the first line of
`/proc/interrupts` and executes:

```sh
[ "$NUM_OF_CPU" -lt 2 ] && exit 0
```

before `get_wifi_if_name`, MT7621 model setup, IRQ affinity or RPS changes.
Therefore donor MT7621 and `ra*/rai*` names are dead code on the single-core
F9K1103 target. Preserve the Cudy script unchanged.

## 10-odhcp6c

The donor script is an event consumer. It requires:
- `system.board.type=router`
- `network.lan.ipv6=1`
- a `gmac` hotplug invocation with `ACTION=linkup`
- matching `PORTNUM`.

It does not poll or alter hardware on its own. Preserve it unchanged.
If the F9K1103 target never emits the proprietary `gmac` event, the script
is inert; that is a kernel/event compatibility concern, not a reason to
replace Cudy userspace.

## Closure

Residual userspace review queue: **CLOSED**.

Remaining target work is restricted to proven hardware/runtime contracts:
- target board/MTD layer;
- Cudy bdinfo backing/provisioning availability;
- Cudy wan_detect procfs/event ABI;
- already validated mcore adapter.

`/bin/busybox`, `/usr/bin/bdinfo`, and `/usr/lib/libbdinfo.so` remain
CUDY_PINNED. BusyBox is NEVER_REPLACE.

FLASH_AUTHORIZATION=NO
