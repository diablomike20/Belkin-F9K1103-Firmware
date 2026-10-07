#!/usr/bin/env bash
set -euo pipefail

# Build CUDY-FIRST Candidate-12. Static-valid, still DO_NOT_FLASH until target test gate.
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
test -f "$STAGE_SCRIPT"
test -f "$REPACK"

WORK="${TMPDIR:-/tmp}/re-cudy-first-candidate-12"
rm -rf "$WORK" "$OUT"
mkdir -p "$WORK" "$OUT"

python3 "$REPACK" split "$BASE_IMG" "$WORK/base"
sudo unsquashfs -no-progress -d "$WORK/target-root" "$WORK/base/rootfs.squashfs" >/dev/null
sudo chown -R "$(id -u):$(id -g)" "$WORK/target-root"

# The stage builder starts from complete Cudy rootfs and restores only the
# proven F9K1103 hardware boundary.
bash "$STAGE_SCRIPT" "$DONOR_ROOT" "$WORK/target-root" "$WORK/stage"

# Preserve engineering evidence outside the firmware payload. The Cudy rootfs
# itself must not be polluted with RE checkpoint files.
for meta in RE-TARGET-HARDWARE-PATHS.txt RE-CUDY-PINNED-SHA256.txt RE-TARGET-CREDENTIAL-SHA256.txt RE-STAGE-STATUS.txt RE-STAGE-SHA256.txt; do
    [ -f "$WORK/stage/$meta" ] && cp "$WORK/stage/$meta" "$OUT/$meta"
done
rm -f "$WORK/stage"/RE-*

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
for rel in \
    sbin/wandetect \
    etc/hotplug.d/gmac/08-wan-detect \
    etc/hotplug.d/gmac/10-odhcp6c \
    etc/hotplug.d/wandetect/08-wan-detect
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

IMAGE="$OUT/RE-F9K1103-CUDY-FIRST-WR1200E-CANDIDATE-12-sysupgrade.bin"
cat "$WORK/base/kernel.bin" "$WORK/rootfs-new.squashfs" "$WORK/base/fwtool-meta.bin" > "$IMAGE"

python3 "$REPACK" validate "$IMAGE" "$OUT/RE-STATIC-VALIDATION.txt"
python3 "$REPACK" extract-rootfs "$IMAGE" "$WORK/final-rootfs.squashfs"
sudo unsquashfs -no-progress -d "$WORK/final-root" "$WORK/final-rootfs.squashfs" >/dev/null
sudo chown -R "$(id -u):$(id -g)" "$WORK/final-root"

# Firstboot access-safety adapter must survive the pack and donor password
# logic itself must remain byte-identical.
test -x "$WORK/final-root/etc/uci-defaults/10zz-f9k1103-unprovisioned-access"
test -x "$WORK/final-root/etc/uci-defaults/29zz-f9k1103-cudy-wireless-contract"
test -x "$WORK/final-root/etc/uci-defaults/99zz-f9k1103-cudy-hardware"
test -f "$WORK/final-root/etc/uci-defaults/11_fix_passwd"
cmp "$DONOR_ROOT/etc/uci-defaults/11_fix_passwd" "$WORK/final-root/etc/uci-defaults/11_fix_passwd"

# Candidate-10 regression gate:
# the logical Cudy wireless sections must exist before unchanged stock 30_wlan.
[ "29zz-f9k1103-cudy-wireless-contract" \< "30_wlan" ] || {
    echo "ERROR: wireless precondition ordering invalid" >&2
    exit 1
}
[ "99_oem" \< "99zz-f9k1103-cudy-hardware" ] || {
    echo "ERROR: hardware postcondition ordering invalid" >&2
    exit 1
}
for token in wlan00 wlan01 wlan02 wlan10 wlan11 wlan12; do
    grep -q "$token" "$WORK/final-root/etc/uci-defaults/29zz-f9k1103-cudy-wireless-contract" || {
        echo "ERROR: Cudy logical wireless token missing: $token" >&2
        exit 1
    }
done
grep -q "system.board.ports='5'" "$WORK/final-root/etc/uci-defaults/99zz-f9k1103-cudy-hardware"
grep -q 'uci -q delete system.board.portnum' "$WORK/final-root/etc/uci-defaults/99zz-f9k1103-cudy-hardware"
! grep -q "uci set system.board.portnum=" "$WORK/final-root/etc/uci-defaults/99zz-f9k1103-cudy-hardware"

# Candidate-11 physical boot failure isolation:
# keep the boot-proven F9K1103 switch-control binary at the hardware boundary.
test -x "$WORK/target-root/sbin/swconfig"
test -x "$WORK/final-root/sbin/swconfig"
cmp "$WORK/target-root/sbin/swconfig" "$WORK/final-root/sbin/swconfig"
sha256sum "$WORK/final-root/sbin/swconfig" > "$OUT/RE-TARGET-SWCONFIG-SHA256.txt"

# Lexical uci-defaults ordering is part of the safety contract:
# 10zz target precondition MUST execute before unchanged donor 11_fix_passwd.
[ "10zz-f9k1103-unprovisioned-access" \< "11_fix_passwd" ] || {
    echo "ERROR: firstboot password guard ordering invalid" >&2
    exit 1
}
grep -q 'bdinfo checkuuid' "$WORK/final-root/etc/uci-defaults/10zz-f9k1103-unprovisioned-access"
grep -q "ttylogin='1'" "$WORK/final-root/etc/uci-defaults/10zz-f9k1103-unprovisioned-access"

# Recovery credential data must remain the exact boot-proven target value.
test -f "$WORK/target-root/etc/shadow"
test -f "$WORK/final-root/etc/shadow"
cmp "$WORK/target-root/etc/shadow" "$WORK/final-root/etc/shadow"
sha256sum "$WORK/final-root/etc/shadow" > "$OUT/RE-TARGET-SHADOW-SHA256.txt"

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
    echo 'STATUS=STATIC_CANDIDATE_12'
    echo 'FLASH_AUTHORIZATION=NO'
    echo 'POLICY=CUDY_FIRST'
    echo 'DONOR=WR1200E_R62_2.4.25'
    echo 'CUDY_BUSYBOX=PINNED_NEVER_REPLACE'
    echo 'CUDY_BDINFO=PINNED_ORIGINAL'
    echo 'CUDY_LIBBDINFO=PINNED_ORIGINAL'
    echo 'CUDY_WAN_USERSPACE=PINNED_ORIGINAL'
    echo 'WIRELESS_LOGICAL_CONTRACT=CUDY_WR1200E_PRE_30_WLAN'
    echo 'CUDY_WIRELESS_SECTIONS=wlan00,wlan01,wlan02,wlan10,wlan11,wlan12'
    echo 'TARGET_PORT_METADATA=ports5_portnum_unset_wanport4'
    echo 'TARGET_SWITCHCTL=BOOT_PROVEN_F9K1103_SWCONFIG'
    echo 'BOOTFIX_BASIS=CANDIDATE11_TARGET_BOOT_FAIL'
    echo 'TARGET_WAN_KERNEL_ABI=re_wandetect_compat'
    echo 'WAN_AUTO_PROTOCOL_DETECT=NOT_YET_PARITY_VERIFIED'
    echo 'BDINFO_BACKING=UNPROVISIONED_NO_FAKE_CHECKUUID'
    echo 'CUDY_11_FIX_PASSWD=BYTE_IDENTICAL'
    echo 'ACCESS_SAFETY=TARGET_SHADOW_PRESERVED'
    echo 'FIRSTBOOT_PASSWORD_GUARD=TARGET_TTYLOGIN_PRECONDITION'
    echo "TARGET_KERNEL_RELEASE=$KREL"
    echo "IMAGE_BYTES=$(stat -c %s "$IMAGE")"
    echo "ROOTFS_SQUASHFS_BYTES=$(stat -c %s "$WORK/rootfs-new.squashfs")"
} > "$OUT/RE-CANDIDATE-STATUS.txt"

cp "$WORK/base/layout.txt" "$OUT/RE-BASE-LAYOUT.txt"
(
    cd "$OUT"
    find . -maxdepth 1 -type f -name 'RE-*' ! -name 'RE-SHA256SUMS.txt' -print0 \
        | sort -z \
        | xargs -0 sha256sum \
        > RE-SHA256SUMS.txt
)
(
    cd "$OUT"
    sha256sum -c RE-SHA256SUMS.txt
)

echo "CUDY-FIRST Candidate-12 built: $IMAGE"
echo "DO NOT FLASH: physical authorization gate has not been reached."
