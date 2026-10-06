# RE — Candidate-10 rejected

The artifact produced by workflow run 37387319154 is **BROKEN_CANDIDATE / DO_NOT_FLASH**.

Reasons:

1. The F9K1103 hardware adapter set `system.board.ports=5` but did not set
   `system.board.portnum=5`. The unchanged Cudy `/sbin/wandetect` and
   `/etc/hotplug.d/gmac/08-wan-detect` consume `system.board.portnum`.
   This can select incorrect WAN/switch logic.

2. `re_wandetect_compat.ko` from Candidate-10 supplies only the procfs storage
   ABI. It does **not** implement the proprietary Cudy automatic protocol
   detection/hotplug producer. Candidate-10 itself records
   `WAN_AUTO_PROTOCOL_DETECT=NOT_YET_PARITY_VERIFIED`.

3. Static image validation only proved the Belkin image envelope, CRCs,
   SquashFS structure and size. It did not prove boot/runtime correctness.

4. Therefore workflow SUCCESS is not runtime acceptance.

Candidate-10 must not be used as an authoritative target build.

Preserved invariants for the replacement:
- Cudy BusyBox: NEVER_REPLACE.
- Cudy bdinfo + libbdinfo.so: donor-original.
- Cudy /sbin/wandetect and hotplug userspace: donor-original.
- Belkin ownership remains limited to physical kernel/driver/switch/flash/calibration boundaries.

Replacement target: RE CUDY-FIRST Candidate-11.
