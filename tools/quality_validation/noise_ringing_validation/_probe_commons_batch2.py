#!/usr/bin/env python3
from __future__ import annotations

import json
import ssl
import urllib.parse
import urllib.request

UA = "ACCESSVisionCheck-NRValidation/1.0 (research; local collection)"
TITLES = [
    "File:JPEG.jpg",
    "File:Jpeg.png",
    "File:Lossy-page1-250px-JPEG_example_JPG_RIP_025.jpg.jpg",
    "File:JPEG example.jpg",
    "File:Quality comparison jpg vs saveforweb.jpg",
    "File:Example of JPEG compression artifacts.jpg",
    "File:US Capitol west side.JPG",
    "File:Statue of Liberty, NY.jpg",
    "File:Eiffel Tower from Champ de Mars, Paris May 2014.jpg",
    "File:Sydney Opera House Closeup.jpg",
    "File:Mount Fuji Japan.jpg",
    "File:Red Square Moscow panorama.jpg",
    "File:London Eye at night 2.jpg",
    "File:Hong Kong night skyline.jpg",
    "File:Las Vegas Strip at night.jpg",
    "File:Neon signs in Shinjuku.jpg",
    "File:Times Square (New York City).jpg",
    "File:Broadway Times Square New York City.jpg",
    "File:Unsharp mask.jpg",
    "File:Acutance.jpg",
]


def main() -> None:
    params = {
        "action": "query",
        "titles": "|".join(TITLES),
        "prop": "imageinfo",
        "iiprop": "url|size|mime|extmetadata",
        "format": "json",
        "redirects": "1",
    }
    url = "https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    ctx = ssl.create_default_context()
    with urllib.request.urlopen(req, timeout=90, context=ctx) as resp:
        data = json.loads(resp.read().decode())
    for page in sorted(data.get("query", {}).get("pages", {}).values(), key=lambda p: p.get("title") or ""):
        title = page.get("title")
        if "missing" in page:
            print("MISSING", title)
            continue
        info = (page.get("imageinfo") or [{}])[0]
        meta = info.get("extmetadata") or {}
        lic = (meta.get("LicenseShortName") or {}).get("value")
        print("OK", title, f"{info.get('width')}x{info.get('height')}", lic)


if __name__ == "__main__":
    main()
