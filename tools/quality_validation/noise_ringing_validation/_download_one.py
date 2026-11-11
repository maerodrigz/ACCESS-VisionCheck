#!/usr/bin/env python3
"""Download a single planned Commons slot (NR0xx)."""

from __future__ import annotations

import sys
import time

from collect_open_license_images import PLANNED, batch_imageinfo, download, ext_for, sha256_bytes, IMAGES


def main() -> int:
    mid = sys.argv[1]
    item = next(x for x in PLANNED if x[0] == mid)
    _, title, *_ = item
    print("cooldown 20s…", flush=True)
    time.sleep(20)
    meta = batch_imageinfo([title]).get(title)
    if not meta:
        print("no metadata")
        return 1
    candidates = []
    if meta.get("thumburl"):
        candidates.append(("thumb", meta["thumburl"], meta.get("thumbwidth"), meta.get("thumbheight")))
    if meta.get("url"):
        candidates.append(("orig", meta["url"], meta.get("width"), meta.get("height")))
    ext = ext_for(str(meta["mime"]), str(meta.get("thumburl") or meta.get("url")))
    dest = IMAGES / f"{mid}{ext}"
    for label, url, w, h in candidates:
        print(f"try {label} {url[:80]}…", flush=True)
        try:
            data = download(str(url), dest)
            print(f"OK {dest.name} {w}x{h} sha={sha256_bytes(data)[:12]} bytes={len(data)}")
            return 0
        except Exception as exc:  # noqa: BLE001
            print("FAIL", exc)
            time.sleep(15)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
