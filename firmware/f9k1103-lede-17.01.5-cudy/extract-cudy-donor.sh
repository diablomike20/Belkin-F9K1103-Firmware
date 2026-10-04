#!/usr/bin/env bash
set -euo pipefail

DONOR_URL='https://www.cudy.com/cdn/shop/files/WR1200V2-R26-2.4.23-20251224-145945-flash.zip?v=10287497656812635253'
DONOR_ZIP_SHA='def1d4b8472b5fef4d0f13d337d6c2f11127d14ef6bd7100780dbac0115aa35c'
DONOR_BIN='WR1200V2-R26-2.4.23-20251224-145945-flash.bin'
DONOR_BIN_SHA='b9842ca6d6b54d4d2b8bb4d13457ee674ba2d13540443af1cf1ce82708ea02cd'
EXPECTED_SQUASHFS_OFFSET='2583295'

BASE="${GITHUB_WORKSPACE:-$PWD}"
WORK="$BASE/_cudy-donor-work"
OUT="$BASE/out-f9k1103-cudy-donor"
rm -rf "$WORK" "$OUT"
mkdir -p "$WORK" "$OUT"
cd "$WORK"

echo "[1/8] Download official Cudy WR1200V2 2.4.23 donor"
wget -q --show-progress -O donor.zip "$DONOR_URL"
echo "$DONOR_ZIP_SHA  donor.zip" | sha256sum -c -

echo "[2/8] Extract and verify inner firmware"
unzip -j donor.zip "$DONOR_BIN"
echo "$DONOR_BIN_SHA  $DONOR_BIN" | sha256sum -c -

echo "[3/8] Locate SquashFS"
OFFSET="$(python3 - "$DONOR_BIN" <<'PY'
from pathlib import Path
import sys
b=Path(sys.argv[1]).read_bytes()
print(b.find(b'hsqs'))
PY
)"
echo "squashfs_offset=$OFFSET"
test "$OFFSET" = "$EXPECTED_SQUASHFS_OFFSET"

python3 - "$DONOR_BIN" "$OFFSET" donor.squashfs <<'PY'
from pathlib import Path
import sys
src=Path(sys.argv[1]).read_bytes()
off=int(sys.argv[2])
Path(sys.argv[3]).write_bytes(src[off:])
PY

echo "[4/8] Extract SquashFS"
unsquashfs -no-progress -d donor-root donor.squashfs >/dev/null

echo "[5/8] Basic truth"
{
  echo "donor=WR1200V2-R26-2.4.23-20251224-145945"
  echo "zip_sha256=$DONOR_ZIP_SHA"
  echo "bin_sha256=$DONOR_BIN_SHA"
  echo "squashfs_offset=$OFFSET"
  echo "rootfs_files=$(find donor-root -type f | wc -l)"
  echo "luci_files=$(find donor-root/usr/lib/lua/luci -type f 2>/dev/null | wc -l)"
  echo "www_files=$(find donor-root/www -type f 2>/dev/null | wc -l)"
  echo
  unsquashfs -s donor.squashfs
} > "$OUT/DONOR-TRUTH.txt"

echo "[6/8] Build file/ABI inventories"
find donor-root -type f -print0 | sort -z | xargs -0 sha256sum > "$OUT/ROOTFS-SHA256SUMS.txt"
find donor-root/usr/lib/lua/luci donor-root/www donor-root/etc/config donor-root/etc/init.d   -type f -print 2>/dev/null | sed 's#^donor-root##' | sort > "$OUT/ROUTER-USERSPACE-PATHS.txt"

find donor-root -type f -print0 | while IFS= read -r -d '' f; do
  info="$(file -b "$f" || true)"
  case "$info" in
    *ELF*) printf '%s	%s
' "${f#donor-root}" "$info" ;;
  esac
done | sort > "$OUT/ELF-INVENTORY.tsv"

echo "[7/8] Classify port candidates"
python3 - "$WORK/donor-root" "$OUT/CUDY-PORT-MAP.csv" <<'PY'
from pathlib import Path
import csv, sys, subprocess
root=Path(sys.argv[1])
out=Path(sys.argv[2])

scan_roots=[
    root/'usr/lib/lua/luci',
    root/'www',
    root/'etc/config',
    root/'etc/init.d',
    root/'usr/lib',
]
cell_words=('cellular','modem','gcom','4g','5g','sms','simcard','wwan')
hw_words=('mt7628','ralink','factory','bdinfo','cmagent','cmsd','hcshd','softapd')
rows=[]
seen=set()
for base in scan_roots:
    if not base.exists():
        continue
    for p in base.rglob('*'):
        if not p.is_file() or p in seen:
            continue
        seen.add(p)
        rel='/' + str(p.relative_to(root))
        low=rel.lower()
        try:
            typ=subprocess.check_output(['file','-b',str(p)],text=True,errors='replace').strip()
        except Exception:
            typ='UNKNOWN'
        if 'ELF' in typ:
            cls='BLOCK_OPAQUE_ELF'
            reason='Cudy donor is mipsel_24kc; F9K1103 target is mipsel_74kc. Requires separate ABI/runtime proof.'
        elif any(w in low for w in cell_words):
            cls='EXCLUDE_CELLULAR'
            reason='F9K1103 is a non-cellular router.'
        elif rel.startswith('/www/') or rel.startswith('/usr/lib/lua/luci/'):
            cls='UI_LUA_CANDIDATE'
            reason='Primary portable Cudy UI/Lua candidate; dependency/adaptation review required.'
        elif rel.startswith('/etc/config/'):
            cls='SEMANTICS_REFERENCE'
            reason='Use as Cudy UCI semantics reference; do not overwrite F9K1103 hardware config blindly.'
        elif rel.startswith('/etc/init.d/'):
            cls='SCRIPT_REVIEW'
            reason='Shell/init candidate; review service dependencies and hardware assumptions.'
        elif any(w in low for w in hw_words):
            cls='HARDWARE_VENDOR_REVIEW'
            reason='Potential board/vendor dependency.'
        else:
            cls='REVIEW'
            reason='Manual portability classification required.'
        rows.append((rel,cls,typ,reason))

with out.open('w',newline='') as f:
    w=csv.writer(f)
    w.writerow(['path','classification','file_type','reason'])
    w.writerows(sorted(rows))
PY

grep -E 'UI_LUA_CANDIDATE|SCRIPT_REVIEW|SEMANTICS_REFERENCE|EXCLUDE_CELLULAR|BLOCK_OPAQUE_ELF'   "$OUT/CUDY-PORT-MAP.csv" > "$OUT/CUDY-PORT-MAP-FOCUSED.csv" || true

echo "[8/8] Dependency/string leads"
grep -RIlE 'cellular|gcom|modem|sms|wwan|bdinfo|cmagent|cmsd|hcshd|softapd'   donor-root/usr/lib/lua/luci donor-root/www donor-root/etc/init.d 2>/dev/null   | sed 's#^donor-root##' | sort > "$OUT/HARDWARE-DEPENDENCY-LEADS.txt" || true

{
  echo 'F9K1103 CUDY DONOR AUDIT'
  echo '========================'
  echo
  echo 'Primary donor: WR1200V2 R26 2.4.23'
  echo 'Purpose: router UI/userspace semantics only.'
  echo 'Target hardware/kernel/driver truth remains native F9K1103 LEDE 17.01.5.'
  echo
  echo 'Never blindly copy:'
  echo '- donor kernel/modules'
  echo '- MT7628 Wi-Fi stack'
  echo '- cellular/SMS/modem stack'
  echo '- opaque donor ELF binaries'
  echo
  echo 'Next gate: review CUDY-PORT-MAP.csv and construct a source-only/portable overlay.'
} > "$OUT/README.txt"

( cd "$OUT" && sha256sum * > SHA256SUMS.txt )
echo "DONOR_AUDIT=PASS"
