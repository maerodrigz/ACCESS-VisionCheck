#!/usr/bin/env python3
"""One-shot Commons batch metadata probe (research helper)."""

from __future__ import annotations

import json
import ssl
import urllib.parse
import urllib.request

UA = "ACCESSVisionCheck-NRValidation/1.0 (research; local collection)"
TITLES = [
    "File:Airport night ISO 1600.jpg",
    "File:A night street scene in NYC.jpg",
    "File:Chinatown (102204197).jpeg",
    "File:Night Photography in NYC - Downtown Manhattan.JPG",
    "File:Late Night Sunset (122829211).jpeg",
    "File:Golden Gate Bridge from Battery Spencer.jpg",
    "File:Brandenburg Gate at night.jpg",
    "File:JPEG compression artifact example.png",
    "File:Unsharp masking.jpg",
    "File:Oversharpening.jpg",
    "File:Bokeh.jpg",
    "File:Times Square New York City.jpg",
    "File:Empire State Building Midtown Manhattan New York City 2014 HDR.jpg",
    "File:Tokyo Tower at night.jpg",
    "File:Milky Way Galaxy.jpg",
    "File:Flower meadow.jpg",
    "File:Yosemite Valley from Tunnel View.jpg",
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
    for page in data.get("query", {}).get("pages", {}).values():
        title = page.get("title")
        if "missing" in page:
            print("MISSING", title)
            continue
        info = (page.get("imageinfo") or [{}])[0]
        meta = info.get("extmetadata") or {}
        lic = (meta.get("LicenseShortName") or {}).get("value")
        print(
            "OK",
            title,
            info.get("width"),
            "x",
            info.get("height"),
            lic,
            (info.get("url") or "")[:80],
        )


if __name__ == "__main__":
    main()
