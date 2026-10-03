# Firmware Unlock 9 — Project handoff package

This directory is the successor handoff for the full Cudy LT500D / OpenCudy / Firmware Unlock project and the newly active Belkin F9K1103 v1 LEDE 17.01.5 port line.

## Read order

1. `FIRMWARE-UNLOCK-9-PROMPT.txt`
2. `fu_9-PROJECT-MASTER-DOCUMENTATION.md`
3. `fu_9-CURRENT-STATE-MATRIX.csv`
4. `fu_9-BELKIN-LEDE-17.01.5-STATUS.md`
5. `fu_9-R25-FU8-RE-STATUS.md`
6. `fu_9-DONOR-FIRMWARE-STUDY.md`
7. `fu_9-HISTORY-TIMELINE.md`
8. `fu_9-OPEN-ISSUES-ROADMAP.md`
9. `fu_9-EVIDENCE-AND-OPERATING-RULES.md`
10. `fu_9-FIRMWARE-INVENTORY.csv`

## Current primary mission

The primary task at handoff is:

**Belkin F9K1103 v1 native LEDE 17.01.5 baseline -> physical boot proof -> Cudy userspace/UI port.**

The project must not regress to an OpenWrt 19-only Cudy adaptation unless the LEDE line becomes technically impossible. OpenWrt 19.07 F9K1109 v1 remains a hardware/reference baseline because that image is what has actually been used on the F9K1103 hardware.

As of 2026-10-02, three LEDE 17.01.5 candidates build successfully and pass static image validation, but none has yet been proven to boot on the physical F9K1103 v1.

## Separate firmware archive

The final handoff delivery also contains a separate `Firmware-Unlock-9-ALL-FIRMWARE.zip` containing all firmware binaries/packages that were materially available to the project at handoff. The documentation ZIP should be treated as the source of truth for status; presence in the firmware archive does not mean a firmware is safe to flash or target-verified.

## Critical rule

Never upgrade an evidence status merely because a file exists.

- SOURCE_PRESENT / SOURCE_VERIFIED is not TARGET_VERIFIED.
- STATIC_VERIFIED is not PHYSICAL_BOOT_VERIFIED.
- Image-format acceptance is not successful boot.
- A donor firmware from another model is not R25 or F9K1103 truth without independent corroboration.
