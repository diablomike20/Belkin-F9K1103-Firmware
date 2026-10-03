# FU9 — Belkin F9K1103 v1 / LEDE 17.01.5 status

## 1. Authoritative target identity

Physical target:
- Belkin F9K1103 v1 / N750 DB
- RT3883
- 64 MB RAM
- 8 MB SPI NOR
- RTL8367R-VB
- dual-band
- two USB 2.0 ports

Important correction:
The OpenWrt 19 firmware used on the physical F9K1103 was an F9K1109 v1 build, not a native F9K1103 target.

Reference image:
openwrt-19.07.0-ramips-rt3883-belkin_f9k1109v1-squashfs-sysupgrade.bin

This remains hardware/reference evidence, not proof that F9K1103 == F9K1109.

## 2. Why LEDE 17.01.5 is primary

The Cudy donor family under study strongly converges on LEDE 17.01.5 userspace:
- LT500D R25
- WR1200 V2/R26
- WR1300
- WR2100
- other historical Cudy lines

Therefore the desired Belkin Cudy port has a cleaner compatibility target if the base system itself is LEDE 17.01.5.

OpenWrt 19 remains useful for:
- known working board support
- RT3883/F9K110x hardware reference
- switch/radio/flash comparison
- recovery and image-layout comparison

## 3. Native F9K1103 LEDE source

Repository:
diablomike20/Belkin-F9K1103-Firmware

Source:
firmware/f9k1103-lede-17.01.5/

Key files:
- README.md
- F9K1103.dts
- build-lede-17.01.5.sh
- host glibc compatibility patches

The port is a native target, not a renamed RT-N56U binary.

## 4. Board definition facts

Flash:
- u-boot: 0x000000..0x02ffff
- uboot-env: 0x030000..0x03ffff
- factory: 0x040000..0x04ffff
- firmware starts 0x050000
- user-cfg: 0x7f0000..0x7fffff

Switch:
- RTL8367R-VB family
- SMI GPIO 1/2
- LAN 0..3
- WAN 4
- CPU port 5

GPIO:
- reset 25
- WPS 26
- power LED 0
- LAN LED 13
- WAN LED 12
- USB LED 9

Radio calibration:
- SoC WMAC: factory + 0x0000
- PCI RT3091/RT3092: factory + 0x8000

Image:
- uImage name N750F9K1103VB
- HW_WAN_MAC / HW_LAN_MAC stock-family evidence

## 5. Historical LEDE build failures

Earlier builds failed in/around the old LEDE ramips lzma-loader path.
Observed class:
- outer PLATFORM handling collided with old LEDE build assumptions
- empty/incorrect loader object/source names
- modern host glibc compatibility issues also required backports

The build script contains explicit historical guards so these old failures should not be reintroduced blindly.

## 6. Current SUCCESS candidates

### 6.1 Clean direct-LZMA — primary static candidate

Run:
36964886797

Head:
ee79c687cffee78d274a3da63a3bec53a34ed19b

Artifact ID:
11210566323

LEDE source:
248b35890339d70d7b43e3b40fba0281f854ed9a

Sysupgrade:
SHA256 b78106c7509a31f886682e9d071f6d41fdaee7bd6f209add4a4aa6b61a9f0622
size 3,670,185

Initramfs:
SHA256 ec8c0d181804c27f2ceda71f6110a82b1dcd1e6c0cd178cc2c3f0e93787af1da

Static validation:
- uImage magic PASS
- N750F9K1103VB PASS
- LZMA compression
- load/entry 0x80000000
- header CRC PASS
- payload CRC PASS
- SquashFS detected
- upstream image size limit PASS
- physical partition size PASS

Status:
STATIC_VERIFIED
TARGET_REQUIRED

### 6.2 Direct-LZMA alternate

Run:
36964149495
Head:
7ce3aa38ab4781bbe9a7f24885879702c1fe6bc1

Sysupgrade:
67c4b54e108256a38a879873c7c2f267b3ec945413b53b10e0361b06c2170444

Initramfs:
829b0e19a5140d27d0c90b2d75d04a8eb438f6a7bf1870689e6b0dcb0e35fa09

Status:
STATIC_VERIFIED / TARGET_REQUIRED

### 6.3 Minimal boot baseline

Run:
36964690258
Head:
2bf62b1ee82246b9ea59d6f904427f2048d74e28

Sysupgrade:
a918447c22de77e2e446d0950cc119a5b47bfe14f3af43962df4d787b9f328c9
size 3,342,505

Initramfs:
784cb062e6d238712469b4d3bb61295ab0cd735ffa725d24b5cd10f9ff1bf592

Status:
STATIC_VERIFIED / TARGET_REQUIRED

## 7. Other F9K1103 native build lines

OpenWrt 23.05.5:
- run 36031900371
- SUCCESS
- static build
- physical target runtime not verified

ImmortalWrt 18.06:
- run 36031917929
- SUCCESS
- static build
- physical target runtime not verified

These are fallback/reference lines, not the current primary direction.

## 8. Physical boot definition

A successful build is NOT a successful router port.

Physical acceptance must separately prove:
1. bootloader accepts image
2. kernel boots reliably
3. correct MTD partition map
4. rootfs/overlay stable
5. LAN switch
6. WAN switch
7. RTL8367R-VB CPU link
8. 2.4 GHz
9. 5 GHz
10. factory calibration
11. MAC extraction
12. LEDs/buttons
13. USB host
14. LuCI/login
15. reboot persistence
16. sysupgrade
17. recovery

## 9. Safety of first physical test

No automatic flash.
The user must explicitly choose physical testing.

Before physical test:
- recovery route must be documented
- current F9K1109/OpenWrt recovery reference preserved
- exact image SHA checked
- static image metadata rechecked
- no config preservation assumptions carried across incompatible layouts without proof

Prefer the least destructive/recoverable method available.

## 10. Cudy port after LEDE boot

After physical LEDE verification:
1. import Cudy assets/theme
2. establish Cudy LuCI framework compatibility
3. port navigation and login without breaking auth
4. port dashboard
5. System/LAN/DHCP
6. build Belkin-specific adapters
7. Wireless
8. WAN
9. Devices
10. Advanced functions
11. USB functions only with real hardware support
12. safe OpenCudy Developer additions

Primary donors:
- WR1200 V2 R26 2.4.12 / 2.4.23
- LT500D R25 2.4.16

Do not bulk-copy Cudy hardware binaries.

## 11. Current handoff verdict

The native F9K1103 LEDE 17.01.5 build problem has crossed an important milestone:
**BUILD SUCCESS + STATIC VALIDATION PASS now exists.**

The next real blocker is:
**PHYSICAL BOOT / HARDWARE RUNTIME VERIFICATION.**
