#!/usr/bin/env bash
set -euo pipefail

OWRT_TAG=v23.05.5
WORKDIR="${PWD}/_f9k1103_build"
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

git clone --depth 1 --branch "$OWRT_TAG" https://github.com/openwrt/openwrt.git openwrt
cd openwrt

cp "$GITHUB_WORKSPACE/firmware/f9k1103/rt3883_belkin_f9k1103v1.dts" target/linux/ramips/dts/

python3 - <<'PY'
from pathlib import Path
p=Path('target/linux/ramips/image/rt3883.mk')
s=p.read_text()
needle='TARGET_DEVICES += belkin_f9k1109v1\n'
block='''TARGET_DEVICES += belkin_f9k1109v1

define Device/belkin_f9k1103v1
  $(Device/uimage-lzma-loader)
  SOC := rt3883
  DEVICE_VENDOR := Belkin
  DEVICE_MODEL := F9K1103
  DEVICE_VARIANT := Version 1.0
  DEVICE_PACKAGES := kmod-usb-ohci kmod-usb2 kmod-usb-ledtrig-usbport
  IMAGE_SIZE := 7808k
  # F9K1103/F9K110x stock U-Boot validates this uImage name.
  UIMAGE_NAME := N750F9K1103VB
endef
TARGET_DEVICES += belkin_f9k1103v1
'''
if needle not in s:
    raise SystemExit('rt3883.mk anchor not found')
p.write_text(s.replace(needle, block, 1))

p=Path('target/linux/ramips/rt3883/base-files/etc/board.d/02_network')
s=p.read_text()
s=s.replace('''\tbelkin,f9k1109v1)\n\t\tucidef_add_switch "switch0" \\\n''','''\tbelkin,f9k1103v1|\\\n\tbelkin,f9k1109v1)\n\t\tucidef_add_switch "switch0" \\\n''',1)
s=s.replace('''\tbelkin,f9k1109v1)\n\t\twan_mac=$(mtd_get_mac_ascii uboot-env HW_WAN_MAC)\n''','''\tbelkin,f9k1103v1|\\\n\tbelkin,f9k1109v1)\n\t\twan_mac=$(mtd_get_mac_ascii uboot-env HW_WAN_MAC)\n''',1)
p.write_text(s)
PY

git diff -- target/linux/ramips/dts/rt3883_belkin_f9k1103v1.dts target/linux/ramips/image/rt3883.mk target/linux/ramips/rt3883/base-files/etc/board.d/02_network > "$GITHUB_WORKSPACE/F9K1103-OPENWRT-23.05.5.patch"

./scripts/feeds update -a
./scripts/feeds install -a

cat > .config <<'CFG'
CONFIG_TARGET_ramips=y
CONFIG_TARGET_ramips_rt3883=y
CONFIG_TARGET_ramips_rt3883_DEVICE_belkin_f9k1103v1=y
CONFIG_PACKAGE_luci=y
CONFIG_TARGET_ROOTFS_INITRAMFS=y
CFG
make defconfig

make -j"$(nproc)" download
make -j"$(nproc)" V=s

OUT="$GITHUB_WORKSPACE/out-f9k1103"
rm -rf "$OUT"
mkdir -p "$OUT"
cp -av bin/targets/ramips/rt3883/*f9k1103* "$OUT/" || true
cp -av bin/targets/ramips/rt3883/profiles.json "$OUT/" || true
cp -av "$GITHUB_WORKSPACE/F9K1103-OPENWRT-23.05.5.patch" "$OUT/"

git rev-parse HEAD > "$OUT/OPENWRT_SOURCE_COMMIT.txt"
{
  echo "OpenWrt tag: $OWRT_TAG"
  echo "Board: Belkin F9K1103 v1"
  echo "Compatible: belkin,f9k1103v1"
  echo "UIMAGE_NAME: N750F9K1103VB"
  echo "Firmware partition: 0x50000 + 0x7a0000 (shared F9K110x DTSI)"
  echo "Status: PORT-WIP / static build only / NOT hardware-runtime-verified"
} > "$OUT/BUILD-INFO.txt"

cd "$OUT"
for f in *f9k1103*bin; do
  [ -f "$f" ] || continue
  echo "===== $f =====" >> UIMAGE-HEADERS.txt
  dumpimage -l "$f" >> UIMAGE-HEADERS.txt 2>&1 || true
  stat -c 'size=%s bytes' "$f" >> UIMAGE-HEADERS.txt
  echo >> UIMAGE-HEADERS.txt
done
sha256sum * > SHA256SUMS.txt
