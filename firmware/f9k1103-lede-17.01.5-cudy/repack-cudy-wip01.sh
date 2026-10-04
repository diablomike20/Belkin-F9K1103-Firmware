#!/usr/bin/env bash
set -euo pipefail

BASE_NATIVE="${GITHUB_WORKSPACE}/base-native"
OUT="${GITHUB_WORKSPACE}/out-f9k1103-cudy-wip01"
WORK="${GITHUB_WORKSPACE}/_f9k1103_cudy_repack"
PORT_DIR="${GITHUB_WORKSPACE}/firmware/f9k1103-lede-17.01.5-cudy"

BASE_SHA='d244aec4ca9aef7f46d9b49c8497d99ecd671298245ee41c61af9377a0c5d6b3'
DONOR_URL='https://www.cudy.com/cdn/shop/files/WR1200V2-R26-2.4.23-20251224-145945-flash.zip?v=10287497656812635253'
DONOR_ZIP_SHA='def1d4b8472b5fef4d0f13d337d6c2f11127d14ef6bd7100780dbac0115aa35c'
DONOR_BIN='WR1200V2-R26-2.4.23-20251224-145945-flash.bin'
DONOR_BIN_SHA='b9842ca6d6b54d4d2b8bb4d13457ee674ba2d13540443af1cf1ce82708ea02cd'
DONOR_SQ_OFF='2583295'
IMAGE_LIMIT=$((7224 * 1024))

rm -rf "$WORK" "$OUT"
mkdir -p "$WORK" "$OUT"

BASE_IMAGE="$(find "$BASE_NATIVE" -type f -name '*f9k1103*squashfs*sysupgrade.bin' | head -1)"
BASE_INITRAMFS="$(find "$BASE_NATIVE" -type f -name '*f9k1103*initramfs*kernel.bin' | head -1 || true)"
[ -n "$BASE_IMAGE" ] && [ -f "$BASE_IMAGE" ] || { echo 'native base sysupgrade not found' >&2; exit 1; }

echo "[1/10] Verify BUILD_VERIFIED F9K1103 native base"
echo "$BASE_SHA  $BASE_IMAGE" | sha256sum -c -

cd "$WORK"

echo "[2/10] Extract native rootfs and metadata"
python3 - "$BASE_IMAGE" <<'PY'
from pathlib import Path
import struct, sys, json
src=Path(sys.argv[1]).read_bytes()
off=src.find(b'hsqs')
if off < 0:
    raise SystemExit('native squashfs not found')
if len(src) < 16:
    raise SystemExit('native image too short')
magic, old_crc = struct.unpack_from('>II', src, len(src)-16)
typ = src[-8]
size = struct.unpack_from('>I', src, len(src)-4)[0]
if magic != 0x46577830 or typ != 1 or size < 24 or size > len(src):
    raise SystemExit('native fwtool metadata trailer invalid')
meta_start=len(src)-size
hdr=src[meta_start:meta_start+8]
meta=src[meta_start+8:len(src)-16]
if hdr != b'\0'*8:
    raise SystemExit('unexpected fwtool metadata header')
obj=json.loads(meta.decode())
if 'f9k1103' not in obj.get('supported_devices',[]):
    raise SystemExit('native metadata does not support f9k1103')
bytes_used=struct.unpack_from('<Q',src,off+40)[0]
root=src[off:off+bytes_used]
Path('native-prefix.bin').write_bytes(src[:off])
Path('native-rootfs.squashfs').write_bytes(root)
Path('native-metadata.json').write_bytes(meta)
Path('native-layout.txt').write_text(
    f'kernel_prefix_size={off}\n'
    f'rootfs_bytes_used={bytes_used}\n'
    f'metadata_size={size}\n'
    f'supported_devices={obj.get("supported_devices")}\n'
)
PY
sudo unsquashfs -no-progress -d native-root native-rootfs.squashfs >/dev/null
sudo chown -R "$(id -u):$(id -g)" native-root

echo "[3/10] Acquire exact FU8-selected Cudy WR1200V2 2.4.23 donor"
wget -qO donor.zip "$DONOR_URL"
echo "$DONOR_ZIP_SHA  donor.zip" | sha256sum -c -
unzip -j donor.zip "$DONOR_BIN" >/dev/null
echo "$DONOR_BIN_SHA  $DONOR_BIN" | sha256sum -c -
OFF="$(python3 - "$DONOR_BIN" <<'PY'
from pathlib import Path
import sys
print(Path(sys.argv[1]).read_bytes().find(b'hsqs'))
PY
)"
[ "$OFF" = "$DONOR_SQ_OFF" ] || { echo "unexpected donor squashfs offset: $OFF" >&2; exit 1; }
python3 - "$DONOR_BIN" "$OFF" <<'PY'
from pathlib import Path
import sys
b=Path(sys.argv[1]).read_bytes()
Path('donor.squashfs').write_bytes(b[int(sys.argv[2]):])
PY
sudo unsquashfs -no-progress -d donor-root donor.squashfs >/dev/null
sudo chown -R "$(id -u):$(id -g)" donor-root

echo "[4/10] Overlay only boot-safe Cudy presentation assets"
DST="native-root/www/luci-static/bootstrap"
mkdir -p "$DST/css" "$DST/fonts" "$DST/img" "$DST/svg"
for f in font-awesome.min.css iconfont.css; do
    cp -a "donor-root/www/luci-static/bootstrap/css/$f" "$DST/css/"
done
cp -a donor-root/www/luci-static/bootstrap/fonts/. "$DST/fonts/"
cp -a donor-root/www/luci-static/bootstrap/img/favicon.ico "$DST/img/"
cp -a donor-root/www/luci-static/bootstrap/img/logo.png "$DST/img/"
cp -a donor-root/www/luci-static/bootstrap/img/loginlogo.png "$DST/img/"
if [ -d donor-root/www/luci-static/resources ]; then
    cp -a donor-root/www/luci-static/resources/. "$DST/svg/"
fi
cp "$PORT_DIR/cudy-f9k1103-legacy.css" "$DST/cudy-f9k1103.css"

echo "[5/10] Adapt legacy LEDE LuCI theme without Cudy bdinfo/auth dependency"
python3 - "$WORK/native-root" <<'PY'
from pathlib import Path
import re, sys
root=Path(sys.argv[1])

header=root/'usr/lib/lua/luci/view/themes/bootstrap/header.htm'
hs=header.read_text()
links=(
    '\n\t\t<link rel="stylesheet" href="<%=media%>/css/font-awesome.min.css">\n'
    '\t\t<link rel="stylesheet" href="<%=media%>/css/iconfont.css">\n'
    '\t\t<link rel="stylesheet" href="<%=media%>/cudy-f9k1103.css">\n'
)
if 'cudy-f9k1103.css' not in hs:
    if '</head>' not in hs:
        raise SystemExit('header </head> not found')
    hs=hs.replace('</head>',links+'\t</head>',1)

if 'cudy-f9k1103' not in hs:
    hs,n=re.subn(r'<body\s+class="', '<body class="cudy-f9k1103 ', hs, count=1)
    if n==0:
        hs,n=re.subn(r'<body\b', '<body class="cudy-f9k1103"', hs, count=1)
    if n==0:
        raise SystemExit('header <body> not found')

brand=(
    '<a class="brand cudy-brand" href="<%=luci.dispatcher.build_url("admin/status/overview")%>">'
    '<img src="<%=media%>/img/logo.png" alt="Cudy">'
    '<span>Cudy <span class="cudy-model">F9K1103</span></span></a>'
)
hs,n=re.subn(r'<a\s+class="brand"[^>]*>.*?</a>',brand,hs,count=1,flags=re.S)
if n==0 and 'cudy-brand' not in hs:
    raise SystemExit('LuCI brand anchor not found')
header.write_text(hs)

sysauth=root/'usr/lib/lua/luci/view/sysauth.htm'
ss=sysauth.read_text()
if 'cudy-login-head' not in ss:
    marker='<%+header%>'
    if marker not in ss:
        raise SystemExit('sysauth header include not found')
    ss=ss.replace(marker,marker+'\n<div class="cudy-login-head"><img src="<%=media%>/img/loginlogo.png" alt="Cudy"><h2>F9K1103 Cudy Firmware</h2></div>',1)
sysauth.write_text(ss)

footer=root/'usr/lib/lua/luci/view/themes/bootstrap/footer.htm'
fs=footer.read_text()
if 'community port' not in fs:
    fs,n=re.subn(
        r'(<footer[^>]*>)',
        r'\1\n    <div class="cudy-port-mark">F9K1103 Cudy Firmware (community port)</div>',
        fs,count=1,flags=re.S)
    if n==0:
        raise SystemExit('footer tag not found')
footer.write_text(fs)

(root/'etc/rom_version').write_text('F9K1103-CUDY-WIP-01-LEDE-17.01.5\n')
(root/'etc/cudy_f9k1103_build').write_text(
    'project=F9K1103 LEDE 17.01.5 Cudy Firmware\n'
    'stage=CUDY-WIP-01\n'
    'cudy_donor=WR1200V2-R26-2.4.23-20251224-145945\n'
    'cellular=excluded\n'
    'kernel_base=native-f9k1103-lede-17.01.5\n'
)

rel=root/'etc/openwrt_release'
if rel.exists():
    lines=[]
    replaced=False
    for line in rel.read_text().splitlines():
        if line.startswith('DISTRIB_DESCRIPTION='):
            lines.append("DISTRIB_DESCRIPTION='F9K1103 Cudy Firmware WIP-01 / LEDE 17.01.5'")
            replaced=True
        else:
            lines.append(line)
    if not replaced:
        lines.append("DISTRIB_DESCRIPTION='F9K1103 Cudy Firmware WIP-01 / LEDE 17.01.5'")
    rel.write_text('\n'.join(lines)+'\n')
PY

echo "[6/10] Repack SquashFS using native geometry"
sudo mksquashfs native-root new-rootfs.squashfs     -comp xz -b 262144 -noappend -all-root -no-xattrs -nopad >/dev/null
sudo chown "$(id -u):$(id -g)" new-rootfs.squashfs

echo "[7/10] Rebuild sysupgrade envelope and fwtool metadata CRC"
python3 - "$BASE_IMAGE" new-rootfs.squashfs native-metadata.json "$OUT/RE-F9K1103-LEDE-17.01.5-CUDY-WIP-01-sysupgrade.bin" "$IMAGE_LIMIT" <<'PY'
from pathlib import Path
import struct, sys, binascii, hashlib, json
base=Path(sys.argv[1]).read_bytes()
root=Path(sys.argv[2]).read_bytes()
meta=Path(sys.argv[3]).read_bytes()
out=Path(sys.argv[4])
limit=int(sys.argv[5])

off=base.find(b'hsqs')
if off < 0:
    raise SystemExit('base squashfs marker missing')
prefix=base[:off]

# Preserve native uImage byte-for-byte.
if prefix[:4] != bytes.fromhex('27051956'):
    raise SystemExit('native uImage magic missing')

pre=bytearray(prefix)
pre.extend(root)
pad=(-len(pre)) % 65536
pre.extend(b'\xff' * pad)
pre.extend(bytes.fromhex('deadc0de'))

hdr=b'\0'*8

# fwtool's crc32_block() keeps the internal CRC state (no final xor).
table=[]
poly=0xedb88320
for i in range(256):
    c=i
    for _ in range(8):
        c=(c>>1)^poly if c&1 else c>>1
    table.append(c & 0xffffffff)

def crc_block(v,data):
    for x in data:
        v=table[(v & 0xff)^x]^(v>>8)
    return v & 0xffffffff

crc=0xffffffff
crc=crc_block(crc,pre)
crc=crc_block(crc,hdr)
crc=crc_block(crc,meta)
size=8+len(meta)+16
tr=struct.pack('>II',0x46577830,crc)+bytes([1,0,0,0])+struct.pack('>I',size)
image=bytes(pre)+hdr+meta+tr
if len(image)>limit:
    raise SystemExit(f'image too large: {len(image)} > {limit}')
out.write_bytes(image)

# Validate unchanged native kernel uImage.
magic,hcrc,ts,psz,load,entry,dcrc=struct.unpack('>7I',image[:28])
hz=bytearray(image[:64]); hz[4:8]=b'\0'*4
calc_h=binascii.crc32(hz)&0xffffffff
payload=image[64:64+psz]
calc_d=binascii.crc32(payload)&0xffffffff
if magic!=0x27051956 or hcrc!=calc_h or dcrc!=calc_d:
    raise SystemExit('uImage CRC validation failed')

# Validate new rootfs and fwtool trailer.
roff=image.find(b'hsqs')
rused=struct.unpack_from('<Q',image,roff+40)[0]
tmagic,tcrc=struct.unpack_from('>II',image,len(image)-16)
ttype=image[-8]
tsize=struct.unpack_from('>I',image,len(image)-4)[0]
mstart=len(image)-tsize
state=0xffffffff
state=crc_block(state,image[:len(image)-16])
if tmagic!=0x46577830 or ttype!=1 or tcrc!=state:
    raise SystemExit('fwtool metadata CRC validation failed')
obj=json.loads(image[mstart+8:len(image)-16].decode())
if 'f9k1103' not in obj.get('supported_devices',[]):
    raise SystemExit('rebuilt image lost f9k1103 supported_devices')

Path(sys.argv[4]+'.validation').write_text(
    f'image_size={len(image)}\n'
    f'image_limit={limit}\n'
    f'kernel_prefix_size={off}\n'
    f'kernel_sha256={hashlib.sha256(prefix).hexdigest()}\n'
    f'new_rootfs_bytes_used={rused}\n'
    f'rootfs_offset={roff}\n'
    f'uimage_header_crc_ok={hcrc==calc_h}\n'
    f'uimage_payload_crc_ok={dcrc==calc_d}\n'
    f'fwtool_crc_ok={tcrc==state}\n'
    f'supported_devices={obj.get("supported_devices")}\n'
    f'VALIDATION=PASS\n'
)
PY

mv "$OUT/RE-F9K1103-LEDE-17.01.5-CUDY-WIP-01-sysupgrade.bin.validation" "$OUT/CUDY-WIP-01-STATIC-VALIDATION.txt"

echo "[8/10] Validate built rootfs contents"
ROM_VERSION="$(unsquashfs -cat new-rootfs.squashfs etc/rom_version)"
echo "$ROM_VERSION" | grep -Fq 'F9K1103-CUDY-WIP-01-LEDE-17.01.5'
unsquashfs -ls new-rootfs.squashfs | grep -Fq 'www/luci-static/bootstrap/img/logo.png'
unsquashfs -ls new-rootfs.squashfs | grep -Fq 'www/luci-static/bootstrap/cudy-f9k1103.css'
unsquashfs -ls new-rootfs.squashfs | grep -Fq 'etc/cudy_f9k1103_build'

echo "[9/10] Preserve native recovery/initramfs reference"
if [ -n "$BASE_INITRAMFS" ] && [ -f "$BASE_INITRAMFS" ]; then
    cp "$BASE_INITRAMFS" "$OUT/RE-F9K1103-LEDE-17.01.5-NATIVE-initramfs-kernel.bin"
fi
cp "$PORT_DIR/PORT-POLICY.md" "$OUT/RE-F9K1103-CUDY-PORT-POLICY.md"
cat > "$OUT/RE-F9K1103-CUDY-WIP-01-README.txt" <<'EOF'
F9K1103 LEDE 17.01.5 Cudy Firmware — WIP-01

This is the first boot-safe flashable Cudy-port checkpoint.

Kept native:
- F9K1103 LEDE 17.01.5 kernel/uImage
- RT3883 / RT3092 drivers
- RTL8367R-VB switch support
- flash/DTS/sysupgrade metadata
- native LuCI authentication/dispatcher/backend

Added from FU8-selected Cudy WR1200V2 2.4.23 donor:
- Cudy branding images
- Cudy icon/font visual assets
- Cudy visual presentation layer

Explicitly NOT added yet:
- Cudy bdinfo/auth dispatcher
- opaque Cudy ELF binaries
- MT7628 drivers
- cellular/SMS/modem stack
- TR-069
- full Cudy controller/CBI page set

This checkpoint is a boot-safe UI-shell milestone, not yet the final feature-complete Cudy userspace port.
EOF

echo "[10/10] Hash artifact"
(
  cd "$OUT"
  sha256sum RE-* CUDY-WIP-01-STATIC-VALIDATION.txt > SHA256SUMS.txt
)
echo "F9K1103_CUDY_WIP01=PASS"
