#!/usr/bin/env python3
"""Read-only: ffprobe + classifier vs stored DB row for media 1000442511."""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

BACKEND = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BACKEND))

from app.env_bootstrap import bootstrap_environment

bootstrap_environment()

from app.services.camera_provenance import classify_video_container_provenance
from sqlalchemy import create_engine, text
from app.config import settings

VIDEO = BACKEND / "uploads" / "videos" / "1f9281ef0e0a4f05bccd19d54e3279aa.mp4"
MEDIA_ID = 265


def ffprobe_json(path: Path) -> dict:
    cmd = [
        "ffprobe",
        "-v",
        "quiet",
        "-print_format",
        "json",
        "-show_format",
        "-show_streams",
        str(path),
    ]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
    if r.returncode != 0:
        raise RuntimeError(r.stderr[:500])
    return json.loads(r.stdout)


def exiftool_json(path: Path) -> dict | None:
    import shutil

    if not shutil.which("exiftool"):
        return None
    cmd = ["exiftool", "-j", "-G", "-a", "-u", str(path)]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
    if r.returncode != 0:
        return {"error": r.stderr[:500]}
    data = json.loads(r.stdout)
    return data[0] if data else {}


def redact_gps(meta: dict) -> dict:
    out = {}
    for k, v in meta.items():
        kl = k.lower()
        if any(x in kl for x in ("gps", "location", "latitude", "longitude")):
            out[k] = "<redacted>"
        elif "serial" in kl or "uuid" in kl and "brand" not in kl:
            out[k] = "<redacted>"
        else:
            out[k] = v
    return out


def main() -> None:
    if not VIDEO.is_file():
        print(json.dumps({"error": "video file missing", "path": str(VIDEO)}))
        return

    content = VIDEO.read_bytes()
    probe = ffprobe_json(VIDEO)
    fmt_tags = probe.get("format", {}).get("tags") or {}
    stream_tag_keys: list[dict] = []
    for i, st in enumerate(probe.get("streams") or []):
        tags = st.get("tags") or {}
        stream_tag_keys.append(
            {
                "index": i,
                "codec": st.get("codec_name"),
                "tag_keys": sorted(tags.keys()),
                "android_keys": {
                    k: tags[k]
                    for k in tags
                    if "android" in k.lower() or k.lower() in ("make", "model", "manufacturer")
                },
            }
        )

    classified = classify_video_container_provenance(content, ext=".mp4", file_name="1000442511")
    exif = exiftool_json(VIDEO)

    engine = create_engine(settings.database_url)
    with engine.connect() as c:
        row = c.execute(
            text(
                "SELECT exif_metadata FROM ai_detection_results WHERE media_id = :id"
            ),
            {"id": MEDIA_ID},
        ).fetchone()

    stored = row[0] if row else None
    if isinstance(stored, str):
        stored = json.loads(stored)

    report = {
        "media_id": MEDIA_ID,
        "file_name": "1000442511",
        "local_path": str(VIDEO),
        "size_bytes": len(content),
        "ffprobe_format_tag_keys": sorted(fmt_tags.keys()),
        "ffprobe_format_android_related": {
            k: fmt_tags[k]
            for k in fmt_tags
            if "android" in k.lower()
            or k.lower() in ("make", "model", "manufacturer", "creation_time")
        },
        "ffprobe_streams": stream_tag_keys,
        "classifier_now": classified.to_dict(),
        "stored_exif_metadata_summary": {
            "camera_provenance_strength": (stored or {}).get("camera_provenance_strength"),
            "provenance_policy_outcome": (stored or {}).get("provenance_policy_outcome"),
            "summary": (stored or {}).get("summary"),
            "fields": (stored or {}).get("fields"),
        },
        "exiftool": redact_gps(exif) if isinstance(exif, dict) else exif,
    }
    print(json.dumps(report, indent=2, default=str))


if __name__ == "__main__":
    main()
