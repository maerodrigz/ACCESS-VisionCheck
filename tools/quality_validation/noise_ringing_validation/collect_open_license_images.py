#!/usr/bin/env python3
"""Download openly licensed Wikimedia Commons photographs for NR001–NR015.

Research-only. Provenance from Commons API. Failed slots stay empty.
Does not score images, retune detectors, or touch production.
"""

from __future__ import annotations

import csv
import hashlib
import json
import re
import ssl
import time
import urllib.parse
import urllib.request
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent
IMAGES = ROOT / "images"
FACILITATOR = ROOT / "facilitator"
UA = "ACCESSVisionCheck-NRValidation/1.0 (research; local collection; contact: local-dev)"

# Verified Commons titles (batch-probed). Buckets are facilitator planning hints only.
PLANNED = [
    ("NR001", "File:Golden Gate Bridge from Battery Spencer.jpg", "clean", "daylight-bridge",
     "Daylight landmark; collection target=clean. Not a human label."),
    ("NR002", "File:Yosemite Valley from Tunnel View.jpg", "clean", "daylight-landscape",
     "Daylight landscape; collection target=clean. Not a human label."),
    ("NR003", "File:Statue of Liberty, NY.jpg", "clean", "daylight-monument",
     "Daylight monument; collection target=clean. Not a human label."),
    ("NR004", "File:Airport night ISO 1600.jpg", "low_light_noise", "night-airport-iso1600",
     "Author describes unprocessed ISO 1600 night shot; possible grain. Not a label."),
    ("NR005", "File:A night street scene in NYC.jpg", "low_light_noise", "night-street-iso3200",
     "EXIF ISO 3200 night street; possible luminance noise. Not a label."),
    ("NR006", "File:Chinatown (102204197).jpeg", "low_light_noise", "night-street-iso4000",
     "EXIF ISO 4000 night street; possible grain. Not a label."),
    ("NR007", "File:Night Photography in NYC - Downtown Manhattan.JPG", "moderate_strong_noise",
     "night-skyline-iso3200", "EXIF ISO 3200 night skyline; may show stronger noise. Not a label."),
    ("NR008", "File:Late Night Sunset (122829211).jpeg", "moderate_strong_noise",
     "night-landscape-iso1250", "Late-night landscape ISO 1250; shadows may show noise. Not a label."),
    ("NR009", "File:Milky Way Galaxy.jpg", "moderate_strong_noise", "night-sky",
     "Night-sky style image; shadows often noisy. Not a label."),
    ("NR010", "File:Times Square (New York City).jpg", "possible_ringing", "neon-signage-edges",
     "High-contrast neon/signage; inspect for halos (may be absent). Not a label."),
    ("NR011", "File:Tokyo Tower at night.jpg", "possible_ringing", "night-tower-edges",
     "Lit tower edges against dark sky; possible fringe risk. Not a label."),
    ("NR012", "File:London Eye at night 2.jpg", "possible_ringing", "night-structure-edges",
     "Night structure with bright edges; possible halo risk. Not a label."),
    ("NR013", "File:Quality comparison jpg vs saveforweb.jpg", "mixed_ambiguous",
     "jpeg-quality-comparison", "JPEG quality comparison; compression vs noise ambiguity. Not a label."),
    ("NR014", "File:Bokeh.jpg", "mixed_ambiguous", "bokeh-texture",
     "Bokeh/texture confuser for noise judgment. Not a label."),
    ("NR015", "File:Brandenburg Gate at night.jpg", "mixed_ambiguous", "night-architecture-edges",
     "Night architecture with hard edges; mixed noise/edge ambiguity. Not a label."),
]

BUCKET_HINTS = {
    "clean": ("clean", "clean"),
    "low_light_noise": ("mild", "clean"),
    "moderate_strong_noise": ("moderate", "clean"),
    "possible_ringing": ("clean", "mild"),
    "mixed_ambiguous": ("mild", "mild"),
}


def _open(req: urllib.request.Request, timeout: int = 90):
    return urllib.request.urlopen(req, timeout=timeout, context=ssl.create_default_context())


def strip_html(text: str) -> str:
    text = re.sub(r"<[^>]+>", " ", text or "")
    return re.sub(r"\s+", " ", text).strip()


def batch_imageinfo(titles: list[str]) -> dict[str, dict]:
    params = {
        "action": "query",
        "titles": "|".join(titles),
        "prop": "imageinfo",
        "iiprop": "url|size|mime|extmetadata|thumburl|thumbwidth|thumbheight",
        "iiurlwidth": "2560",
        "format": "json",
        "redirects": "1",
    }
    url = "https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with _open(req) as resp:
        data = json.loads(resp.read().decode())

    # Map requested title -> final title via redirects/normalized
    alias: dict[str, str] = {}
    for n in data.get("query", {}).get("normalized", []) or []:
        alias[n["from"]] = n["to"]
    for r in data.get("query", {}).get("redirects", []) or []:
        alias[r["from"]] = r["to"]

    by_title: dict[str, dict] = {}
    for page in data.get("query", {}).get("pages", {}).values():
        title = page.get("title")
        if not title or "missing" in page or "imageinfo" not in page:
            continue
        info = page["imageinfo"][0]
        meta = info.get("extmetadata") or {}

        def mv(key: str) -> str:
            return str((meta.get(key) or {}).get("value") or "").strip()

        by_title[title] = {
            "resolved_title": title,
            "url": info.get("url"),
            "thumburl": info.get("thumburl"),
            "thumbwidth": info.get("thumbwidth"),
            "thumbheight": info.get("thumbheight"),
            "width": info.get("width"),
            "height": info.get("height"),
            "mime": info.get("mime"),
            "artist_html": mv("Artist"),
            "license_short": mv("LicenseShortName"),
            "license_url": mv("LicenseUrl"),
            "commons_page": "https://commons.wikimedia.org/wiki/"
            + urllib.parse.quote(title.replace(" ", "_")),
        }

    # Resolve each requested title through alias chain
    out: dict[str, dict] = {}
    for req_title in titles:
        t = req_title
        seen = set()
        while t in alias and t not in seen:
            seen.add(t)
            t = alias[t]
        if t in by_title:
            out[req_title] = by_title[t]
    return out


def download(url: str, dest: Path) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with _open(req, timeout=180) as resp:
        data = resp.read()
    dest.write_bytes(data)
    return data


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def ext_for(mime: str, url: str) -> str:
    if mime == "image/jpeg":
        return ".jpg"
    if mime == "image/png":
        return ".png"
    if mime == "image/webp":
        return ".webp"
    suffix = Path(urllib.parse.urlparse(url).path).suffix.lower()
    if suffix in {".jpg", ".jpeg", ".png", ".webp"}:
        return ".jpg" if suffix == ".jpeg" else suffix
    return ".jpg"


def write_csv(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if not rows:
        path.write_text("", encoding="utf-8")
        return
    fields: list[str] = []
    seen: set[str] = set()
    for row in rows:
        for key in row.keys():
            if key not in seen:
                seen.add(key)
                fields.append(key)
    with path.open("w", encoding="utf-8", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=fields, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)


def main() -> int:
    IMAGES.mkdir(parents=True, exist_ok=True)
    FACILITATOR.mkdir(parents=True, exist_ok=True)
    today = date.today().isoformat()

    titles = [t for _, t, *_ in PLANNED]
    print("Batch metadata fetch…", flush=True)
    try:
        meta_map = batch_imageinfo(titles)
    except Exception as exc:  # noqa: BLE001
        print(f"Batch metadata FAILED: {exc}", flush=True)
        meta_map = {}

    rows: list[dict] = []
    notes: list[dict] = []
    failures: list[dict] = []

    # Resume support: keep already-collected rows from existing manifest when files still present.
    existing_rows = []
    if (ROOT / "noise_ringing_image_manifest.csv").is_file():
        with (ROOT / "noise_ringing_image_manifest.csv").open(encoding="utf-8", newline="") as fh:
            existing_rows = list(csv.DictReader(fh))
    existing_by_id = {
        r["media_id"]: r
        for r in existing_rows
        if r.get("media_id") and (ROOT / r.get("relative_path", "")).is_file()
    }

    def on_disk(media_id: str) -> Path | None:
        for ext in (".jpg", ".jpeg", ".png", ".webp"):
            p = IMAGES / f"{media_id}{ext}"
            if p.is_file() and p.stat().st_size > 0:
                return p
        return None

    for media_id, title, bucket, content_tag, note in PLANNED:
        noise_hint, ring_hint = BUCKET_HINTS[bucket]
        if media_id in existing_by_id:
            row = dict(existing_by_id[media_id])
            rows.append(row)
            notes.append(
                {
                    "media_id": media_id,
                    "target_bucket": bucket,
                    "noise_stratum_hint": noise_hint,
                    "ringing_stratum_hint": ring_hint,
                    "collection_note": note,
                    "rater_visible": "no",
                }
            )
            print(f"[{media_id}] keep existing {row.get('relative_path')}", flush=True)
            continue

        disk_path = on_disk(media_id)
        info = meta_map.get(title)
        if disk_path is not None and info:
            data = disk_path.read_bytes()
            digest = sha256_bytes(data)
            photographer = strip_html(info["artist_html"]) or "see Commons page"
            license_status = info["license_short"] or "see Commons page"
            if info["license_url"]:
                license_status = f"{license_status} ({info['license_url']})"
            w, h = int(info.get("width") or 0), int(info.get("height") or 0)
            rows.append(
                {
                    "media_id": media_id,
                    "filename": disk_path.name,
                    "relative_path": f"images/{disk_path.name}",
                    "split": "validation",
                    "content_tag": content_tag,
                    "source_or_photographer": photographer,
                    "license_or_permission": license_status,
                    "commons_title": info["resolved_title"],
                    "commons_page": info["commons_page"],
                    "original_resolution": f"{w}x{h}" if w and h else "see_file",
                    "file_format": info["mime"],
                    "file_size_bytes": len(data),
                    "sha256": digest,
                    "collection_date": today,
                    "previously_used_in_eval_sets": "no_confirmed_disjoint_from_pilot_spaq_koniq_local_lists",
                    "download_variant": "adopted_from_disk",
                    "openable": "pending_checker",
                    "exclude_reason": "",
                }
            )
            notes.append(
                {
                    "media_id": media_id,
                    "target_bucket": bucket,
                    "noise_stratum_hint": noise_hint,
                    "ringing_stratum_hint": ring_hint,
                    "collection_note": note,
                    "rater_visible": "no",
                }
            )
            print(f"[{media_id}] adopt on-disk {disk_path.name} sha256={digest[:12]}…", flush=True)
            continue

        info = meta_map.get(title)
        if not info or not (info.get("url") or info.get("thumburl")):
            failures.append({"media_id": media_id, "commons_title": title, "error": "missing metadata/url"})
            print(f"[{media_id}] FAIL metadata: {title}", flush=True)
            continue

        ext = ext_for(str(info["mime"]), str(info.get("url") or info.get("thumburl")))
        filename = f"{media_id}{ext}"
        rel = f"images/{filename}"
        dest = IMAGES / filename

        # Prefer original; on 429 fall back to Commons 2560px thumb (still a real photo derivative).
        candidates = []
        if info.get("url"):
            candidates.append(("original", str(info["url"]), int(info["width"] or 0), int(info["height"] or 0)))
        if info.get("thumburl"):
            candidates.append(
                (
                    "thumb2560",
                    str(info["thumburl"]),
                    int(info.get("thumbwidth") or 0),
                    int(info.get("thumbheight") or 0),
                )
            )

        data = None
        used = None
        w = h = 0
        for label, url, cw, ch in candidates:
            print(f"[{media_id}] download ({label}) {info['resolved_title']} -> {rel}", flush=True)
            try:
                data = download(url, dest)
                used = label
                w, h = cw, ch
                break
            except Exception as exc:  # noqa: BLE001
                print(f"  FAIL {label}: {exc}", flush=True)
                time.sleep(5.0)

        if data is None:
            failures.append({"media_id": media_id, "commons_title": title, "error": "download failed all candidates"})
            # Do not delete a previously good on-disk file if a later retry fails.
            if dest.exists() and dest.stat().st_size == 0:
                dest.unlink(missing_ok=True)
            continue

        if min(w, h) < 400:
            # If metadata width missing for thumb, probe via bytes later in checker; keep if file large enough.
            if len(data) < 50_000:
                failures.append(
                    {
                        "media_id": media_id,
                        "commons_title": title,
                        "error": f"resolution/file too small ({w}x{h}, {len(data)} bytes)",
                    }
                )
                dest.unlink(missing_ok=True)
                print(f"  FAIL too small {w}x{h}", flush=True)
                continue

        digest = sha256_bytes(data)
        photographer = strip_html(info["artist_html"]) or "see Commons page"
        license_status = info["license_short"] or "see Commons page"
        if info["license_url"]:
            license_status = f"{license_status} ({info['license_url']})"
        res_note = f"{w}x{h}" if w and h else "see_file"
        if used == "thumb2560":
            res_note = f"{res_note}_thumb2560_derivative"

        rows.append(
            {
                "media_id": media_id,
                "filename": filename,
                "relative_path": rel,
                "split": "validation",
                "content_tag": content_tag,
                "source_or_photographer": photographer,
                "license_or_permission": license_status,
                "commons_title": info["resolved_title"],
                "commons_page": info["commons_page"],
                "original_resolution": res_note,
                "file_format": info["mime"],
                "file_size_bytes": len(data),
                "sha256": digest,
                "collection_date": today,
                "previously_used_in_eval_sets": "no_confirmed_disjoint_from_pilot_spaq_koniq_local_lists",
                "download_variant": used or "",
                "openable": "pending_checker",
                "exclude_reason": "",
            }
        )
        notes.append(
            {
                "media_id": media_id,
                "target_bucket": bucket,
                "noise_stratum_hint": noise_hint,
                "ringing_stratum_hint": ring_hint,
                "collection_note": note,
                "rater_visible": "no",
            }
        )
        print(f"  OK {res_note} sha256={digest[:12]}…", flush=True)
        time.sleep(4.0)

    manifest_path = ROOT / "noise_ringing_image_manifest.csv"
    notes_path = FACILITATOR / "collection_notes.csv"
    fail_path = FACILITATOR / "collection_failures.csv"
    status_path = ROOT / "COLLECTION_STATUS_REPORT.md"

    write_csv(manifest_path, rows)
    write_csv(notes_path, notes)
    write_csv(fail_path, failures)

    ready = len(rows)
    have = {r["media_id"] for r in rows}
    missing = [m for m, *_ in PLANNED if m not in have]
    lines = [
        "# Noise/Ringing preliminary collection status",
        "",
        f"- Collection date: {today}",
        "- Target slots: 15 (`NR001`–`NR015`)",
        f"- Images ready: **{ready}/15**",
        f"- Missing slots: {', '.join(missing) if missing else '(none)'}",
        f"- Manifest: `{manifest_path.name}`",
        "- Facilitator notes (hidden from raters): `facilitator/collection_notes.csv`",
        "- Failures: `facilitator/collection_failures.csv`",
        "",
        "## Important",
        "",
        "- Bucket/stratum hints are **collection planning only**, not ground-truth labels.",
        "- Do not show facilitator notes or machine scores to raters.",
        "- Do not claim detectors are validated from this collection alone.",
        "- Sources are Wikimedia Commons with license metadata from the API.",
        "",
    ]
    if failures:
        lines += ["## Failed acquisitions", ""]
        for f in failures:
            lines.append(f"- {f['media_id']}: {f['commons_title']} — {f['error']}")
        lines.append("")
    status_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Ready {ready}/15 -> {status_path}", flush=True)
    return 0 if ready else 1


if __name__ == "__main__":
    raise SystemExit(main())
