#!/usr/bin/env python3
import argparse, binascii, pathlib, struct, sys

LIMIT = 7224 * 1024
UIMAGE_MAGIC = 0x27051956

def read_layout(data: bytes):
    if len(data) < 128:
        raise ValueError("image too short")
    magic,hcrc,ts,size,load,entry,dcrc = struct.unpack(">7I", data[:28])
    if magic != UIMAGE_MAGIC:
        raise ValueError(f"bad uImage magic: 0x{magic:08x}")
    rootfs_off = 64 + size
    if data[rootfs_off:rootfs_off+4] != b"hsqs":
        raise ValueError(f"SquashFS magic missing at {rootfs_off}")
    bytes_used = struct.unpack_from("<Q", data, rootfs_off + 40)[0]
    rootfs_end = rootfs_off + bytes_used
    if rootfs_end > len(data):
        raise ValueError("invalid squashfs bytes_used")
    tsize = struct.unpack(">I", data[-4:])[0]
    if not (16 <= tsize <= 65536 and tsize <= len(data)-rootfs_end):
        raise ValueError(f"invalid fwtool record size: {tsize}")
    return {
        "magic":magic, "hcrc":hcrc, "timestamp":ts, "payload_size":size,
        "load":load, "entry":entry, "dcrc":dcrc, "rootfs_off":rootfs_off,
        "rootfs_bytes_used":bytes_used, "rootfs_end":rootfs_end,
        "fwtool_size":tsize
    }

def split_image(image, work):
    data = pathlib.Path(image).read_bytes()
    l = read_layout(data)
    out = pathlib.Path(work)
    out.mkdir(parents=True, exist_ok=True)
    (out/"kernel.bin").write_bytes(data[:l["rootfs_off"]])
    (out/"rootfs.squashfs").write_bytes(data[l["rootfs_off"]:l["rootfs_end"]])
    (out/"fwtool-meta.bin").write_bytes(data[-l["fwtool_size"]:])
    (out/"layout.txt").write_text(
        f'uimage_payload_size={l["payload_size"]}\n'
        f'rootfs_offset={l["rootfs_off"]}\n'
        f'rootfs_bytes_used={l["rootfs_bytes_used"]}\n'
        f'fwtool_record_size={l["fwtool_size"]}\n'
    )

def extract_rootfs(image, out_path):
    data = pathlib.Path(image).read_bytes()
    l = read_layout(data)
    pathlib.Path(out_path).write_bytes(data[l["rootfs_off"]:l["rootfs_end"]])

def validate(image, report):
    p = pathlib.Path(image)
    b = p.read_bytes()
    l = read_layout(b)
    hdr = b[:64]
    name = hdr[32:64].split(b"\0",1)[0].decode("ascii","replace")
    hz = bytearray(hdr)
    hz[4:8] = b"\0\0\0\0"
    hc = binascii.crc32(hz) & 0xffffffff
    payload = b[64:64+l["payload_size"]]
    dc = binascii.crc32(payload) & 0xffffffff
    ok = (
        l["hcrc"] == hc and l["dcrc"] == dc and
        name == "N750F9K1103VB" and len(b) <= LIMIT
    )
    lines = [
        f"file={p.name}",
        f"size={len(b)}",
        f"uimage_name={name}",
        f"header_crc_ok={l['hcrc']==hc}",
        f"payload_crc_ok={l['dcrc']==dc}",
        f"squashfs_offset={l['rootfs_off']}",
        f"rootfs_bytes_used={l['rootfs_bytes_used']}",
        f"fwtool_record_size={l['fwtool_size']}",
        f"fits_7224k={len(b)<=LIMIT}",
        f"VALIDATION={'PASS' if ok else 'FAIL'}",
    ]
    pathlib.Path(report).write_text("\n".join(lines)+"\n")
    if not ok:
        raise SystemExit("static validation failed")

def main():
    ap=argparse.ArgumentParser()
    sub=ap.add_subparsers(dest="cmd", required=True)
    s=sub.add_parser("split"); s.add_argument("image"); s.add_argument("work")
    e=sub.add_parser("extract-rootfs"); e.add_argument("image"); e.add_argument("out")
    v=sub.add_parser("validate"); v.add_argument("image"); v.add_argument("report")
    a=ap.parse_args()
    if a.cmd=="split": split_image(a.image,a.work)
    elif a.cmd=="extract-rootfs": extract_rootfs(a.image,a.out)
    elif a.cmd=="validate": validate(a.image,a.report)

if __name__=="__main__":
    main()
