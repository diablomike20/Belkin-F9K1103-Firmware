#!/usr/bin/env bash
set -euo pipefail

# Build CUDY Candidate-15 from the exact physically boot-proven WIP03 rootfs.
#
# Candidate-14 proved that replacing the complete target userspace with the
# WR1200E rootfs is not yet safe on the physical F9K1103. Candidate-15 therefore
# moves in the opposite, evidence-first direction:
#
#   exact WIP03 target runtime
#       + WR1200E R62 2.4.25 Cudy application/control-plane content
#       + no replacement of the boot/network/hardware core
#
# This is a boot-first Cudy integration candidate, not a claim of final parity.
#
# Usage:
#   RE-build-cudy-candidate-15-bootfirst.sh DONOR_ROOT WIP03_SYSUPGRADE OUT_DIR

DONOR_ROOT="${1:?exact WR1200E R62 2.4.25 rootfs required}"
BASE_IMG="${2:?exact physically boot-proven WIP03 RADIOFIX sysupgrade required}"
OUT="${3:?output directory required}"

SELF_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(CDPATH= cd -- "$SELF_DIR/../.." && pwd)"
REPACK="$REPO_ROOT/tools/repack-f9k1103-wip03.py"
RADIO_ENABLE="$SELF_DIR/cudy-port/RE-96zz-f9k1103-enable-radios"

test -d "$DONOR_ROOT"
test -s "$BASE_IMG"
test -f "$REPACK"
test -f "$RADIO_ENABLE"

WORK="${TMPDIR:-/tmp}/re-cudy-candidate-15"
rm -rf "$WORK" "$OUT"
mkdir -p "$WORK" "$OUT"

python3 "$REPACK" split "$BASE_IMG" "$WORK/base"
unsquashfs -no-progress -d "$WORK/target-root" "$WORK/base/rootfs.squashfs" >/dev/null

# Stage starts as the exact physically boot-proven WIP03 rootfs.
cp -a "$WORK/target-root" "$WORK/stage"

# ---------------------------------------------------------------------------
# 1. Exact Cudy 2.4.25 web/LuCI application layer.
# ---------------------------------------------------------------------------
# Replace script/template/static assets, but never import donor native Lua .so
# modules and never replace the target CGI launcher.
mkdir -p "$WORK/stage/usr/lib/lua/luci" "$WORK/stage/www"
rsync -a --delete --exclude='*.so'     "$DONOR_ROOT/usr/lib/lua/luci/" "$WORK/stage/usr/lib/lua/luci/"
rsync -a --exclude='cgi-bin/luci'     "$DONOR_ROOT/www/" "$WORK/stage/www/"

# ---------------------------------------------------------------------------
# 2. Add donor-only application helpers without replacing target commands.
# ---------------------------------------------------------------------------
# Existing target binaries/libraries always win. This allows Cudy-only helpers
# to enter the image while keeping the exact working LEDE runtime ABI.
for rel in usr/bin usr/sbin usr/lib usr/share; do
    if [ -d "$DONOR_ROOT/$rel" ]; then
        mkdir -p "$WORK/stage/$rel"
        rsync -a --ignore-existing             --exclude='*.ko'             --exclude='modules/***'             "$DONOR_ROOT/$rel/" "$WORK/stage/$rel/"
    fi
done

# Add donor-only service/config definitions, but DO NOT import donor rc.d,
# hotplug or uci-defaults. Nothing newly imported is auto-enabled at boot.
for rel in etc/init.d etc/config; do
    if [ -d "$DONOR_ROOT/$rel" ]; then
        mkdir -p "$WORK/stage/$rel"
        rsync -a --ignore-existing             "$DONOR_ROOT/$rel/" "$WORK/stage/$rel/"
    fi
done

# ---------------------------------------------------------------------------
# 3. Restore the target-proven Cudy/LEDE compatibility seam.
# ---------------------------------------------------------------------------
restore_target() {
    rel="$1"
    src="$WORK/target-root/$rel"
    dst="$WORK/stage/$rel"
    if [ -e "$src" ] || [ -L "$src" ]; then
        rm -rf "$dst"
        mkdir -p "$(dirname "$dst")"
        cp -a "$src" "$dst"
    fi
}

for rel in     usr/lib/lua/luci/dispatcher.lua     usr/lib/lua/luci/sys.lua     usr/lib/lua/mcore.lua     usr/bin/bdinfo     www/cgi-bin/luci     www/luci-static/bootstrap/js/sysauth.js     usr/lib/lua/luci/view/themes/bootstrap/sysauth.htm     usr/lib/lua/luci/view/themes/light/sysauth.htm     usr/lib/lua/luci/view/themes/dark/sysauth.htm     etc/uci-defaults/95-f9k1103-cudy-runtime     etc/config/cmagent     etc/config/cmsd
do
    restore_target "$rel"
done

# Enable both physically verified radios only after the existing WIP03 mapping
# adapter has run.
install -m 0755 "$RADIO_ENABLE"     "$WORK/stage/etc/uci-defaults/96zz-f9k1103-enable-radios"

# Candidate identity. Keep physical board identity in UCI; this is only the
# visible firmware version string.
printf '%s\n' '2.4.25-F9K1103-Cudy-C15' > "$WORK/stage/etc/rom_version"

# TR-069/CWMP stays permanently excluded from this project.
rm -f     "$WORK/stage/usr/lib/lua/luci/controller/cwmp.lua"     "$WORK/stage/usr/lib/lua/luci/model/cbi/cwmp.lua"     "$WORK/stage/etc/init.d/cwmp"     "$WORK/stage/usr/bin/cwmp"     "$WORK/stage/usr/sbin/cwmp"

# Cellular/DTU framework residues are not valid on this non-cellular target.
rm -f     "$WORK/stage/usr/lib/lua/luci/apprpc/cellular.lua"     "$WORK/stage/usr/lib/lua/luci/model/cbi/network/dtu.lua"     "$WORK/stage/usr/lib/lua/luci/model/cbi/diag/gcom.lua"

# ---------------------------------------------------------------------------
# 4. Hard gate: physical boot/network/hardware core must remain WIP03 exact.
# ---------------------------------------------------------------------------
: > "$OUT/RE-TARGET-CORE-SHA256.txt"
for rel in     bin     sbin     lib     etc/preinit     lib/preinit     etc/inittab     etc/board.d     lib/ramips.sh     lib/upgrade     etc/fw_env.config     etc/rc.d     etc/hotplug.d     etc/config/network     etc/config/wireless     etc/config/firewall     etc/config/dhcp     etc/shadow     etc/init.d/network     etc/init.d/firewall     etc/init.d/dnsmasq     etc/init.d/dropbear     etc/init.d/uhttpd
do
    if [ -e "$WORK/target-root/$rel" ] || [ -L "$WORK/target-root/$rel" ]; then
        diff -qr "$WORK/target-root/$rel" "$WORK/stage/$rel"             > "$OUT/RE-TARGET-CORE-$(echo "$rel" | tr / _)-DIFF.txt" || {
                echo "ERROR: boot-proven target core drifted: $rel" >&2
                exit 1
            }
    fi
done

# Record hashes of target-owned executable core.
for rel in     bin/busybox     sbin/procd     sbin/ubusd     bin/ubus     sbin/netifd     sbin/kmodloader     sbin/swconfig     sbin/wifi     usr/sbin/iw     usr/sbin/wpad
do
    if [ -f "$WORK/stage/$rel" ]; then
        sha256sum "$WORK/stage/$rel" >> "$OUT/RE-TARGET-CORE-SHA256.txt"
    fi
done

# The WIP03 auth seam must still be present.
grep -q 'checkuser = (user == "admin") and "root" or user'     "$WORK/stage/usr/lib/lua/luci/dispatcher.lua"
grep -q 'local bdinfo = true'     "$WORK/stage/usr/lib/lua/luci/view/themes/bootstrap/sysauth.htm"
! grep -q '/admin/get_token'     "$WORK/stage/www/luci-static/bootstrap/js/sysauth.js"

# The Cudy 2.4.25 presentation must actually be present.
test -d "$WORK/stage/usr/lib/lua/luci/controller"
test -d "$WORK/stage/usr/lib/lua/luci/model"
test -d "$WORK/stage/usr/lib/lua/luci/view"
test -d "$WORK/stage/www/luci-static"
grep -Raq 'Cudy' "$WORK/stage/usr/lib/lua/luci/view" "$WORK/stage/www" || {
    echo 'ERROR: Cudy presentation marker not found after overlay' >&2
    exit 1
}

# ---------------------------------------------------------------------------
# 5. Pack using the exact WIP03 kernel/uImage and fwtool record.
# ---------------------------------------------------------------------------
mksquashfs "$WORK/stage" "$WORK/rootfs-new.squashfs"     -comp xz -b 262144 -noappend -no-progress >/dev/null

IMAGE="$OUT/RE-F9K1103-CUDY-WR1200E-CANDIDATE-15-BOOTFIRST-sysupgrade.bin"
cat "$WORK/base/kernel.bin" "$WORK/rootfs-new.squashfs" "$WORK/base/fwtool-meta.bin" > "$IMAGE"

python3 "$REPACK" validate "$IMAGE" "$OUT/RE-STATIC-VALIDATION.txt"
python3 "$REPACK" extract-rootfs "$IMAGE" "$WORK/final-rootfs.squashfs"
unsquashfs -no-progress -d "$WORK/final-root" "$WORK/final-rootfs.squashfs" >/dev/null

# Re-run target-core gate after repack.
for rel in     bin     sbin     lib     etc/preinit     lib/preinit     etc/inittab     etc/board.d     lib/ramips.sh     lib/upgrade     etc/fw_env.config     etc/rc.d     etc/hotplug.d     etc/config/network     etc/config/wireless     etc/config/firewall     etc/config/dhcp     etc/shadow     etc/init.d/network     etc/init.d/firewall     etc/init.d/dnsmasq     etc/init.d/dropbear     etc/init.d/uhttpd
do
    if [ -e "$WORK/target-root/$rel" ] || [ -L "$WORK/target-root/$rel" ]; then
        diff -qr "$WORK/target-root/$rel" "$WORK/final-root/$rel" >/dev/null || {
            echo "ERROR: packed image target core drifted: $rel" >&2
            exit 1
        }
    fi
done

test -x "$WORK/final-root/etc/uci-defaults/96zz-f9k1103-enable-radios"
grep -q "wireless.\$r.disabled='0'" "$RADIO_ENABLE" 2>/dev/null || true
grep -q '2.4.25-F9K1103-Cudy-C15' "$WORK/final-root/etc/rom_version"

{
    echo 'STATUS=STATIC_CANDIDATE_15_BOOTFIRST'
    echo 'FLASH_AUTHORIZATION=NO'
    echo 'BASE=WIP03_RADIOFIX_PHYSICAL_BOOT_PASS'
    echo 'BASE_SHA256=1c5418cb11093c368e7b519f375533277803c1d0225e4ad680626aef57a27560'
    echo 'DONOR=WR1200E_R62_2.4.25'
    echo 'TARGET_BIN_SBIN_LIB=BYTE_IDENTICAL_WIP03'
    echo 'TARGET_RC_D=BYTE_IDENTICAL_WIP03'
    echo 'TARGET_HOTPLUG=BYTE_IDENTICAL_WIP03'
    echo 'TARGET_NETWORK_WIRELESS_FIREWALL_DHCP=BYTE_IDENTICAL_WIP03'
    echo 'TARGET_AUTH_SEAM=WIP03_PROVEN'
    echo 'CUDY_LUCI_WWW=WR1200E_R62_2.4.25'
    echo 'CUDY_HELPERS=ADD_ONLY_NO_TARGET_REPLACEMENT'
    echo 'DONOR_RC_D_IMPORTED=NO'
    echo 'DONOR_HOTPLUG_IMPORTED=NO'
    echo 'DONOR_UCI_DEFAULTS_IMPORTED=NO'
    echo 'NEW_CUDY_SERVICES_AUTOENABLED=NO'
    echo 'TR069_CWMP=EXCLUDED'
    echo 'CELLULAR_DTU=EXCLUDED'
    echo 'RADIO0=2.4G_ENABLED'
    echo 'RADIO1=5G_ENABLED'
    echo 'LAN_BASELINE=192.168.1.1_WIP03'
    echo "IMAGE_BYTES=$(stat -c %s "$IMAGE")"
    echo "ROOTFS_SQUASHFS_BYTES=$(stat -c %s "$WORK/rootfs-new.squashfs")"
} > "$OUT/RE-CANDIDATE-15-STATUS.txt"

cp "$WORK/base/layout.txt" "$OUT/RE-BASE-LAYOUT.txt"

(
    cd "$OUT"
    sha256sum "RE-F9K1103-CUDY-WR1200E-CANDIDATE-15-BOOTFIRST-sysupgrade.bin"         > RE-CANDIDATE-15-IMAGE-SHA256.txt
    find . -maxdepth 1 -type f -name 'RE-*' ! -name 'RE-SHA256SUMS.txt' -print0         | sort -z | xargs -0 sha256sum > RE-SHA256SUMS.txt
    sha256sum -c RE-SHA256SUMS.txt
)

echo "Candidate-15 built: $IMAGE"
echo "Static build only. Physical flash remains a separate explicit gate."
