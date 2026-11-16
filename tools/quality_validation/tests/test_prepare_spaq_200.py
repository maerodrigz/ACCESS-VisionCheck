from __future__ import annotations

import csv
import io
import sys
import zipfile
from pathlib import Path

import pytest
from PIL import Image

_TOOLKIT = Path(__file__).resolve().parents[1]
if str(_TOOLKIT) not in sys.path:
    sys.path.insert(0, str(_TOOLKIT))

from prepare_spaq_200 import IntegrityError, extract_zip, prepare  # noqa: E402


def _tiny_jpeg(path: Path) -> None:
    Image.new("RGB", (16, 16), color=(40, 80, 120)).save(path, format="JPEG")


def _write_part(zip_path: Path, name: str, stratum: int, label: str) -> None:
    tmp = zip_path.parent / f"_img_{name}"
    _tiny_jpeg(tmp)
    buf = io.StringIO()
    writer = csv.DictWriter(
        buf,
        fieldnames=[
            "media_id",
            "source_media_key",
            "mos_quality_raw",
            "attr_brightness_raw",
            "attr_colorfulness_raw",
            "attr_contrast_raw",
            "attr_noisiness_raw",
            "attr_sharpness_raw",
            "stratum_id",
            "stratum_label",
            "selection_seed",
            "n_per_stratum",
            "image_on_disk",
        ],
    )
    writer.writeheader()
    writer.writerow(
        {
            "media_id": f"spaq_{Path(name).stem}",
            "source_media_key": name,
            "mos_quality_raw": "20",
            "attr_brightness_raw": "30",
            "attr_colorfulness_raw": "40",
            "attr_contrast_raw": "50",
            "attr_noisiness_raw": "10",
            "attr_sharpness_raw": "60",
            "stratum_id": str(stratum),
            "stratum_label": label,
            "selection_seed": "20261107",
            "n_per_stratum": "1",
            "image_on_disk": "False",
        }
    )
    with zipfile.ZipFile(zip_path, "w") as zf:
        zf.writestr("human_ratings.csv", buf.getvalue())
        zf.write(tmp, arcname=f"images/{name}")
    tmp.unlink()


def test_zip_slip_rejected(tmp_path: Path) -> None:
    zpath = tmp_path / "bad.zip"
    with zipfile.ZipFile(zpath, "w") as zf:
        zf.writestr("../escape.jpg", b"not-a-jpeg")
    with pytest.raises(IntegrityError, match="zip-slip"):
        extract_zip(zpath, tmp_path / "out")


def test_prepare_two_parts(tmp_path: Path) -> None:
    _write_part(tmp_path / "SPAQ_Part_1.zip", "00001.jpg", 1, "Q1_very_low")
    _write_part(tmp_path / "SPAQ_Part_2.zip", "00002.jpg", 2, "Q2_low")
    payload = prepare(tmp_path, n_parts=2, expected_per_part=1, expected_total=2)
    assert payload["status"] == "ok"
    assert payload["n_readable_jpegs"] == 2
    merged = tmp_path / "metadata" / "human_ratings_200.csv"
    rows = list(csv.DictReader(merged.open(encoding="utf-8")))
    assert [r["source_media_key"] for r in rows] == ["00001.jpg", "00002.jpg"]
    assert rows[0]["image_on_disk"] == "False"
    assert (tmp_path / "images" / "00001.jpg").is_file()
    orig = (tmp_path / "metadata" / "parts" / "SPAQ_Part_1_human_ratings.csv").read_text(encoding="utf-8")
    assert "00001.jpg" in orig
