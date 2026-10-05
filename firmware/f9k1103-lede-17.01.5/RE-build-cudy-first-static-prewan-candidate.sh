#!/usr/bin/env bash
set -euo pipefail

# CUDY-FIRST PRE-WAN static image.
# Purpose: close all full-rootfs/image/static gates independently from the
# separately compiled target wan_detect procfs compatibility module.
# NEVER FLASH this artifact.

DONOR_ROOT="${1:?exact WR1200E donor rootfs required}"
BASE_IMG="${2:?boot-proven F9K1103 sysupgrade required}"
OUT="${3:?output directory required}"

SELF_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(CDPATH= cd -- "$SELF_DIR/../.." && pwd)"
REPACK="$REPO_ROOT/tools/repack-f9k1103-wip03.py"
STAGE_SCRIPT="$SELF_DIR/RE-prepare-wr1200e-cudy-first-stage.sh"

test -d "$DONOR_ROOT"
test -s "$BASE_IMG"
test -f "$REPACK"
test -f "$STAGE_SCRIPT"

WORK="${TMPDIR:-/tmp}/re-cudy-first-prewan-12"
rm -rf "$WORK" "$OUT"
mkdir -p "$WORK" "$OUT"

python3 "$REPACK" split "$BASE_IMG" "$WORK/base"
sudo unsquashfs -no-progress -d "$WORK/target-root" "$WORK/base/rootfs.squashfs" >/dev/null
sudo chown -R "$(id -u):$(id -g)" "$WORK/target-root"

bash "$STAGE_SCRIPT" "$DONOR_ROOT" "$WORK/target-root" "$WORK/stage"

# Evidence stays outside production rootfs.
for meta in   RE-TARGET-HARDWARE-PATHS.txt   RE-CUDY-PINNED-SHA256.txt   RE-TARGET-CREDENTIAL-SHA256.txt   RE-STAGE-STATUS.txt   RE-STAGE-SHA256.txt
do
  [ -f "$WORK/stage/$meta" ] && cp "$WORK/stage/$meta" "$OUT/$meta"
done
rm -f "$WORK/stage"/RE-*

# The donor proprietary wan_detect.ko must never cross the hardware boundary.
if find "$WORK/stage/lib/modules" -type f -name 'wan_detect.ko' | grep -q .; then
  echo "ERROR: donor wan_detect.ko entered target hardware layer" >&2
  exit 1
fi

# PRE-WAN artifact deliberately contains no replacement wan_detect module.
if find "$WORK/stage/lib/modules" -type f -name 're_wandetect_compat.ko' | grep -q .; then
  echo "ERROR: stale target wan_detect compatibility module found" >&2
  exit 1
fi

# Absolute Cudy userspace invariants.
: > "$OUT/RE-CUDY-PINNED-SHA256.txt"
for rel in bin/busybox usr/bin/bdinfo usr/lib/libbdinfo.so; do
  dsha="$(sha256sum "$DONOR_ROOT/$rel" | awk '{print $1}')"
  ssha="$(sha256sum "$WORK/stage/$rel" | awk '{print $1}')"
  [ "$dsha" = "$ssha" ] || { echo "ERROR: Cudy pin drift before pack: $rel" >&2; exit 1; }
  printf '%s  %s\n' "$ssha" "$rel" >> "$OUT/RE-CUDY-PINNED-SHA256.txt"
done

# WAN/IPv6 userspace is Cudy-owned even though the kernel autodetect module is
# deliberately absent in this PRE-WAN static artifact.
for rel in   sbin/wandetect   etc/hotplug.d/gmac/08-wan-detect   etc/hotplug.d/gmac/10-odhcp6c   etc/hotplug.d/wandetect/08-wan-detect
do
  [ -f "$DONOR_ROOT/$rel" ] || continue
  cmp "$DONOR_ROOT/$rel" "$WORK/stage/$rel" || {
    echo "ERROR: Cudy WAN userspace drifted: $rel" >&2
    exit 1
  }
done

# High-level Cudy defaults remain donor-original.
for rel in   etc/uci-defaults/01_network   etc/uci-defaults/30_wlan   etc/uci-defaults/40_luci-wireless   etc/uci-defaults/11_fix_passwd
do
  [ -f "$DONOR_ROOT/$rel" ] || continue
  cmp "$DONOR_ROOT/$rel" "$WORK/stage/$rel" || {
    echo "ERROR: Cudy high-level default drifted: $rel" >&2
    exit 1
  }
done

mksquashfs "$WORK/stage" "$WORK/rootfs-new.squashfs"   -comp xz -b 262144 -noappend -no-progress >/dev/null

IMAGE="$OUT/RE-F9K1103-CUDY-FIRST-WR1200E-PREWAN-STATIC-12-sysupgrade.bin"
cat "$WORK/base/kernel.bin" "$WORK/rootfs-new.squashfs" "$WORK/base/fwtool-meta.bin" > "$IMAGE"

python3 "$REPACK" validate "$IMAGE" "$OUT/RE-STATIC-VALIDATION.txt"
python3 "$REPACK" extract-rootfs "$IMAGE" "$WORK/final-rootfs.squashfs"
sudo unsquashfs -no-progress -d "$WORK/final-root" "$WORK/final-rootfs.squashfs" >/dev/null
sudo chown -R "$(id -u):$(id -g)" "$WORK/final-root"

# Post-pack Cudy immutable gates.
for rel in bin/busybox usr/bin/bdinfo usr/lib/libbdinfo.so; do
  cmp "$DONOR_ROOT/$rel" "$WORK/final-root/$rel" || {
    echo "ERROR: Cudy pin drift after pack: $rel" >&2
    exit 1
  }
done

# Preserve boot-proven target physical layer byte-for-byte where expected.
for rel in lib/wifi etc/config/network etc/config/wireless; do
  if [ -e "$WORK/target-root/$rel" ]; then
    diff -qr "$WORK/target-root/$rel" "$WORK/final-root/$rel"       > "$OUT/RE-TARGET-$(echo "$rel" | tr / _)-DIFF.txt" || {
        echo "ERROR: target physical layer drifted: $rel" >&2
        exit 1
      }
  fi
done

# Firstboot recovery safety.
test -x "$WORK/final-root/etc/uci-defaults/10zz-f9k1103-unprovisioned-access"
cmp "$DONOR_ROOT/etc/uci-defaults/11_fix_passwd" "$WORK/final-root/etc/uci-defaults/11_fix_passwd"
cmp "$WORK/target-root/etc/shadow" "$WORK/final-root/etc/shadow"

# Cudy identity / target physical metadata adapter must be present.
test -x "$WORK/final-root/etc/uci-defaults/99zz-f9k1103-cudy-hardware"
grep -q "system.board.rom='R62'" "$WORK/final-root/etc/uci-defaults/99zz-f9k1103-cudy-hardware"
grep -q "system.board.model='WR1200E'" "$WORK/final-root/etc/uci-defaults/99zz-f9k1103-cudy-hardware"
grep -q "system.board.ports='5'" "$WORK/final-root/etc/uci-defaults/99zz-f9k1103-cudy-hardware"
! grep -q 'system.board.portnum' "$WORK/final-root/etc/uci-defaults/99zz-f9k1103-cudy-hardware"

{
  echo 'STATUS=PREWAN_STATIC_CANDIDATE'
  echo 'FLASH_AUTHORIZATION=NO'
  echo 'DO_NOT_FLASH=YES'
  echo 'POLICY=CUDY_FIRST'
  echo 'DONOR=WR1200E_R62_2.4.25'
  echo 'CUDY_BUSYBOX=CUDY_PINNED_NEVER_REPLACE'
  echo 'CUDY_BDINFO=CUDY_PINNED_ORIGINAL'
  echo 'CUDY_LIBBDINFO=CUDY_PINNED_ORIGINAL'
  echo 'CUDY_WAN_USERSPACE=CUDY_PINNED_ORIGINAL'
  echo 'CUDY_11_FIX_PASSWD=BYTE_IDENTICAL'
  echo 'BDINFO_CHECKUUID=NOT_FAKED'
  echo 'PORTNUM=UNSET_AS_STOCK_R62'
  echo 'WAN_KERNEL_COMPAT=DELIBERATELY_PENDING'
  echo 'WAN_AUTO_PROTOCOL_DETECT=NOT_AVAILABLE_IN_THIS_PREWAN_ARTIFACT'
  echo 'TARGET_SHADOW=PRESERVED'
  echo "IMAGE_BYTES=$(stat -c %s "$IMAGE")"
  echo "ROOTFS_SQUASHFS_BYTES=$(stat -c %s "$WORK/rootfs-new.squashfs")"
  echo "IMAGE_SHA256=$(sha256sum "$IMAGE" | awk '{print $1}')"
} > "$OUT/RE-CANDIDATE-STATUS.txt"

cp "$WORK/base/layout.txt" "$OUT/RE-BASE-LAYOUT.txt"
(
  cd "$OUT"
  find . -maxdepth 1 -type f -name 'RE-*' -print0 | sort -z | xargs -0 sha256sum > RE-SHA256SUMS.txt
)

echo "PRE-WAN STATIC candidate built: $IMAGE"
echo "DO NOT FLASH."
