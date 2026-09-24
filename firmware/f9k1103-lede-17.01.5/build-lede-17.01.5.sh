#!/usr/bin/env bash
set -euo pipefail
export FORCE_UNSAFE_CONFIGURE=1

LEDE_TAG=v17.01.5
WORKDIR="${PWD}/_f9k1103_lede17015_build"
OUT="${GITHUB_WORKSPACE}/out-f9k1103-lede-17.01.5"

rm -rf "$WORKDIR" "$OUT"
mkdir -p "$WORKDIR" "$OUT"
cd "$WORKDIR"

git clone --depth 1 --branch "$LEDE_TAG" https://github.com/lede-project/source.git lede
cd lede

# LEDE 17.01.5 ships m4 1.4.18 with old gnulib code that fails on
# glibc >= 2.28. Backport OpenWrt's later compatibility patch verbatim.
wget -qO tools/m4/patches/010-glibc-change-work-around.patch \
  https://raw.githubusercontent.com/openwrt/openwrt/v19.07.0/tools/m4/patches/010-glibc-change-work-around.patch

# The historical feed host was retired; use the GitHub mirrors while keeping
# the exact commits pinned by LEDE v17.01.5.
sed -i \
  -e 's#https://git.lede-project.org/feed/packages.git#https://github.com/openwrt/packages.git#' \
  -e 's#https://git.lede-project.org/project/luci.git#https://github.com/openwrt/luci.git#' \
  -e 's#https://git.lede-project.org/feed/routing.git#https://github.com/openwrt/routing.git#' \
  -e 's#https://git.lede-project.org/feed/telephony.git#https://github.com/openwrt/telephony.git#' \
  feeds.conf.default

# LEDE's historical keyring Git host now presents an OpenWrt certificate and
# fails strict TLS validation. Keep the exact pinned 2017 commit, but fetch it
# from the official OpenWrt GitHub mirror.
sed -i 's#PKG_SOURCE_URL=$(LEDE_GIT)/keyring.git#PKG_SOURCE_URL:=https://github.com/openwrt/keyring.git#' \
  package/system/lede-keyring/Makefile

cp "$GITHUB_WORKSPACE/firmware/f9k1103-lede-17.01.5/F9K1103.dts" target/linux/ramips/dts/
# LEDE 17.01.5's lzma-loader wrapper already passes PLATFORM="ralink"
# to its inner loader build. Do not pass/override the later OpenWrt PLATFORM
# variable at the outer make level: on this old tree it collides with legacy
# build-system state and can leave TARGET_CROSS empty (observed as "cc -o .o").
cp "$GITHUB_WORKSPACE/firmware/f9k1103-lede-17.01.5/010-glibc-change-work-around.patch" tools/m4/patches/010-glibc-change-work-around.patch
# Backport OpenWrt's own post-17.01 host-glibc compatibility fixes.
cp "$GITHUB_WORKSPACE/firmware/f9k1103-lede-17.01.5/010-m4-glibc-change-work-around.patch" tools/m4/patches/010-glibc-change-work-around.patch
cp "$GITHUB_WORKSPACE/firmware/f9k1103-lede-17.01.5/110-findutils-glibc-change-work-around.patch" tools/findutils/patches/110-glibc-change-work-around.patch
cp "$GITHUB_WORKSPACE/firmware/f9k1103-lede-17.01.5/125-e2fsprogs-glibc-sysmacros.patch" tools/e2fsprogs/patches/125-glibc-2.23-sysmacros.patch
cp "$GITHUB_WORKSPACE/firmware/f9k1103-lede-17.01.5/120-bison-glibc-2.28.patch" tools/bison/patches/120-glibc-2.28-fseterr.patch

python3 - <<'PY'
from pathlib import Path

def replace_once(path, old, new):
    p=Path(path)
    s=p.read_text()
    if old not in s:
        raise SystemExit(f'anchor not found in {path}: {old!r}')
    p.write_text(s.replace(old,new,1))

# 0. Backport the later ramips embedded LZMA loader image command.
# LEDE 17.01.5 already contains target/linux/ramips/image/lzma-loader;
# it only lacks the image-pipeline wrapper added later upstream.
replace_once(
    'target/linux/ramips/image/Makefile',
    '''define Build/relocate-kernel
''',
    '''define Build/loader-common
\trm -rf $@.src
\t$(MAKE) -C lzma-loader PKG_BUILD_DIR="$@.src" TARGET_DIR="$(dir $@)" LOADER_NAME="$(notdir $@)" BOARD="$(BOARDNAME)" LZMA_TEXT_START=0x81800000 LOADADDR=$(KERNEL_LOADADDR) LOADER_DATA="$@" compile loader.bin
\tmv "$@.bin" "$@"
\trm -rf $@.src
endef

define Build/loader-kernel
\t$(call Build/loader-common)
endef

define Build/relocate-kernel
''',
)

# 1. Image recipe. 7808 KiB == 0x7a0000 firmware partition.
replace_once(
    'target/linux/ramips/image/rt3883.mk',
    'TARGET_DEVICES += rt-n56u\n',
    '''TARGET_DEVICES += rt-n56u

define Device/f9k1103
  DTS := F9K1103
  BLOCKSIZE := 64k
  IMAGE_SIZE := 7808k
  UIMAGE_NAME := N750F9K1103VB
  # Belkin's stock U-Boot has known LZMA decompression issues on this
  # F9K110x platform family. Embed the LZMA kernel in OpenWrt's tiny
  # self-relocating loader and mark the outer uImage as uncompressed.
  LOADER_TYPE := bin
  KERNEL := kernel-bin | patch-dtb | lzma | loader-kernel | uImage none
  DEVICE_TITLE := Belkin F9K1103 v1
  DEVICE_PACKAGES := kmod-usb-core kmod-usb-ohci kmod-usb2 swconfig
endef
TARGET_DEVICES += f9k1103
'''
)

# 2. Old ramips board detection.
replace_once(
    'target/linux/ramips/base-files/lib/ramips.sh',
    '\t*"RT-N56U")\n\t\tname="rt-n56u"\n\t\t;;\n',
    '''\t*"Belkin F9K1103"*)
\t\tname="f9k1103"
\t\t;;
\t*"RT-N56U")
\t\tname="rt-n56u"
\t\t;;
'''
)

# 3. Network topology: RTL8367R-VB LAN 0..3, WAN 4, CPU 5.
replace_once(
    'target/linux/ramips/base-files/etc/board.d/02_network',
    '\trt-n56u)\n\t\tucidef_add_switch "switch0" \\\n\t\t\t"0:lan" "1:lan" "2:lan" "3:lan" "4:wan" "8@eth0"\n\t\t;;\n',
    '''\tf9k1103)
\t\tucidef_add_switch "switch0" \\
\t\t\t"0:lan" "1:lan" "2:lan" "3:lan" "4:wan" "5@eth0"
\t\t;;
\trt-n56u)
\t\tucidef_add_switch "switch0" \\
\t\t\t"0:lan" "1:lan" "2:lan" "3:lan" "4:wan" "8@eth0"
\t\t;;
'''
)

# 4. F9K1103 stock U-Boot/NVRAM MAC variable names.
replace_once(
    'target/linux/ramips/base-files/etc/board.d/02_network',
    '\trt-n56u)\n\t\tlan_mac=$(cat /sys/class/net/eth0/address)\n',
    '''\tf9k1103)
\t\twan_mac=$(mtd_get_mac_ascii uboot-env HW_WAN_MAC)
\t\tlan_mac=$(mtd_get_mac_ascii uboot-env HW_LAN_MAC)
\t\t;;
\trt-n56u)
\t\tlan_mac=$(cat /sys/class/net/eth0/address)
'''
)

# 5. Allow normal uImage sysupgrade on the custom board.
replace_once(
    'target/linux/ramips/base-files/lib/upgrade/platform.sh',
    '\tf7c027|\\\n',
    '\tf7c027|\\\n\tf9k1103|\\\n'
)

# 6. LED GPIOs are defined directly in the DTS; no board.d patch is required.

PY

echo "=== LEDE 17.01.5 lzma-loader sanity ==="
grep -nE '^(PLATFORM|loader-compile:)|PLATFORM=' target/linux/ramips/image/lzma-loader/Makefile || true
python3 - <<'PY_LZMA_SANITY'
from pathlib import Path
p = Path('target/linux/ramips/image/lzma-loader/Makefile')
s = p.read_text()
if 'PLATFORM="ralink"' not in s:
    raise SystemExit('LEDE lzma-loader lost its stock PLATFORM="ralink" inner-build setting')
if 'PLATFORM="$(PLATFORM)"' in s:
    raise SystemExit('Unexpected later-OpenWrt PLATFORM passthrough is present; this caused the previous empty-platform loader failure')
print('lzma-loader platform sanity: PASS (stock LEDE hardcoded ralink)')
PY_LZMA_SANITY
echo "Using stock LEDE 17.01.5 lzma-loader inner PLATFORM=ralink path; no outer PLATFORM override"

git diff --   target/linux/ramips/dts/F9K1103.dts   target/linux/ramips/image/Makefile   target/linux/ramips/image/rt3883.mk   target/linux/ramips/base-files/lib/ramips.sh   target/linux/ramips/base-files/etc/board.d/01_leds   target/linux/ramips/base-files/etc/board.d/02_network   target/linux/ramips/base-files/lib/upgrade/platform.sh   > "$GITHUB_WORKSPACE/F9K1103-LEDE-17.01.5.patch"

./scripts/feeds update -a
./scripts/feeds install -a

cat > .config <<'CFG'
CONFIG_TARGET_ramips=y
CONFIG_TARGET_ramips_rt3883=y
CONFIG_TARGET_ramips_rt3883_DEVICE_f9k1103=y
CONFIG_TARGET_ROOTFS_SQUASHFS=y
CONFIG_TARGET_ROOTFS_INITRAMFS=y
CONFIG_PACKAGE_luci=y
CFG

make defconfig
make -j2 download
make -j2 V=s

cp -av bin/targets/ramips/rt3883/*f9k1103* "$OUT/" || true
cp -av "$GITHUB_WORKSPACE/F9K1103-LEDE-17.01.5.patch" "$OUT/"
git rev-parse HEAD > "$OUT/LEDE_SOURCE_COMMIT.txt"

cat > "$OUT/BUILD-INFO.txt" <<EOF
Base: LEDE/OpenWrt 17.01.5
Tag: $LEDE_TAG
Board: Belkin F9K1103 v1
Target: ramips/rt3883
DTS: F9K1103
uImage name: N750F9K1103VB
Firmware partition: 0x50000 + 0x7a0000
Status: PORT-WIP / build-verified / NOT hardware-runtime-verified
EOF

python3 - "$OUT" <<'PY'
import binascii, pathlib, struct, sys
out=pathlib.Path(sys.argv[1])
report=[]
bins=sorted(out.glob('*f9k1103*squashfs*sysupgrade.bin'))
if not bins:
    raise SystemExit('No F9K1103 squashfs sysupgrade image was produced')
for p in bins:
    b=p.read_bytes()
    if len(b)<64:
        raise SystemExit(f'{p.name}: too short')
    hdr=b[:64]
    magic,hcrc,ts,size,load,entry,dcrc=struct.unpack('>7I',hdr[:28])
    os_,arch,typ,comp=hdr[28:32]
    name=hdr[32:64].split(b'\0',1)[0].decode('ascii','replace')
    hz=bytearray(hdr)
    hz[4:8]=b'\0\0\0\0'
    calc_h=binascii.crc32(hz)&0xffffffff
    payload=b[64:64+size]
    calc_d=binascii.crc32(payload)&0xffffffff
    squash=b.find(b'hsqs')
    ok=(
        magic==0x27051956 and
        hcrc==calc_h and
        dcrc==calc_d and
        name=='N750F9K1103VB' and
        comp==0 and
        len(b)<=0x7a0000 and
        squash>=0
    )
    report += [
        f'file={p.name}',
        f'total_size={len(b)}',
        f'partition_limit={0x7a0000}',
        f'uimage_magic=0x{magic:08x}',
        f'uimage_name={name}',
        f'uimage_payload_size={size}',
        f'outer_compression={comp} (0=none)',
        f'load=0x{load:08x}',
        f'entry=0x{entry:08x}',
        f'header_crc_ok={hcrc==calc_h}',
        f'payload_crc_ok={dcrc==calc_d}',
        f'squashfs_offset={squash}',
        f'fits_partition={len(b)<=0x7a0000}',
        f'VALIDATION={"PASS" if ok else "FAIL"}',
        ''
    ]
    if not ok:
        raise SystemExit(f'{p.name}: static validation failed')
(out/'STATIC-VALIDATION.txt').write_text('\n'.join(report))
PY

(
  cd "$OUT"
  sha256sum * > SHA256SUMS.txt
)
