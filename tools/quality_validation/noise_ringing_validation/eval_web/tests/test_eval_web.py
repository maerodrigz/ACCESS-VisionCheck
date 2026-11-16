"""Lightweight tests for the offline Noise/Ringing evaluation webpage."""

from __future__ import annotations

import csv
import io
import re
import sys
from pathlib import Path

EVAL_WEB = Path(__file__).resolve().parents[1]
NR_ROOT = EVAL_WEB.parent
IMAGES = NR_ROOT / "images"
REPO = NR_ROOT.parents[2]
sys.path[:0] = [str(REPO)]

IMAGE_IDS = [f"NR{i:03d}" for i in range(1, 16)]
CSV_HEADER = [
    "media_id",
    "rater_id",
    "media_type",
    "noise",
    "ringing_artifacts",
    "sharpness",
    "blur",
    "brightness",
    "contrast",
    "blocking_artifacts",
    "flickering",
    "motion_stability",
    "overall_visual_quality",
    "notes",
]


def test_all_fifteen_images_exist_and_open():
    import cv2
    import numpy as np

    for mid in IMAGE_IDS:
        path = IMAGES / f"{mid}.jpg"
        assert path.is_file(), f"missing {path}"
        data = path.read_bytes()
        img = cv2.imdecode(np.frombuffer(data, dtype=np.uint8), cv2.IMREAD_COLOR)
        assert img is not None, f"cannot decode {mid}"


def test_webpage_files_present():
    assert (EVAL_WEB / "index.html").is_file()
    assert (EVAL_WEB / "app.js").is_file()
    assert (EVAL_WEB / "styles.css").is_file()
    assert (EVAL_WEB / "README.md").is_file()


def test_html_has_required_ui_and_hides_facilitator_info():
    html = (EVAL_WEB / "index.html").read_text(encoding="utf-8")
    js = (EVAL_WEB / "app.js").read_text(encoding="utf-8")
    blob = html + "\n" + js

    for token in ("R1", "R2", "R3", "Noise", "Ringing", "Export CSV", "localStorage"):
        assert token in blob

    # Rubric phrases (exact definitions embedded)
    assert "Clean tones. No distracting grain or color splotches at 100%." in blob
    assert "Clean edges; no light/dark halo at 100%." in blob

    forbidden = [
        "collection_notes",
        "noise_stratum",
        "ringing_stratum",
        "target_bucket",
        "machine_noise",
        "efficientnet",
        "soft_score",
        "EXPECTED artifact",
    ]
    lower = blob.lower()
    for bad in forbidden:
        assert bad.lower() not in lower, f"facilitator/machine leak: {bad}"


def test_csv_export_matches_template_shape():
    """Simulate complete ratings and verify CSV columns/rows (no fabricated blanks)."""
    # Minimal reimplementation mirroring app.js buildCsv contract
    ratings = {
        mid: {"noise": ((i % 5) + 1), "ringing_artifacts": ((i * 2) % 5) + 1, "notes": ""}
        for i, mid in enumerate(IMAGE_IDS)
    }
    lines = [",".join(CSV_HEADER)]
    for mid in IMAGE_IDS:
        row = ratings[mid]
        lines.append(
            ",".join(
                [
                    mid,
                    "R1",
                    "photo",
                    str(row["noise"]),
                    str(row["ringing_artifacts"]),
                    "N/A",
                    "N/A",
                    "N/A",
                    "N/A",
                    "N/A",
                    "N/A",
                    "N/A",
                    "N/A",
                    "",
                ]
            )
        )
    text = "\r\n".join(lines) + "\r\n"
    reader = csv.DictReader(io.StringIO(text))
    assert reader.fieldnames == CSV_HEADER
    rows = list(reader)
    assert len(rows) == 15
    assert [r["media_id"] for r in rows] == IMAGE_IDS
    assert all(r["rater_id"] == "R1" for r in rows)
    assert all(r["noise"] in {"1", "2", "3", "4", "5"} for r in rows)
    assert all(r["ringing_artifacts"] in {"1", "2", "3", "4", "5"} for r in rows)
    # Template compatibility: unused criteria are N/A, not invented scores
    assert all(r["sharpness"] == "N/A" for r in rows)

    # Existing blank template header must match
    template = (NR_ROOT / "ratings" / "R1_noise_ringing_ratings.csv").read_text(encoding="utf-8")
    template_header = template.splitlines()[0].strip()
    assert template_header == ",".join(CSV_HEADER)


def test_app_js_keeps_sessions_namespaced():
    js = (EVAL_WEB / "app.js").read_text(encoding="utf-8")
    assert "access_nr_eval_v1_" in js
    assert "STORAGE_PREFIX + raterId" in js or 'STORAGE_PREFIX + raterId' in js
    # Export gated on completeness
    assert "Export locked until all 15" in js or "all 15 images" in js


def test_no_external_cdn_dependencies():
    html = (EVAL_WEB / "index.html").read_text(encoding="utf-8")
    assert "cdn." not in html.lower()
    assert "unpkg" not in html.lower()
    assert "googleapis" not in html.lower()
    assert re.search(r'href="styles\.css"', html)
    assert re.search(r'src="app\.js"', html)
