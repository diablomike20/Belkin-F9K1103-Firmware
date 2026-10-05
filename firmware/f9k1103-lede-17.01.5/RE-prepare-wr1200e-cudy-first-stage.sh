#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   RE-prepare-wr1200e-cudy-first-stage.sh DONOR_ROOT TARGET_ROOT OUT_ROOT
#
# DONOR_ROOT = exact unpacked WR1200E R62 / 2.4.25 rootfs
# TARGET_ROOT = exact unpacked known-booting F9K1103 LEDE rootfs
# OUT_ROOT    = non-flashable Cudy-first staging rootfs
#
# The donor rootfs is copied first. Only proven physical target boundaries are
# then restored from TARGET_ROOT. This script does NOT build or flash firmware.

DONOR_ROOT="${1:?donor rootfs required}"
TARGET_ROOT="${2:?target rootfs required}"
OUT_ROOT="${3:?output rootfs required}"

SELF_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ADAPTER_SRC="$SELF_DIR/cudy-port/RE-99-f9k1103-cudy-hardware"
MCORE_SRC="$SELF_DIR/cudy-port/mcore.lua"

test -d "$DONOR_ROOT"
test -d "$TARGET_ROOT"
test -f "$ADAPTER_SRC"
test -f "$MCORE_SRC"

rm -rf "$OUT_ROOT"
mkdir -p "$OUT_ROOT"

# Start from the complete Cudy userspace.
rsync -aH --numeric-ids   --exclude='/dev/***'   --exclude='/proc/***'   --exclude='/sys/***'   --exclude='/tmp/***'   --exclude='/overlay/***'   --exclude='/rom/***'   "$DONOR_ROOT/" "$OUT_ROOT/"

copy_target_path() {
  local rel="$1"
  local src="$TARGET_ROOT/$rel"
  local dst="$OUT_ROOT/$rel"

  rm -rf "$dst"
  if [ -e "$src" ] || [ -L "$src" ]; then
    mkdir -p "$(dirname "$dst")"
    cp -a "$src" "$dst"
    printf '%s\n' "$rel" >> "$OUT_ROOT/RE-TARGET-HARDWARE-PATHS.txt"
  fi
}

: > "$OUT_ROOT/RE-TARGET-HARDWARE-PATHS.txt"

# Kernel / modules / firmware blobs are always target-owned.
for rel in   lib/modules   lib/firmware   etc/modules.d   etc/modules-boot.d
do
  copy_target_path "$rel"
done

# Physical board detection, flash upgrade/recovery and preinit are target-owned.
for rel in   etc/board.d   lib/ramips.sh   lib/preinit   lib/upgrade   etc/fw_env.config   etc/inittab
do
  copy_target_path "$rel"
done

# The initial physical interface topology must come from the boot-verified
# F9K1103 baseline. Cudy uci-defaults are preserved in OUT_ROOT and will
# apply Cudy semantics on top of these target physical objects.
for rel in   etc/config/network   etc/config/wireless
do
  copy_target_path "$rel"
done

# Keep the physically validated mcore contract adapter.
mkdir -p "$OUT_ROOT/usr/lib/lua"
cp -a "$MCORE_SRC" "$OUT_ROOT/usr/lib/lua/mcore.lua"

# Install the thin physical adapter after all stock Cudy defaults.
mkdir -p "$OUT_ROOT/etc/uci-defaults"
cp -a "$ADAPTER_SRC" "$OUT_ROOT/etc/uci-defaults/99-f9k1103-cudy-hardware"
chmod 0755 "$OUT_ROOT/etc/uci-defaults/99-f9k1103-cudy-hardware"

# IMPORTANT: donor bdinfo is deliberately left untouched here. Its ABI and
# hardware data access are audited separately. Do not silently replace it
# with the historical reduced shim.

# This stage is intentionally non-flashable until ELF ABI and adapter gates
# have closed.
cat > "$OUT_ROOT/RE-STAGE-STATUS.txt" <<'EOF'
STATUS=NON_FLASHABLE
POLICY=CUDY_FIRST
DONOR=WR1200E_R62_2.4.25
TARGET_HARDWARE=F9K1103
MCORE=TARGET_VERIFIED_ADAPTER
BDINFO=DONOR_ORIGINAL_PENDING_COMPATIBILITY
EOF

find "$OUT_ROOT" -xdev -type f -print0 | sort -z | xargs -0 sha256sum   > "$OUT_ROOT/RE-STAGE-SHA256.txt"

echo "RE Cudy-first stage prepared: $OUT_ROOT"
