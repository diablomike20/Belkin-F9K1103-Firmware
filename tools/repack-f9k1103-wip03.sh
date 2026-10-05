#!/usr/bin/env bash
set -euo pipefail

BASE_ARTIFACT_ID=11313772739
REPO="${GITHUB_REPOSITORY:-diablomike20/Belkin-F9K1103-Firmware}"
GH_TOKEN="${GH_TOKEN:?GH_TOKEN missing}"

BASE=/tmp/wip03-base
WORK=/tmp/wip03-repack
OUT="${GITHUB_WORKSPACE:-$PWD}/out-wip03-radiofix"

rm -rf "$BASE" "$WORK" "$OUT"
mkdir -p "$BASE" "$WORK" "$OUT"

curl -fL \
  -H "Authorization: Bearer $GH_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$REPO/actions/artifacts/$BASE_ARTIFACT_ID/zip" \
  -o /tmp/wip03-base.zip

unzip -q /tmp/wip03-base.zip -d "$BASE"
IMG="$BASE/lede-ramips-rt3883-f9k1103-squashfs-sysupgrade.bin"
test -s "$IMG"

python3 tools/repack-f9k1103-wip03.py split "$IMG" "$WORK"
unsquashfs -no-progress -d "$WORK/rootfs" "$WORK/rootfs.squashfs" >/dev/null

TARGET="$WORK/rootfs/etc/uci-defaults/95-f9k1103-cudy-runtime"
test -f "$TARGET"
cp firmware/f9k1103-lede-17.01.5/cudy-port/95-f9k1103-cudy-runtime "$TARGET"
chmod 0755 "$TARGET"

grep -q 'radio0) target="wlan00"' "$TARGET"
grep -q 'radio1) target="wlan10"' "$TARGET"
grep -q "wireless.wlan00.device='radio0'" "$TARGET"
grep -q "wireless.wlan10.device='radio1'" "$TARGET"

mksquashfs "$WORK/rootfs" "$WORK/rootfs-new.squashfs" \
  -comp xz -b 262144 -noappend -no-progress >/dev/null

FINAL="$OUT/RE-F9K1103-LEDE-17.01.5-CUDY-WIP03-RADIOFIX-sysupgrade.bin"
cat "$WORK/kernel.bin" "$WORK/rootfs-new.squashfs" "$WORK/fwtool-meta.bin" > "$FINAL"

python3 tools/repack-f9k1103-wip03.py validate "$FINAL" "$OUT/RE-STATIC-VALIDATION.txt"
python3 tools/repack-f9k1103-wip03.py extract-rootfs "$FINAL" "$WORK/final-rootfs.sqfs"
unsquashfs -no-progress -d "$WORK/final-rootfs" "$WORK/final-rootfs.sqfs" >/dev/null

F="$WORK/final-rootfs/etc/uci-defaults/95-f9k1103-cudy-runtime"
grep -q 'radio0) target="wlan00"' "$F"
grep -q 'radio1) target="wlan10"' "$F"
grep -q "wireless.wlan00.device='radio0'" "$F"
grep -q "wireless.wlan10.device='radio1'" "$F"

cp "$F" "$OUT/RE-95-f9k1103-cudy-runtime-IN-IMAGE"
cp "$WORK/layout.txt" "$OUT/RE-BASE-LAYOUT.txt"

{
  echo "Base successful WIP03 artifact:"
  echo "  artifact_id=$BASE_ARTIFACT_ID"
  echo "  source_commit=8aca39b3a52e037ad530ee14f03cf6ef82ecdc7e"
  echo
  echo "Radio-fix source:"
  echo "  branch=f9k1103-cudy-port-wip03"
  echo "  source_commit=${GITHUB_SHA:-unknown}"
  echo
  echo "Physical TARGET-TEST-01 truth:"
  echo "  radio0 = PCI RT3091/3092 = 2.4 GHz = Cudy wlan00"
  echo "  radio1 = RT3883 WMAC      = 5 GHz   = Cudy wlan10"
  echo
  echo "Kernel/uImage and fwtool metadata are inherited unchanged."
  echo "Rootfs was rebuilt with the corrected runtime adapter."
  echo "Physical flash was not performed."
} > "$OUT/RE-REPACK-INFO.txt"

(
  cd "$OUT"
  sha256sum * > RE-SHA256SUMS.txt
)

cat "$OUT/RE-STATIC-VALIDATION.txt"
cat "$OUT/RE-REPACK-INFO.txt"
cat "$OUT/RE-SHA256SUMS.txt"
