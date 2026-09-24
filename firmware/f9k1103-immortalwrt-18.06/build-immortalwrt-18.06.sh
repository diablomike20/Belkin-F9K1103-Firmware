#!/usr/bin/env bash
set -euo pipefail

# GitHub container runs as root; GNU tar's configure blocks this by default.
export FORCE_UNSAFE_CONFIGURE=1

IWRT_COMMIT=cab1e2e283d048f8f0fa3f31133510c86b30fd83
WORKDIR="${PWD}/_f9k1103_immortalwrt1806_build"
OUT="${GITHUB_WORKSPACE}/out-f9k1103-immortalwrt-18.06"

rm -rf "$WORKDIR" "$OUT"
mkdir -p "$WORKDIR" "$OUT"
cd "$WORKDIR"

git init immortalwrt
cd immortalwrt
git remote add origin https://github.com/immortalwrt/immortalwrt.git
git fetch --depth 1 origin "$IWRT_COMMIT"
git checkout --detach FETCH_HEAD

cp "$GITHUB_WORKSPACE/firmware/f9k1103-immortalwrt-18.06/rt3883_belkin_f9k1103v1.dts"    target/linux/ramips/dts/

python3 - <<'PY'
from pathlib import Path

def replace_once(path, old, new):
    p=Path(path)
    s=p.read_text()
    if old not in s:
        raise SystemExit("anchor not found: %s" % path)
    p.write_text(s.replace(old,new,1))

p='target/linux/ramips/image/rt3883.mk'
anchor='TARGET_DEVICES += belkin_f9k1109v1\n'
profile=r'''
TARGET_DEVICES += belkin_f9k1109v1

define Device/belkin_f9k1103v1
  SOC := rt3883
  BLOCKSIZE := 64k
  DEVICE_VENDOR := Belkin
  DEVICE_MODEL := F9K1103
  DEVICE_VARIANT := Version 1.0
  DEVICE_PACKAGES := kmod-usb-ohci kmod-usb2 kmod-usb-ledtrig-usbport swconfig
  IMAGE_SIZE := 7808k
  KERNEL := kernel-bin | append-dtb | lzma -d16 | uImage lzma
  UIMAGE_NAME := N750F9K1103VB
endef
TARGET_DEVICES += belkin_f9k1103v1
'''
replace_once(p,anchor,profile)

p='target/linux/ramips/rt3883/base-files/etc/board.d/02_network'
s=Path(p).read_text()
s=s.replace('belkin,f9k1109v1)\n\t\tucidef_add_switch "switch0"', 'belkin,f9k1103v1|\\\n\tbelkin,f9k1109v1)\n\t\tucidef_add_switch "switch0"', 1)
s=s.replace('belkin,f9k1109v1)\n\t\twan_mac=$(mtd_get_mac_ascii uboot-env HW_WAN_MAC)', 'belkin,f9k1103v1|\\\n\tbelkin,f9k1109v1)\n\t\twan_mac=$(mtd_get_mac_ascii uboot-env HW_WAN_MAC)', 1)
Path(p).write_text(s)
PY

git diff -- target/linux/ramips/dts/rt3883_belkin_f9k1103v1.dts  target/linux/ramips/image/rt3883.mk  target/linux/ramips/rt3883/base-files/etc/board.d/02_network  > "$GITHUB_WORKSPACE/F9K1103-IMMORTALWRT-18.06.patch"

./scripts/feeds update -a
./scripts/feeds install -a

cat > .config <<'CFG'
CONFIG_TARGET_ramips=y
CONFIG_TARGET_ramips_rt3883=y
CONFIG_TARGET_ramips_rt3883_DEVICE_belkin_f9k1103v1=y
CONFIG_TARGET_ROOTFS_SQUASHFS=y
CONFIG_PACKAGE_luci=y
CFG

make defconfig
cp .config "$OUT/BUILD-CONFIG.txt"
make -j2 download V=s
make -j2 V=s

cp -av bin/targets/ramips/rt3883/*f9k1103v1* "$OUT/"
cp -av "$GITHUB_WORKSPACE/F9K1103-IMMORTALWRT-18.06.patch" "$OUT/"
git rev-parse HEAD > "$OUT/IMMORTALWRT_SOURCE_COMMIT.txt"

cat > "$OUT/BUILD-INFO.txt" <<EOF
Base: ImmortalWrt 18.06-SNAPSHOT
Source commit: $IWRT_COMMIT
Reference device: Belkin F9K1109 v1
Target device: Belkin F9K1103 v1
Target: ramips/rt3883
uImage name: N750F9K1103VB
Firmware partition: 0x50000 + 0x7a0000
Status: PORT-WIP / build validation required / NOT hardware-runtime-verified\nBuild pipeline revision: 2
EOF

python3 - "$OUT" <<'PY'
import binascii, pathlib, struct, sys
out=pathlib.Path(sys.argv[1])
bins=sorted(out.glob('*f9k1103v1*squashfs*sysupgrade.bin'))
if not bins:
    raise SystemExit('No F9K1103 v1 sysupgrade image produced')
report=[]
for p in bins:
    b=p.read_bytes()
    if len(b)<64: raise SystemExit('image too short')
    hdr=b[:64]
    magic,hcrc,ts,size,load,entry,dcrc=struct.unpack('>7I',hdr[:28])
    comp=hdr[31]
    name=hdr[32:64].split(b'\0',1)[0].decode('ascii','replace')
    hz=bytearray(hdr); hz[4:8]=b'\0'*4
    h_ok=(binascii.crc32(hz)&0xffffffff)==hcrc
    payload=b[64:64+size]
    d_ok=(binascii.crc32(payload)&0xffffffff)==dcrc
    squash=b.find(b'hsqs')
    ok=(magic==0x27051956 and h_ok and d_ok and name=='N750F9K1103VB' and len(b)<=0x7a0000 and squash>=0)
    report += [f'file={p.name}',f'total_size={len(b)}',f'uimage_name={name}',f'uimage_magic=0x{magic:08x}',f'uimage_payload_size={size}',f'compression={comp}',f'header_crc_ok={h_ok}',f'payload_crc_ok={d_ok}',f'squashfs_offset={squash}',f'fits_partition={len(b)<=0x7a0000}',f'VALIDATION={"PASS" if ok else "FAIL"}','']
    if not ok: raise SystemExit('static validation failed')
(out/'STATIC-VALIDATION.txt').write_text('\n'.join(report))
PY

(cd "$OUT" && sha256sum * > SHA256SUMS.txt)
