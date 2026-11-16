#!/usr/bin/env python3
"""Read-only ISO BMFF / QuickTime meta box walk (no external MP4Box)."""
from __future__ import annotations

import json
import re
import struct
import sys
from pathlib import Path

VIDEO = Path(__file__).resolve().parent.parent / "uploads" / "videos" / "1f9281ef0e0a4f05bccd19d54e3279aa.mp4"

# Keys we care about for provenance (literal tag names only).
PROVENANCE_KEY_HINTS = (
    b"com.android",
    b"android",
    b"manufacturer",
    b"model",
    b"make",
    b"camera",
    b"device",
    b"encoder",
    b"software",
    b"location",  # flag only, do not print values that look like GPS
)

SENSITIVE_VALUE_RE = re.compile(
    r"(\d{1,3}\.\d+,\s*\d{1,3}\.\d+)|"  # lat,lon-ish
    r"(\+?\d{2,3}\.\d{4,})|"  # long decimal coords
    r"(uuid|serial|imei)",
    re.I,
)


def read_box_header(data: bytes, offset: int) -> tuple[int, bytes, int] | None:
    if offset + 8 > len(data):
        return None
    size, typ = struct.unpack_from(">I4s", data, offset)
    typ = bytes(typ)
    head = 8
    if size == 1:
        if offset + 16 > len(data):
            return None
        size = struct.unpack_from(">Q", data, offset + 8)[0]
        head = 16
    elif size == 0:
        size = len(data) - offset
    if size < head or offset + size > len(data):
        return None
    return size, typ, head


def walk_boxes(
    data: bytes,
    start: int,
    end: int,
    path: str,
    depth: int,
    out: list[dict],
    max_depth: int = 12,
) -> None:
    if depth > max_depth:
        return
    off = start
    while off + 8 <= end:
        hdr = read_box_header(data, off)
        if hdr is None:
            break
        size, typ, head = hdr
        box_end = off + size
        name = typ.decode("latin-1", errors="replace")
        entry = {"path": f"{path}/{name}", "offset": off, "size": size}
        out.append(entry)
        container_types = {
            b"moov",
            b"trak",
            b"mdia",
            b"minf",
            b"stbl",
            b"udta",
            b"meta",
            b"ilst",
            b"keys",
            b"mdta",
            b"uuid",
            b"sinf",
            b"schi",
        }
        if typ in container_types and box_end > off + head:
            walk_boxes(data, off + head, box_end, entry["path"], depth + 1, out, max_depth)
        off = box_end


def parse_keys_box(data: bytes, offset: int, size: int) -> list[tuple[int, str]]:
    """Parse keys box: version + entry_count + (key_size, key_namespace)."""
    results: list[tuple[int, str]] = []
    inner = data[offset : offset + size]
    if len(inner) < 8:
        return results
    version_flags = struct.unpack_from(">I", inner, 0)[0]
    if version_flags >> 24 != 0:
        pass
    count = struct.unpack_from(">I", inner, 4)[0]
    pos = 8
    for i in range(count):
        if pos + 4 > len(inner):
            break
        ksize = struct.unpack_from(">I", inner, pos)[0]
        pos += 4
        if ksize < 8 or pos + ksize > len(inner):
            break
        ns = inner[pos : pos + 4].decode("latin-1", errors="replace")
        val = inner[pos + 4 : pos + ksize].decode("utf-8", errors="replace").strip("\x00")
        results.append((i + 1, f"{ns}:{val}" if ns else val))
        pos += ksize
    return results


def parse_ilst_string(data: bytes, offset: int, size: int) -> list[str]:
    """Best-effort ilst/data or ©xyz string extraction."""
    found: list[str] = []
    inner = data[offset : offset + size]
    off = 0
    while off + 8 <= len(inner):
        hdr = read_box_header(inner, off)
        if hdr is None:
            break
        bsize, btyp, bhead = hdr
        payload = inner[off + bhead : off + bsize]
        # data box: type indicator + locale + value
        if btyp == b"data" and len(payload) >= 8:
            type_code = struct.unpack_from(">I", payload, 0)[0]
            raw = payload[8:]
            if type_code == 1:  # UTF-8
                try:
                    txt = raw.decode("utf-8").strip("\x00")
                    if txt:
                        found.append(txt)
                except Exception:
                    pass
            elif type_code in (0, 23):
                try:
                    txt = raw.decode("utf-8", errors="replace").strip("\x00")
                    if txt and len(txt) < 200:
                        found.append(txt)
                except Exception:
                    pass
        off += bsize
    return found


def find_meta_structure(data: bytes) -> dict:
    """Locate moov/meta/keys/ilst and extract key names + ilst values."""
    report: dict = {"keys_entries": [], "ilst_items": [], "udta_boxes": []}
    boxes: list[dict] = []
    walk_boxes(data, 0, len(data), "", 0, boxes)

    for b in boxes:
        path = b["path"]
        off = b["offset"]
        size = b["size"]
        hdr = read_box_header(data, off)
        if hdr is None:
            continue
        _, typ, head = hdr
        if typ == b"keys":
            report["keys_entries"].extend(parse_keys_box(data, off + head, size - head))
        if typ == b"udta":
            report["udta_boxes"].append({"path": path, "offset": off, "size": size})
        if "/meta/ilst" in path or path.endswith("/ilst"):
            parent_name = path.split("/")[-2] if "/" in path else ""
            vals = parse_ilst_string(data, off + head, size - head)
            if vals:
                report["ilst_items"].append({"parent": path, "values": vals})

    # Also scan moov for free-form tag atoms (©too, ©swr, etc.)
    tag_atoms: list[dict] = []
    for b in boxes:
        off = b["offset"]
        size = b["size"]
        hdr = read_box_header(data, off)
        if hdr is None:
            continue
        _, typ, head = hdr
        if len(typ) == 4 and typ[0] == 0xA9:  # QuickTime copyright-style tags
            payload = data[off + head : off + size]
            if 0 < len(payload) < 512:
                try:
                    txt = payload.decode("utf-8", errors="replace").strip("\x00")
                    if txt:
                        tag_atoms.append(
                            {"path": b["path"], "tag": typ.hex(), "text": txt[:120]}
                        )
                except Exception:
                    pass
    report["quicktime_tag_atoms"] = tag_atoms
    report["box_paths_of_interest"] = sorted(
        {b["path"] for b in boxes if any(x in b["path"] for x in ("/moov", "udta", "meta", "keys", "ilst", "uuid"))}
    )
    return report


def ascii_string_hits(data: bytes) -> list[dict]:
    """Literal substring hits for provenance-related keys (not device inference)."""
    hits: list[dict] = []
    lower_data = data.lower()
    needles = [
        b"com.android.manufacturer",
        b"com.android.model",
        b"com.android.version",
        b"infinix",
        b"manufacturer",
        b"android.model",
    ]
    for needle in needles:
        idx = 0
        while True:
            pos = lower_data.find(needle, idx)
            if pos == -1:
                break
            # context window, redact if sensitive
            start = max(0, pos - 16)
            end = min(len(data), pos + len(needle) + 48)
            chunk = data[start:end]
            try:
                ctx = chunk.decode("utf-8", errors="replace")
            except Exception:
                ctx = repr(chunk)
            if SENSITIVE_VALUE_RE.search(ctx):
                ctx = "<redacted: possible sensitive payload>"
            hits.append({"needle": needle.decode("ascii", errors="replace"), "offset": pos, "context": ctx[:100]})
            idx = pos + 1
            if len(hits) > 50:
                break
    return hits


def main() -> None:
    path = VIDEO
    if len(sys.argv) > 1:
        path = Path(sys.argv[1])
    if not path.is_file():
        print(json.dumps({"error": "file missing", "path": str(path)}))
        return
    data = path.read_bytes()
    boxes: list[dict] = []
    walk_boxes(data, 0, len(data), "", 0, boxes)
    top_level = [b for b in boxes if b["path"].count("/") == 1]
    meta = find_meta_structure(data)
    strings = ascii_string_hits(data)

    # Manufacturer/model literal check in keys/ilst
    mfg_model_literals: list[str] = []
    for idx, key in meta.get("keys_entries", []):
        kl = key.lower()
        if "manufacturer" in kl or "model" in kl or kl.endswith(":make"):
            mfg_model_literals.append(f"keys[{idx}]={key}")
    for item in meta.get("ilst_items", []):
        for v in item.get("values", []):
            vl = v.lower()
            if "infinix" in vl or "manufacturer" in vl:
                mfg_model_literals.append(f"ilst:{v[:80]}")

    out = {
        "file": str(path),
        "size_bytes": len(data),
        "top_level_boxes": top_level,
        "total_boxes_enumerated": len(boxes),
        "meta_structure": meta,
        "ascii_provenance_substrings": strings,
        "literal_manufacturer_model_in_keys_or_ilst": mfg_model_literals,
    }
    print(json.dumps(out, indent=2, default=str))


if __name__ == "__main__":
    main()
