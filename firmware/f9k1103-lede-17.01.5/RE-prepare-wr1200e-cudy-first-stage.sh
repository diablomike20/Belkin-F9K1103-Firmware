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
ADAPTER_SRC="$SELF_DIR/cudy-port/RE-99zz-f9k1103-cudy-hardware"
WIRELESS_PRE_SRC="$SELF_DIR/cudy-port/RE-29zz-f9k1103-cudy-wireless-contract"
PREACCESS_SRC="$SELF_DIR/cudy-port/RE-10zz-f9k1103-unprovisioned-access"
MCORE_SRC="$SELF_DIR/cudy-port/mcore.lua"

test -d "$DONOR_ROOT"
test -d "$TARGET_ROOT"
test -f "$ADAPTER_SRC"
test -f "$WIRELESS_PRE_SRC"
test -f "$PREACCESS_SRC"
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
for rel in   lib/modules   lib/firmware   lib/wifi   etc/modules.d   etc/modules-boot.d
do
  copy_target_path "$rel"
done

# Physical board detection, flash upgrade/recovery and preinit are target-owned.
for rel in   etc/board.d   lib/ramips.sh   lib/preinit   lib/upgrade   etc/fw_env.config   etc/inittab
do
  copy_target_path "$rel"
done

# Physical kernel/module and switch control must remain a coherent target
# stack. Candidate-11/12 kept target modules but donor kmodloader, and kept the
# target RTL8367R topology but donor network init (which calls Cudy/MTK
# /sbin/vlancfg). Restore the exact boot-proven target control points.
for rel in \
  sbin/kmodloader \
  sbin/swconfig \
  etc/init.d/network
do
  copy_target_path "$rel"
done

# WR1200E's proprietary MTK Wi-Fi userspace has no mac80211 netifd handler,
# no wpad/hostapd and no iw binary. F9K1103 is mac80211/rt2x00, so these are
# physical radio userspace boundaries and must come from the boot-proven target.
for rel in \
  lib/netifd/hostapd.sh \
  lib/netifd/wireless \
  usr/sbin/iw \
  usr/sbin/wpad \
  usr/sbin/hostapd \
  usr/sbin/wpa_supplicant
do
  copy_target_path "$rel"
done

# The initial physical interface topology must come from the boot-verified
# F9K1103 baseline. Cudy uci-defaults are preserved in OUT_ROOT and will
# apply Cudy semantics on top of these target physical objects.
for rel in \
  etc/config/network \
  etc/config/wireless \
  etc/shadow
do
  copy_target_path "$rel"
done

# Keep the physically validated mcore contract adapter.
mkdir -p "$OUT_ROOT/usr/lib/lua"
cp -a "$MCORE_SRC" "$OUT_ROOT/usr/lib/lua/mcore.lua"

# Install target-only firstboot access guard immediately before donor
# 11_fix_passwd. The donor script itself remains byte-identical.
mkdir -p "$OUT_ROOT/etc/uci-defaults"
cp -a "$PREACCESS_SRC" "$OUT_ROOT/etc/uci-defaults/10zz-f9k1103-unprovisioned-access"
chmod 0755 "$OUT_ROOT/etc/uci-defaults/10zz-f9k1103-unprovisioned-access"

# Recreate the exact Cudy logical wireless section contract before stock
# 30_wlan runs.  Physical driver/radio ownership remains target mac80211.
cp -a "$WIRELESS_PRE_SRC" "$OUT_ROOT/etc/uci-defaults/29zz-f9k1103-cudy-wireless-contract"
chmod 0755 "$OUT_ROOT/etc/uci-defaults/29zz-f9k1103-cudy-wireless-contract"

# Install the thin physical adapter after all stock Cudy defaults. Runtime name
# intentionally sorts after donor 99_fixwan / 99_oem.
cp -a "$ADAPTER_SRC" "$OUT_ROOT/etc/uci-defaults/99zz-f9k1103-cudy-hardware"
chmod 0755 "$OUT_ROOT/etc/uci-defaults/99zz-f9k1103-cudy-hardware"

# CUDY-PINNED userspace.
# /bin/busybox is NEVER_REPLACE by project policy and any hash mismatch is fatal.
# /usr/bin/bdinfo and /usr/lib/libbdinfo.so are CUDY_PINNED_ORIGINAL.
# Only the read-only data-access backing below their Cudy API may be adapted.
#
# bdinfo/libbdinfo are Cudy provisioning/device-identity components.
# BusyBox is kept from the complete donor userspace as well; do not silently
# substitute the target LEDE BusyBox merely because both are LEDE-based.
for rel in \
  bin/busybox \
  usr/bin/bdinfo \
  usr/lib/libbdinfo.so
do
  test -e "$DONOR_ROOT/$rel" || { echo "ERROR: donor-pinned object missing: $rel" >&2; exit 1; }
  test -e "$OUT_ROOT/$rel" || { echo "ERROR: donor-pinned object missing from stage: $rel" >&2; exit 1; }
  donor_sha="$(sha256sum "$DONOR_ROOT/$rel" | awk '{print $1}')"
  stage_sha="$(sha256sum "$OUT_ROOT/$rel" | awk '{print $1}')"
  [ "$donor_sha" = "$stage_sha" ] || {
    echo "ERROR: Cudy-pinned object changed: $rel" >&2
    echo "DONOR=$donor_sha STAGE=$stage_sha" >&2
    exit 1
  }
  printf '%s  %s\n' "$donor_sha" "$rel" >> "$OUT_ROOT/RE-CUDY-PINNED-SHA256.txt"
done

# Recovery credential data is target-owned. This is deliberately data-only:
# donor BusyBox, passwd utility and donor 11_fix_passwd remain Cudy-original.
test -f "$TARGET_ROOT/etc/shadow" || { echo "ERROR: target shadow missing" >&2; exit 1; }
test -f "$OUT_ROOT/etc/shadow" || { echo "ERROR: staged shadow missing" >&2; exit 1; }
TARGET_SHADOW_SHA256="$(sha256sum "$TARGET_ROOT/etc/shadow" | awk '{print $1}')"
STAGE_SHADOW_SHA256="$(sha256sum "$OUT_ROOT/etc/shadow" | awk '{print $1}')"
[ "$TARGET_SHADOW_SHA256" = "$STAGE_SHADOW_SHA256" ] || {
  echo "ERROR: target recovery shadow changed in stage" >&2
  exit 1
}
printf '%s  %s\n' "$STAGE_SHADOW_SHA256" "etc/shadow" >> "$OUT_ROOT/RE-TARGET-CREDENTIAL-SHA256.txt"

# The donor 11_fix_passwd itself is immutable Cudy code.
test -f "$DONOR_ROOT/etc/uci-defaults/11_fix_passwd"
test -f "$OUT_ROOT/etc/uci-defaults/11_fix_passwd"
DONOR_FIXPASS_SHA="$(sha256sum "$DONOR_ROOT/etc/uci-defaults/11_fix_passwd" | awk '{print $1}')"
STAGE_FIXPASS_SHA="$(sha256sum "$OUT_ROOT/etc/uci-defaults/11_fix_passwd" | awk '{print $1}')"
[ "$DONOR_FIXPASS_SHA" = "$STAGE_FIXPASS_SHA" ] || {
  echo "ERROR: Cudy 11_fix_passwd changed" >&2
  exit 1
}

# The exact donor bdinfo remains untouched here. Its hardware data access is
# audited separately. Do not silently replace it with the historical reduced
# shim.

# This stage is intentionally non-flashable until ELF ABI and adapter gates
# have closed.
cat > "$OUT_ROOT/RE-STAGE-STATUS.txt" <<'EOF'
STATUS=NON_FLASHABLE
POLICY=CUDY_FIRST
DONOR=WR1200E_R62_2.4.25
TARGET_HARDWARE=F9K1103
MCORE=TARGET_VERIFIED_ADAPTER
BDINFO=CUDY_PINNED_ORIGINAL_UNPROVISIONED
BDINFO_CHECKUUID=NOT_FAKED
ACCESS_SAFETY=TARGET_SHADOW_PRESERVED
FIRSTBOOT_PASSWORD_GUARD=TARGET_TTYLOGIN_PRECONDITION
WIRELESS_LOGICAL_CONTRACT=CUDY_WR1200E_PRE_30_WLAN
BUSYBOX_POLICY=CUDY_PINNED_NEVER_REPLACE
EOF

find "$OUT_ROOT" -xdev -type f -print0 | sort -z | xargs -0 sha256sum   > "$OUT_ROOT/RE-STAGE-SHA256.txt"

echo "RE Cudy-first stage prepared: $OUT_ROOT"
