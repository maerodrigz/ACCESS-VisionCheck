"""Focused tests for Blocking/Ringing Wave A/B (no inference, no SPAQ-200 images)."""

from __future__ import annotations

import hashlib
import sys
from pathlib import Path

import pytest

_TOOLKIT = Path(__file__).resolve().parents[1]
if str(_TOOLKIT) not in sys.path:
    sys.path.insert(0, str(_TOOLKIT))

from blocking_ringing_audit import analyze_phase8_rows  # noqa: E402
from blocking_ringing_livec_eval import (  # noqa: E402
    ARTIFACTS,
    BC_KEYS_JSON,
    DEFAULT_OUT,
    N_PER_QUINTILE,
    N_SELECT,
    SCORER_PATHS,
    SELECTION_SEED,
    abort_if_existing,
    hash_paths,
    load_bc_selected_keys,
)
from brightness_contrast_livec_eval import assign_strata, select_livec200  # noqa: E402


def _synthetic_test_rows(n: int = 250) -> list[dict]:
    rows = []
    for i in range(n):
        mos = 5.0 + (90.0 * i / max(n - 1, 1))
        rows.append(
            {
                "index": i + 7,
                "source_media_key": f"{i:04d}.jpg",
                "stem": f"{i:04d}",
                "mos_quality_raw": mos,
                "split": "test",
                "image_path": f"/tmp/{i:04d}.jpg",
            }
        )
    return rows


def test_seed_matches_prior_livec_sample() -> None:
    assert SELECTION_SEED == 20261108
    assert N_SELECT == 200
    assert N_PER_QUINTILE == 40
    from brightness_contrast_livec_eval import SELECTION_SEED as BC_SEED
    from blur_quality_livec_eval import SELECTION_SEED as BLUR_SEED

    assert SELECTION_SEED == BC_SEED == BLUR_SEED


def test_select_is_reproducible() -> None:
    rows = _synthetic_test_rows(250)
    assign_strata(rows)
    a = select_livec200(rows, seed=SELECTION_SEED, n_per=N_PER_QUINTILE)
    b = select_livec200(rows, seed=SELECTION_SEED, n_per=N_PER_QUINTILE)
    assert [r["source_media_key"] for r in a] == [r["source_media_key"] for r in b]
    assert len(a) == 200


def test_abort_if_output_exists(tmp_path: Path) -> None:
    abort_if_existing(tmp_path)
    (tmp_path / ARTIFACTS[0]).write_text("x", encoding="utf-8")
    with pytest.raises(SystemExit, match="refusing to overwrite"):
        abort_if_existing(tmp_path)


def test_default_out_dir_is_approved_folder() -> None:
    assert DEFAULT_OUT.name == "run_block_ring_livec_001"
    assert DEFAULT_OUT.name != "run_blur_livec_001"


def test_hash_paths_stable(tmp_path: Path) -> None:
    p = tmp_path / "a.py"
    p.write_bytes(b"hello")
    first = hash_paths([p])
    assert first[str(p)] == hashlib.sha256(b"hello").hexdigest()
    assert first == hash_paths([p])


def test_scorer_paths_are_backend_only() -> None:
    for path in SCORER_PATHS:
        assert "access_backend" in str(path)
        assert "quality_validation" not in str(path)


def test_phase8_synthetic_jpeg_integers_flat_classic_tracks() -> None:
    rows = []
    for q, sev in ((100, 0.0), (70, 30.0), (40, 60.0), (25, 75.0), (15, 85.0), (8, 92.0)):
        rows.append(
            {
                "media_id": "CTRL-001",
                "family": "original" if sev == 0 else "jpeg",
                "is_original": sev == 0,
                "severity": sev,
                "enet_int_blocking_artifacts": 3,
                "enet_raw_blocking_artifacts": 0.40 + sev / 400.0,
                "opencv_int_blocking_artifacts": 3,
                "opencv_raw_blocking_artifacts": 0.10 + sev / 200.0,
                "classic_blocking_boundary_ratio": 1.0 + sev / 80.0,
                "classic_blocking_flat_frac": 0.10 + sev / 200.0,
                "enet_int_sharpness": 3,
                "enet_raw_sharpness": 0.5,
                "enet_int_noise": 4,
                "enet_raw_noise": 0.4,
                "enet_overall": 3.5,
                "enet_int_ringing_artifacts": 3,
                "enet_raw_ringing_artifacts": 0.5,
                "opencv_int_ringing_artifacts": 3,
                "opencv_raw_ringing_artifacts": 0.1,
                "classic_ringing_edge_lap": 10.0,
            }
        )
    for amount in (0.0, 1.4, 1.8, 2.2, 2.8, 3.5):
        rows.append(
            {
                "media_id": "CTRL-001",
                "family": "original" if amount == 0 else "ringing",
                "is_original": amount == 0,
                "severity": amount,
                "enet_int_ringing_artifacts": 3,
                "enet_raw_ringing_artifacts": 0.40 + 0.08 * amount,
                "opencv_int_ringing_artifacts": 3,
                "opencv_raw_ringing_artifacts": 0.05 + 0.02 * amount,
                "classic_ringing_edge_lap": 8.0 + 6.0 * amount,
                "enet_int_sharpness": 3 if amount < 3 else 4,
                "enet_raw_sharpness": 0.40 + 0.05 * amount,
                "enet_int_noise": 4,
                "enet_raw_noise": 0.3 + 0.02 * amount,
                "enet_overall": 3.4,
                "enet_int_blocking_artifacts": 3,
                "enet_raw_blocking_artifacts": 0.5,
                "opencv_int_blocking_artifacts": 3,
                "opencv_raw_blocking_artifacts": 0.2,
                "classic_blocking_boundary_ratio": 1.1,
                "classic_blocking_flat_frac": 0.2,
            }
        )
    out = analyze_phase8_rows(rows)
    assert out["jpeg"]["severity_sensitivity"]["enet_int_blocking"]["n_images_defined"] == 0
    assert out["jpeg"]["severity_sensitivity"]["classic_boundary_ratio"]["n_images_defined"] == 1
    assert out["ringing"]["severity_sensitivity"]["enet_int_ringing"]["n_images_defined"] == 0
    assert out["ringing"]["severity_sensitivity"]["enet_raw_ringing"]["n_images_defined"] == 1


def test_bc_keys_loader_requires_seed(tmp_path: Path) -> None:
    path = tmp_path / "bc.json"
    path.write_text('{"selection": {"seed": 1, "selected_keys": ["a"]}}', encoding="utf-8")
    with pytest.raises(SystemExit, match="seed"):
        load_bc_selected_keys(path)


def test_bc_livec_json_exists_for_key_lock() -> None:
    assert BC_KEYS_JSON.is_file()
