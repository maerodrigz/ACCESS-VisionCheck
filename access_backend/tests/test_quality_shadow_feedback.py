"""Phase 3 research-only hybrid feedback generator tests."""

from __future__ import annotations

import json
from typing import Any

import pytest

from app.services.quality_shadow.feedback_generator import generate_hybrid_feedback
from app.services.quality_shadow.feedback_rules import (
    Q_MILD,
    Q_MODERATE,
    Q_SEVERE,
    band_from_q,
)
from app.services.quality_shadow.scoring import run_shadow_score
from app.services.quality_shadow import maybe_schedule_quality_shadow


def _obs_by_criterion(fb: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {o["criterion"]: o for o in fb["observations"]}


def _base_raw() -> dict[str, float]:
    return {
        "sharpness_laplacian_var": 100.0,
        "blur_inv_laplacian": 0.5,
        "brightness_mean": 0.48,
        "contrast_rms": 0.5,
        "blocking_boundary_ratio": 1.0,
    }


def test_each_supported_criterion_emits_observation() -> None:
    fb = generate_hybrid_feedback(
        criteria_q={
            "sharpness": 0.8,
            "blur": 0.8,
            "brightness": 0.8,
            "contrast": 0.8,
            "blocking_artifacts": 0.8,
        },
        criteria_raw=_base_raw(),
        color={
            "color_balance": {"available": True, "badge": 5},
            "color_saturation": {"available": True, "badge": 5},
        },
        musiq_opq_raw=70.0,
        musiq_status="ok",
    )
    names = {o["criterion"] for o in fb["observations"]}
    assert names == {
        "sharpness",
        "blur",
        "brightness",
        "contrast",
        "blocking_artifacts",
        "color_balance",
        "color_saturation",
    }
    assert fb["musiq_excluded_from_criterion_feedback"] is True
    assert fb["production_feedback_mutated"] is False
    # MUSIQ must not appear as a criterion observation
    assert "musiq" not in names and "overall" not in names


@pytest.mark.parametrize(
    "q,expected",
    [
        (Q_SEVERE - 0.001, "severe"),
        (Q_SEVERE, "moderate"),
        (Q_MODERATE - 0.001, "moderate"),
        (Q_MODERATE, "mild"),
        (Q_MILD - 0.001, "mild"),
        (Q_MILD, "no_issue"),
        (1.0, "no_issue"),
    ],
)
def test_boundary_thresholds_q(q: float, expected: str) -> None:
    assert band_from_q(q) == expected


def test_boundary_triggers_correct_rule_id() -> None:
    fb = generate_hybrid_feedback(
        criteria_q={
            "sharpness": Q_SEVERE - 0.01,
            "blur": Q_SEVERE - 0.01,
            "brightness": Q_MODERATE - 0.01,
            "contrast": Q_MILD - 0.01,
            "blocking_artifacts": Q_MILD,
        },
        criteria_raw=_base_raw(),
        color={
            "color_balance": {"available": True, "badge": 2},
            "color_saturation": {"available": True, "badge": 3},
        },
    )
    by = _obs_by_criterion(fb)
    assert by["sharpness"]["rule_id"] == "sharpness_severe_v1"
    assert by["brightness"]["rule_id"] == "brightness_moderate_v1"
    assert by["contrast"]["rule_id"] == "contrast_mild_v1"
    assert by["blocking_artifacts"]["rule_id"] == "blocking_artifacts_no_issue_v1"
    assert by["color_balance"]["rule_id"] == "color_balance_severe_v1"
    assert by["color_saturation"]["rule_id"] == "color_saturation_moderate_v1"
    assert by["sharpness"]["threshold"]["value"] == Q_SEVERE


def test_missing_measurements_unavailable() -> None:
    fb = generate_hybrid_feedback(
        criteria_q={"sharpness": 0.9},  # blur + others missing
        criteria_raw={},
        color={},
    )
    by = _obs_by_criterion(fb)
    assert by["sharpness"]["observation_kind"] in ("issue", "no_issue")
    for c in ("blur", "brightness", "contrast", "blocking_artifacts", "color_balance", "color_saturation"):
        assert by[c]["observation_kind"] == "unavailable"
        assert "No reliable" in by[c]["observation"]
        assert by[c]["confidence"] == "unavailable"


def test_color_unavailable_not_fabricated() -> None:
    fb = generate_hybrid_feedback(
        criteria_q={
            "sharpness": 0.9,
            "blur": 0.9,
            "brightness": 0.9,
            "contrast": 0.9,
            "blocking_artifacts": 0.9,
        },
        criteria_raw=_base_raw(),
        color={
            "color_balance": {"available": False, "badge": None},
            "color_saturation": {"available": False, "badge": None},
        },
    )
    by = _obs_by_criterion(fb)
    assert by["color_balance"]["observation_kind"] == "unavailable"
    assert by["color_saturation"]["observation_kind"] == "unavailable"
    assert "cast" not in by["color_balance"]["observation"].lower() or "No reliable" in by["color_balance"]["observation"]


def test_sharpness_blur_duplicate_suppressed() -> None:
    fb = generate_hybrid_feedback(
        criteria_q={
            "sharpness": 0.1,
            "blur": 0.1,
            "brightness": 0.9,
            "contrast": 0.9,
            "blocking_artifacts": 0.9,
        },
        criteria_raw=_base_raw(),
        color={
            "color_balance": {"available": True, "badge": 5},
            "color_saturation": {"available": True, "badge": 5},
        },
    )
    by = _obs_by_criterion(fb)
    assert by["sharpness"]["observation_kind"] == "issue"
    assert by["blur"]["observation_kind"] == "suppressed_duplicate"
    assert by["blur"]["suppressed"] is True
    assert "shared_laplacian" in by["blur"]["suppression_reason"]
    # Only one focus issue counted
    assert fb["issue_count"] == 1


def test_contradictory_focus_bands_still_deduped() -> None:
    """Even if q values somehow diverge, blur remains suppressed when sharpness exists."""
    fb = generate_hybrid_feedback(
        criteria_q={
            "sharpness": 0.9,  # no_issue
            "blur": 0.1,  # would be severe if emitted
            "brightness": 0.9,
            "contrast": 0.9,
            "blocking_artifacts": 0.9,
        },
        criteria_raw=_base_raw(),
        color={
            "color_balance": {"available": True, "badge": 5},
            "color_saturation": {"available": True, "badge": 5},
        },
    )
    by = _obs_by_criterion(fb)
    assert by["sharpness"]["observation_kind"] == "no_issue"
    assert by["blur"]["suppressed"] is True
    assert by["blur"]["observation_kind"] == "suppressed_duplicate"
    assert fb["issue_count"] == 0


def test_production_payload_immutable() -> None:
    payload = {"ai_feedback": "prod", "recommendation": "Accepted", "overall_score": 4.0}
    snap = json.dumps(payload, sort_keys=True)
    _ = generate_hybrid_feedback(
        criteria_q={
            "sharpness": 0.2,
            "blur": 0.2,
            "brightness": 0.2,
            "contrast": 0.2,
            "blocking_artifacts": 0.2,
        },
        criteria_raw=_base_raw(),
        color={
            "color_balance": {"available": True, "badge": 2},
            "color_saturation": {"available": True, "badge": 2},
        },
    )
    assert json.dumps(payload, sort_keys=True) == snap


def test_shadow_flag_disabled_skips_feedback_path(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr("app.config.settings.quality_shadow_enabled", False)
    called: list[str] = []

    def _boom(*a, **k):  # noqa: ANN001
        called.append("generate")
        raise AssertionError("feedback must not run when shadow disabled")

    monkeypatch.setattr(
        "app.services.quality_shadow.scoring.generate_hybrid_feedback",
        _boom,
    )
    assert (
        maybe_schedule_quality_shadow(
            evaluation_id=1,
            media_id=1,
            file_bytes=b"abc",
            is_photo=True,
        )
        is False
    )
    assert called == []


def test_run_shadow_score_includes_experimental_feedback(monkeypatch: pytest.MonkeyPatch) -> None:
    import numpy as np
    import cv2

    bgr = np.full((48, 48, 3), 110, dtype=np.uint8)
    ok, buf = cv2.imencode(".jpg", bgr)
    assert ok
    monkeypatch.setattr(
        "app.services.quality_shadow.scoring.score_image_bytes_musiq",
        lambda *a, **k: {
            "status": "unavailable",
            "musiq_opq_raw": None,
            "musiq_scale": "approx_0_100_mos_like",
            "model_id": "x",
            "engine_handle": None,
            "error": "unavailable",
        },
    )
    record = run_shadow_score(
        content=bytes(buf),
        evaluation_id=1,
        media_id=2,
        anon_salt="test",
    )
    fb = record["experimental_feedback"]
    assert fb is not None
    assert fb["feedback_ruleset_version"]
    assert isinstance(fb["observations"], list)
    assert len(fb["observations"]) == 7
    assert fb["disclaimer"]
