#!/bin/sh
# RE-F9K1103-C15R8-PHYSICAL-PREFLIGHT.sh
# Read-only / test-only preflight for Candidate-15R8.
# This script NEVER performs a firmware write and NEVER uses sysupgrade -F.

set -u

IMG="${1:-/tmp/RE-F9K1103-CUDY-WR1200E-CANDIDATE-15R8-BOOTFIRST-sysupgrade.bin}"
REPORT="${2:-/tmp/RE-C15R8-PREFLIGHT.txt}"
EXPECTED_SHA='03c6bcc370ceba9bdd9dc7a068cdb7679ce12a720bd99446146759ba950674a5'
EXPECTED_UBOOT_SHA='3498feb4d33fe678319510af47b0ad5607c9a0006e217ad8babe6fc5317dadf7'
EXPECTED_BOARD='f9k1103'
EXPECTED_MODEL='Belkin F9K1103 Version 1.0'
FIRMWARE_MAX_BYTES=7995392

exec >"$REPORT" 2>&1

echo 'RE_F9K1103_C15R8_PREFLIGHT=BEGIN'
echo "IMAGE=$IMG"
echo "EXPECTED_SHA256=$EXPECTED_SHA"
echo "FLASH_ACTION=NONE"
echo "FORCE_FLASH_USED=NO"

date 2>/dev/null || true
uname -a 2>/dev/null || true

fail=0

if [ ! -f "$IMG" ]; then
    echo 'IMAGE_PRESENT=NO'
    echo 'PREFLIGHT=FAIL'
    exit 20
fi
echo 'IMAGE_PRESENT=YES'

BOARD="$(cat /tmp/sysinfo/board_name 2>/dev/null || true)"
MODEL="$(cat /tmp/sysinfo/model 2>/dev/null || true)"
[ -n "$MODEL" ] || MODEL="$(ubus call system board 2>/dev/null | sed -n 's/.*"model"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"

echo "BOARD_NAME=$BOARD"
echo "MODEL=$MODEL"

if [ "$BOARD" = "$EXPECTED_BOARD" ]; then
    echo 'BOARD_NAME_GATE=PASS'
else
    echo 'BOARD_NAME_GATE=FAIL'
    fail=1
fi

if [ "$MODEL" = "$EXPECTED_MODEL" ]; then
    echo 'MODEL_GATE=PASS'
else
    echo 'MODEL_GATE=FAIL'
    fail=1
fi

echo '--- PROC_MTD ---'
cat /proc/mtd 2>/dev/null || true

audit_mtd() {
    name="$1"
    expected="$2"
    got="$(awk -v n="\"$name\"" '$4 == n {print $2; exit}' /proc/mtd 2>/dev/null)"
    echo "MTD_${name}_SIZE=${got:-MISSING}"
    if [ "$got" = "$expected" ]; then
        echo "MTD_${name}_GATE=PASS"
    else
        echo "MTD_${name}_GATE=FAIL"
        fail=1
    fi
}

audit_mtd 'u-boot'     '00030000'
audit_mtd 'uboot-env'  '00010000'
audit_mtd 'factory'    '00010000'
audit_mtd 'firmware'   '007a0000'
audit_mtd 'user-cfg'   '00010000'

if [ -r /dev/mtd0 ]; then
    UBOOT_SHA="$(sha256sum /dev/mtd0 2>/dev/null | awk '{print $1}')"
elif [ -r /dev/mtdblock0 ]; then
    UBOOT_SHA="$(sha256sum /dev/mtdblock0 2>/dev/null | awk '{print $1}')"
else
    UBOOT_SHA='UNAVAILABLE'
fi

echo "UBOOT_SHA256=$UBOOT_SHA"
if [ "$UBOOT_SHA" = "$EXPECTED_UBOOT_SHA" ]; then
    echo 'UBOOT_HASH_GATE=PASS'
else
    echo 'UBOOT_HASH_GATE=FAIL'
    fail=1
fi

IMAGE_BYTES="$(wc -c < "$IMG" | tr -d ' ')"
IMAGE_SHA="$(sha256sum "$IMG" | awk '{print $1}')"
IMAGE_NAME="$(dd if="$IMG" bs=1 skip=32 count=32 2>/dev/null | tr -d '\000' | sed 's/[[:space:]]*$//')"

echo "IMAGE_BYTES=$IMAGE_BYTES"
echo "IMAGE_SHA256=$IMAGE_SHA"
echo "UIMAGE_NAME=$IMAGE_NAME"

if [ "$IMAGE_SHA" = "$EXPECTED_SHA" ]; then
    echo 'IMAGE_HASH_GATE=PASS'
else
    echo 'IMAGE_HASH_GATE=FAIL'
    fail=1
fi

if [ "$IMAGE_BYTES" -le "$FIRMWARE_MAX_BYTES" ] 2>/dev/null; then
    echo 'IMAGE_SIZE_GATE=PASS'
else
    echo 'IMAGE_SIZE_GATE=FAIL'
    fail=1
fi

case "$IMAGE_NAME" in
    N750F9K1103VB*) echo 'UIMAGE_NAME_GATE=PASS' ;;
    *) echo 'UIMAGE_NAME_GATE=FAIL'; fail=1 ;;
esac

if [ "$fail" -ne 0 ]; then
    echo 'SYSUPGRADE_T=SKIPPED_DUE_TO_PRECHECK_FAILURE'
    echo 'PREFLIGHT=FAIL'
    echo 'FLASH_PERFORMED=NO'
    exit 30
fi

echo '--- SYSUPGRADE_TEST ---'
set +e
sysupgrade -T "$IMG"
RC=$?
set -e

echo "SYSUPGRADE_T_RC=$RC"
if [ "$RC" -eq 0 ]; then
    echo 'SYSUPGRADE_T=PASS'
    echo 'PREFLIGHT=PASS'
else
    echo 'SYSUPGRADE_T=FAIL'
    echo 'PREFLIGHT=FAIL'
fi

echo 'FLASH_PERFORMED=NO'
echo 'REBOOT_PERFORMED=NO'
echo 'NEXT_ACTION=STOP_AND_REVIEW_REPORT_BEFORE_ANY_FLASH'
echo 'RE_F9K1103_C15R8_PREFLIGHT=END'

[ "$RC" -eq 0 ]
