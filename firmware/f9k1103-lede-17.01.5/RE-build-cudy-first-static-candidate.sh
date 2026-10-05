#!/usr/bin/env bash
set -euo pipefail

# Build a STATIC / DO_NOT_FLASH CUDY-FIRST image candidate.
#
# Usage:
#   RE-build-cudy-first-static-candidate.sh \
#       DONOR_ROOT \
#       BASE_F9K1103_SYSUPGRADE \
#       RE_WANDETECT_KO \
#       OUT_DIR
#
# Required host tools: python3, unsquashfs, mksquashfs, rsync, sha256sum.
#
# This script preserves the boot-proven F9K1103 kernel/uImage bytes and fwtool
# record from BASE_F9K1103_SYSUPGRADE. The rootfs starts from the complete
# WR1200E donor and is adapted only at the physical target boundary.
#
# Output is deliberately NOT authorized for physical flashing.

DONOR_ROOT="${1:?exact WR1200E donor rootfs required}"
BASE_IMG="${2:?boot-proven F9K1103 sysupgrade required}"
WAN_KO="${3:?compiled re_wandetect_compat.ko required}"
OUT="${4:?output directory required}"

SELF_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(CDPATH= cd -- "$SELF_DIR/../.." && pwd)"
REPACK="$REPO_ROOT/tools/repack-f9k1103-wip03.py"
STAGE_SCRIPT="$SELF_DIR/RE-prepare-wr1200e-cudy-first-stage.sh"

test -d "$DONOR_ROOT"
test -s "$BASE_IMG"
test -s "$WAN_KO"
test -x "$STAGE_SCRIPT"
test -f "$REPACK"

WORK="${TMPDIR:-/tmp}/re-cudy-first-candidate-01"
rm -rf "$WORK" "$OUT"
mkdir -p "$WORK" "$OUT"

python3 "$REPACK" split "$BASE_IMG" "$WORK/base"
unsquashfs -no-progress -d "$WORK/target-root" "$WORK/base/rootfs.squashfs" >/dev/null

# The stage builder starts from complete Cudy rootfs and restores only the
# proven F9K1103 hardware boundary.
"$STAGE_SCRIPT" "$DONOR_ROOT" "$WORK/target-root" "$WORK/stage"

KREL="$(basename "$(find "$WORK/stage/lib/modules" -mindepth 1 -maxdepth 1 -type d -print -quit)")"
[ -n "$KREL" ] || { echo "ERROR: target kernel module release not found" >&2; exit 1; }

# Target-only kernel ABI adapter. Cudy /sbin/wandetect and its hotplug scripts
# remain untouched.
install -m 0644 "$WAN_KO" "$WORK/stage/lib/modules/$KREL/re_wandetect_compat.ko"
mkdir -p "$WORK/stage/etc/modules.d"
printf '%s\n' 're_wandetect_compat' > "$WORK/stage/etc/modules.d/50-re-wandetect-compat"

# The proprietary donor wan_detect.ko is MT7628/MT7663 platform truth and must
# never enter the F9K1103 kernel layer.
if find "$WORK/stage/lib/modules" -type f -name 'wan_detect.ko' | grep -q .; then
    echo "ERROR: donor wan_detect.ko entered target stage" >&2
    exit 1
fi

# Hard Cudy pin gate before packing.
for rel in bin/busybox usr/bin/bdinfo usr/lib/libbdinfo.so; do
    dsha="$(sha256sum "$DONOR_ROOT/$rel" | awk '{print $1}')"
    ssha="$(sha256sum "$WORK/stage/$rel" | awk '{print $1}')"
    [ "$dsha" = "$ssha" ] || {
        echo "ERROR: CUDY_PIN mismatch before pack: $rel" >&2
        exit 1
    }
done

# Cudy WAN userspace must remain donor-original.
for rel in     sbin/wandetect     etc/hotplug.d/gmac/08-wan-detect     etc/hotplug.d/wandetect/08-wan-detect
do
    [ -f "$DONOR_ROOT/$rel" ] || continue
    dsha="$(sha256sum "$DONOR_ROOT/$rel" | awk '{print $1}')"
    ssha="$(sha256sum "$WORK/stage/$rel" | awk '{print $1}')"
    [ "$dsha" = "$ssha" ] || {
        echo "ERROR: Cudy WAN userspace changed: $rel" >&2
        exit 1
    }
done

mksquashfs "$WORK/stage" "$WORK/rootfs-new.squashfs"     -comp xz -b 262144 -noappend -no-progress >/dev/null

IMAGE="$OUT/RE-F9K1103-CUDY-FIRST-WR1200E-STATIC-CANDIDATE-01-sysupgrade.bin"
cat "$WORK/base/kernel.bin" "$WORK/rootfs-new.squashfs" "$WORK/base/fwtool-meta.bin" > "$IMAGE"

python3 "$REPACK" validate "$IMAGE" "$OUT/RE-STATIC-VALIDATION.txt"
python3 "$REPACK" extract-rootfs "$IMAGE" "$WORK/final-rootfs.squashfs"
unsquashfs -no-progress -d "$WORK/final-root" "$WORK/final-rootfs.squashfs" >/dev/null

# Post-pack immutable Cudy gate.
: > "$OUT/RE-CUDY-PINNED-SHA256.txt"
for rel in bin/busybox usr/bin/bdinfo usr/lib/libbdinfo.so; do
    dsha="$(sha256sum "$DONOR_ROOT/$rel" | awk '{print $1}')"
    fsha="$(sha256sum "$WORK/final-root/$rel" | awk '{print $1}')"
    [ "$dsha" = "$fsha" ] || {
        echo "ERROR: CUDY_PIN mismatch after repack: $rel" >&2
        exit 1
    }
    printf '%s  %s\n' "$fsha" "$rel" >> "$OUT/RE-CUDY-PINNED-SHA256.txt"
done

test -s "$WORK/final-root/lib/modules/$KREL/re_wandetect_compat.ko"
grep -qx 're_wandetect_compat' "$WORK/final-root/etc/modules.d/50-re-wandetect-compat"

# Confirm target-owned physical Wi-Fi layer survived.
for rel in lib/wifi etc/config/network etc/config/wireless; do
    if [ -e "$WORK/target-root/$rel" ]; then
        diff -qr "$WORK/target-root/$rel" "$WORK/final-root/$rel"           > "$OUT/RE-TARGET-$(echo "$rel" | tr / _)-DIFF.txt" || {
            echo "ERROR: target-owned physical layer drifted: $rel" >&2
            exit 1
          }
    fi
done

# Confirm selected high-level Cudy wireless/network defaults survived.
for rel in   etc/uci-defaults/01_network   etc/uci-defaults/30_wlan   etc/uci-defaults/40_luci-wireless
do
    [ -f "$DONOR_ROOT/$rel" ] || continue
    cmp "$DONOR_ROOT/$rel" "$WORK/final-root/$rel" || {
        echo "ERROR: Cudy high-level default changed: $rel" >&2
        exit 1
    }
done

{
    echo 'STATUS=STATIC_CANDIDATE'
    echo 'FLASH_AUTHORIZATION=NO'
    echo 'POLICY=CUDY_FIRST'
    echo 'DONOR=WR1200E_R62_2.4.25'
    echo 'CUDY_BUSYBOX=PINNED_NEVER_REPLACE'
    echo 'CUDY_BDINFO=PINNED_ORIGINAL'
    echo 'CUDY_LIBBDINFO=PINNED_ORIGINAL'
    echo 'CUDY_WAN_USERSPACE=PINNED_ORIGINAL'
    echo 'TARGET_WAN_KERNEL_ABI=re_wandetect_compat'
    echo 'WAN_AUTO_PROTOCOL_DETECT=NOT_YET_PARITY_VERIFIED'
    echo 'BDINFO_BACKING=NOT_YET_PROVISIONED'
    echo "TARGET_KERNEL_RELEASE=$KREL"
    echo "IMAGE_BYTES=$(stat -c %s "$IMAGE")"
    echo "ROOTFS_SQUASHFS_BYTES=$(stat -c %s "$WORK/rootfs-new.squashfs")"
} > "$OUT/RE-CANDIDATE-STATUS.txt"

cp "$WORK/base/layout.txt" "$OUT/RE-BASE-LAYOUT.txt"
cp "$WORK/stage/RE-TARGET-HARDWARE-PATHS.txt" "$OUT/RE-TARGET-HARDWARE-PATHS.txt"
cp "$WORK/stage/RE-CUDY-PINNED-SHA256.txt" "$OUT/RE-STAGE-CUDY-PINNED-SHA256.txt"

(
    cd "$OUT"
    find . -maxdepth 1 -type f -name 'RE-*' -print0 | sort -z | xargs -0 sha256sum > RE-SHA256SUMS.txt
)

echo "STATIC CUDY-FIRST candidate built: $IMAGE"
echo "DO NOT FLASH: physical authorization gate has not been reached."
