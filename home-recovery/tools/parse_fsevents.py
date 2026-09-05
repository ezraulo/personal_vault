#!/usr/bin/env python3
"""Parse macOS fseventsd DLS logs into (path, event_id, flags) records.

Usage: parse_fsevents.py <dir> [--since-file NAME] [--grep SUBSTR]

Container: one or more concatenated gzip members.
Page:   magic '1SLD'|'2SLD'|'3SLD' | u32 unknown | u32 page_len | records...
Record: NUL-terminated path, u64 event_id, u32 flags,
        and for 3SLD a u64 node_id + u32 reserved (24-byte tail total).
"""
import sys, os, zlib, struct

FLAGS = [
    (0x00000001, "FolderEvent"), (0x00000002, "Mount"), (0x00000004, "Unmount"),
    (0x00000020, "EndOfTransaction"), (0x00000800, "LastHardLinkRemoved"),
    (0x00001000, "HardLink"), (0x00004000, "SymbolicLink"), (0x00008000, "FileEvent"),
    (0x00010000, "PermissionChange"), (0x00020000, "XattrModified"),
    (0x00040000, "XattrRemoved"), (0x00100000, "DocumentRevision"),
    (0x00400000, "ItemCloned"), (0x01000000, "Created"), (0x02000000, "Removed"),
    (0x04000000, "InodeMetaMod"), (0x08000000, "Renamed"), (0x10000000, "Modified"),
    (0x20000000, "Exchange"), (0x40000000, "FinderInfoMod"), (0x80000000, "FolderCreated"),
]

def decode_flags(f):
    out = [n for b, n in FLAGS if f & b]
    rest = f & ~sum(b for b, _ in FLAGS)
    if rest:
        out.append(hex(rest))
    return "|".join(out) if out else hex(f)

def read_members(path):
    """Decompress every gzip member in the file, in order."""
    raw = open(path, "rb").read()
    out = []
    while len(raw) >= 2 and raw[:2] == b"\x1f\x8b":
        d = zlib.decompressobj(31)
        try:
            out.append(d.decompress(raw))
        except zlib.error:
            break
        nxt = d.unused_data
        if not nxt or nxt == raw:
            break
        raw = nxt
    return b"".join(out)

def parse_pages(buf):
    off = 0
    n = len(buf)
    while off + 12 <= n:
        magic = buf[off:off+4]
        if magic not in (b"1SLD", b"2SLD", b"3SLD"):
            off += 1
            continue
        page_len = struct.unpack("<I", buf[off+8:off+12])[0]
        end = min(off + page_len, n) if 12 < page_len <= n - off else n
        tail = 24 if magic == b"3SLD" else 12   # bytes after the path's NUL
        p = off + 12
        while p < end:
            z = buf.find(b"\x00", p, end)
            if z == -1 or z + tail >= end:
                break
            rawpath = buf[p:z]
            # A page's records are followed by padding. Real paths are non-empty and
            # contain no control bytes; anything else means we have run off the end.
            if not rawpath or min(rawpath) < 0x20:
                break
            path = rawpath.decode("utf-8", "replace")
            eid, flags = struct.unpack("<QI", buf[z+1:z+13])
            yield path, eid, flags
            p = z + 1 + tail
        off = end if end > off else off + 12

def main():
    d = sys.argv[1]
    grep = sys.argv[sys.argv.index("--grep")+1] if "--grep" in sys.argv else None
    names = sorted(x for x in os.listdir(d) if x != "fseventsd-uuid" and not x.startswith("."))
    if "--since-file" in sys.argv:
        s = sys.argv[sys.argv.index("--since-file")+1]
        names = [x for x in names if x >= s]
    w = sys.stdout.write
    for fn in names:
        try:
            buf = read_members(os.path.join(d, fn))
        except Exception as e:
            print(f"# {fn}: {e}", file=sys.stderr); continue
        for path, eid, flags in parse_pages(buf):
            if grep and grep not in path:
                continue
            w(f"{fn}\t{eid}\t{decode_flags(flags)}\t{path}\n")

if __name__ == "__main__":
    main()
