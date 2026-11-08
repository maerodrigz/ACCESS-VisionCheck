"""Focused tests for Blur Wave A/B (no inference, no SPAQ-200 images)."""

from __future__ import annotations

import hashlib
import sys
from pathlib import Path

import pytest

_TOOLKIT = Path(__file__).resolve().parents[1]
if str(_TOOLKIT) not in sys.path:
    sys.path.insert(0, str(_TOOLKIT))

from blur_quality_audit import analyze_phase8_rows  # noqa: E402
from blur_quality_livec_eval import (  # noqa: E402
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


def test_seed_matches_brightness_contrast_sample() -> None:
    assert SELECTION_SEED == 20261108
    assert N_SELECT == 200
    assert N_PER_QUINTILE == 40
    from brightness_contrast_livec_eval import SELECTION_SEED as BC_SEED
    from brightness_contrast_livec_eval import N_SELECT as BC_N

    assert SELECTION_SEED == BC_SEED
    assert N_SELECT == BC_N


def test_select_reuses_bc_function_and_is_reproducible() -> None:
    rows = _synthetic_test_rows(250)
    assign_strata(rows)
    a = select_livec200(rows, seed=SELECTION_SEED, n_per=N_PER_QUINTILE)
    b = select_livec200(rows, seed=SELECTION_SEED, n_per=N_PER_QUINTILE)
    assert len(a) == 200
    assert [r["source_media_key"] for r in a] == [r["source_media_key"] for r in b]


def test_abort_if_output_exists(tmp_path: Path) -> None:
    abort_if_existing(tmp_path)
    (tmp_path / ARTIFACTS[0]).write_text("x", encoding="utf-8")
    with pytest.raises(SystemExit, match="refusing to overwrite"):
        abort_if_existing(tmp_path)


def test_default_out_dir_is_approved_folder() -> None:
    assert DEFAULT_OUT.name == "run_blur_livec_001"
    assert "livec" in str(DEFAULT_OUT)


def test_hash_paths_stable(tmp_path: Path) -> None:
    p = tmp_path / "a.py"
    p.write_bytes(b"hello")
    first = hash_paths([p])
    second = hash_paths([p])
    assert first[str(p)] == hashlib.sha256(b"hello").hexdigest()
    assert first == second


def test_scorer_paths_are_backend_only() -> None:
    for path in SCORER_PATHS:
        assert "access_backend" in str(path)
        assert "quality_validation" not in str(path)


def test_phase8_synthetic_detects_integer_saturation_and_opencv_inverse() -> None:
    rows = []
    for sigma in (0.0, 0.5, 1.0, 2.0, 4.0, 8.0):
        sharp = max(0.0, 1.0 - sigma / 8.0)
        rows.append(
            {
                "media_id": "CTRL-001",
                "family": "original" if sigma == 0 else "gaussian_blur",
                "is_original": sigma == 0,
                "severity": sigma,
                "enet_raw_blur": 0.40 + 0.06 * sigma,
                "enet_int_blur": 3,
                "enet_raw_sharpness": 0.60 - 0.05 * sigma,
                "enet_int_sharpness": 3,
                "opencv_raw_sharpness": sharp,
                "opencv_raw_blur": 1.0 - sharp,
                "opencv_int_blur": 3 if sigma < 4 else 2,
                "opencv_int_sharpness": 3 if sigma < 4 else 2,
                "classic_blur_inv_laplacian": 0.2 + 0.08 * sigma,
                "classic_sharpness_laplacian_var": 400.0 / (1.0 + sigma),
            }
        )
    out = analyze_phase8_rows(rows)
    assert out["gaussian_severity_sensitivity"]["enet_int_blur"]["n_images_defined"] == 0
    assert out["gaussian_severity_sensitivity"]["enet_raw_blur"]["n_images_defined"] == 1
    assert out["redundancy"]["opencv_mean_abs_s_plus_b_minus_1"] == 0.0


def test_bc_keys_loader_requires_seed(tmp_path: Path) -> None:
    path = tmp_path / "bc.json"
    path.write_text('{"selection": {"seed": 1, "selected_keys": ["a"]}}', encoding="utf-8")
    with pytest.raises(SystemExit, match="seed"):
        load_bc_selected_keys(path)


def test_bc_livec_json_exists_for_key_lock() -> None:
    assert BC_KEYS_JSON.is_file()
