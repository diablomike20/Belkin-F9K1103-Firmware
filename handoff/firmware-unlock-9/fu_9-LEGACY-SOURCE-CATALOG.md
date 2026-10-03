# FU9 — legacy/source file catalog

This is a navigation catalog for prior Project/Library material. It is not a substitute for the self-contained FU9 documentation. File IDs are recorded because they may help retrieval inside the same Project context.

## High-value master/handoff sources

- `fu_6-PROJECT-MASTER-DOCUMENTATION(1).md`
  - prior file id: `file_00000000b8d4821080615f53f7d683ff`
  - broad earlier project master documentation

- `fu_6-FIRMWARE-UNLOCK-6-DEEP-HANDOFF(1).md`
  - `file_0000000000748210956dbeeab72642ea`
  - deep FU6 lineage/handoff

- `RE-R25-CSP25-HANDOFF-100.md`
  - `file_0000000049ac81f49ed506f8521d17a8`
  - R25 CSP2.5 hunt, R100 donor, request/provenance rules

- `RE-LT500D3-BETA-HUNT-CHECKPOINT-76.md`
  - `file_000000001c98820a93b9e5324c03df69`
  - older beta/support firmware hunt evidence

- `RE-LT500V2-R25-FRESHZIP-AUDIT-04.md`
  - `file_000000003a40820ab4b1db82cc0918b3`
  - exact stock R25 rootfs/source audit

- `RE-SUCCESSOR-CHAT-PROMPT-V3-CONTINUATION(1).md`
  - `file_0000000085d481fd9f8ca1d6e554499a`
  - previous successor state with H09/H11/Developer details

- `RE-LT500V2-R25-PATCH-MANIFEST-PREBUILD-06.md`
  - `file_000000006494820abe0d39abf252fc6c`
  - ENG06 patch lineage

- `RE-LT500V2-R25-ENG06-README.md`
  - `file_00000000a5ec820ab8467686b8fd6229`
  - ENG06 exact status and static integrity

- `RE-OPENCUDY-LT500D-R25-FULL-DOCUMENTATION-24.md`
  - `file_000000000238821182ce3acee8b287ed`
  - cumulative R25/OpenCudy documentation around Cumulative-24

- `RE-SUCCESSOR-CHAT-PROMPT-24.md`
  - `file_00000000691c823096dd27e41eaed80c`
  - previous handoff including Factory Debug RE and Cumulative-24

## Runtime/target evidence sources

- `RE-LT500V2-R25-PERFORMANCE-PROBE-01-20260925-010758.txt`
  - `file_0000000099a0820a8fa299dfca44ce9b`

- `Beillesztett szöveg(5).txt`
  - `file_00000000accc820a88f9a5da08d289fb`
  - physical target facts; flash_uuid/fuuid and hcshd listener observations among other runtime data

- older R25-family runtime log `Beillesztett szöveg(2).txt`
  - `file_000000001550820ab6f682ddb4cd939e`
  - LT500/R25 2.1.1 runtime maintenance sequence evidence

## OpenWrt23 Integration/WS/RE/EM chat exports

The Project contains many chat-export TXT files. They are historical evidence, not automatically current truth:

- `Boss.txt`
- `Boss_2.txt`
- `RE-Kollega.txt`
- `EM-Kollega.txt`
- `FE_2-Kollega.txt`
- `Frontend fejlesztési frissítés.txt`
- `Folytatás várakozás nélkül.txt`

Use the latest explicit integration baseline and source artifact rather than selecting a random older export.

## Firmware Unlock chat exports

Multiple project conversation exports exist:
- `Firmware-Unlock.txt`
- `Firmware-Unlock_2.txt`
- `Firmware-Unlock_3.txt`

These contain important target logs, build histories, OPKG and Developer lifecycle results, but they also contain superseded intermediate states. Use the FU9 current-state matrix to decide which statements are current.

## Donor research export

- `Cudy donor firmwareek felkutatása.txt`

Contains early donor discovery, Snapshot 03 development, Cellular/Resolver findings and cross-model work.

## Belkin project exports

- `Belkin N750 OpenWrt.txt`
- project handoff `markdown(2).md beillesztve`
  - prior file id `file_0000000094008210a446c3afed671815`

The GitHub repository is now more authoritative for current Belkin source/build state.

## FU8 local checkpoint artifacts

Known filenames:
- fu_8-STATIC-P0-CHECKPOINT-09.zip
- fu_8-STATIC-P0-CHECKPOINT-10.zip
- fu_8-STATIC-P0-CHECKPOINT-11.zip
- fu_8-STATIC-P0-CHECKPOINT-12.zip
- fu_8-STATIC-P0-CHECKPOINT-13.zip
- fu_8-STATIC-P0-CHECKPOINT-14.zip

Detailed CP10–14 conclusions are reproduced in FU9 docs, so lack of a local old checkpoint must not force a restart from zero.

## Project-source rule

If a legacy source and the FU9 docs conflict:
1. check date/version;
2. inspect the exact current source/artifact;
3. preserve stronger physical evidence;
4. mark conflict rather than silently merging incompatible states.

FU9 docs are the successor state map; exact source remains authoritative for source-level claims.
