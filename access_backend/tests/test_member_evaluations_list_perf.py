"""Member evaluation LIST must not per-row Supabase-sign and must slim criteria_json."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from unittest.mock import MagicMock, patch

from app.api.routes import evaluations as evaluations_routes
from app.services.member_score_release import (
    MEMBER_UNDER_REVIEW_MESSAGE,
    slim_criteria_json_for_member_list,
)
from app.services.supabase_storage import (
    SUPABASE_STORAGE_REF_PREFIX,
    member_list_file_url,
)


def _full_criteria(*, released: bool = True) -> dict:
    return {
        "media_type": "video",
        "scoring_model": "musiq-paq2piq+opencv-classical",
        "scoring_formula_version": "v2",
        "overall_score": 4.2,
        "quality_level": "Good",
        "recommendation": "Accepted",
        "improvement_suggestions": "Keep the subject steady and avoid harsh backlight.",
        "member_scores_released": released,
        "show_quality_feedback": released,
        "ai_detection": {"verdict": "authentic", "confidence": 0.9, "requires_review": False},
        "criteria": [
            {
                "name": "Sharpness",
                "score": 4,
                "available": True,
                "suggestion": "Tap to focus before capture.",
                "explanation": "long explanation " * 30,
            },
            {"name": "Blur", "score": 4, "available": True},
            {"name": "Motion Stability", "score": 3, "available": True},
        ],
        "rule_based_feedback": {"explanation": "long text " * 40},
        "gemini_feedback": {"explanation": "mentor " * 40},
        "analysis": {
            "frames_analyzed": 4,
            "quality_engine": "musiq_worker",
            "scoring_formula_version": "v2",
        },
        "legacy": {"overall_score": 0.84},
    }


def test_member_list_file_url_keeps_supabase_ref_without_signing() -> None:
    ref = f"{SUPABASE_STORAGE_REF_PREFIX}access-media/access-visioncheck/media/1/a.mp4"
    with patch(
        "app.services.supabase_storage._resolve_supabase_storage_ref",
        side_effect=AssertionError("must not sign on list path"),
    ):
        assert member_list_file_url(ref) == ref
        assert member_list_file_url(ref, storage_removed=True) == ""
        assert member_list_file_url("/uploads/x.jpg") == "/uploads/x.jpg"
        assert member_list_file_url("https://example.com/o.jpg").startswith("https://")


def test_slim_criteria_drops_heavy_rubric_keeps_integrity() -> None:
    full = _full_criteria()
    full["ai_detection"]["exif_metadata"] = {"Make": "x", "huge": "y" * 500}
    full["ai_detection"]["signals"] = [{"name": "a"} for _ in range(20)]
    slim = slim_criteria_json_for_member_list(json.dumps(full))
    assert slim is not None
    data = json.loads(slim)
    assert data["media_type"] == "video"
    assert data["scoring_formula_version"] == "v2"
    assert data["overall_score"] == 4.2
    assert data["ai_detection"]["verdict"] == "authentic"
    assert "exif_metadata" not in data["ai_detection"]
    assert "signals" not in data["ai_detection"]
    assert isinstance(data.get("criteria"), list)
    assert data["criteria"][0]["name"] == "Sharpness"
    assert data["criteria"][0]["suggestion"].startswith("Tap to focus")
    assert data["criteria"][0].get("explanation") in ("", None)
    assert "rule_based_feedback" not in data
    assert "gemini_feedback" not in data
    assert "analysis" not in data
    assert "legacy" not in data


def test_list_evaluations_does_not_call_normalize_sign_and_slims_criteria() -> None:
    ref = f"{SUPABASE_STORAGE_REF_PREFIX}bucket/path/clip.mp4"
    criteria = json.dumps(_full_criteria())
    ev = MagicMock()
    ev.id = 9
    ev.media_id = 90
    ev.media.uploaded_by = 7
    ev.media.file_name = "clip.mp4"
    ev.media.file_url = ref
    ev.media.storage_removed_at = None
    ev.media.submission_chain_id = None
    ev.media.replaces_media_id = None
    ev.media.replacement_lifecycle = None
    ev.criteria_json = criteria
    ev.overall_score = 0.84
    ev.feedback = "ok"
    ev.sharpness_score = 0.8
    ev.brightness_score = 0.8
    ev.contrast_score = 0.8
    ev.blur_score = 0.8
    ev.noise_score = 0.2
    ev.quality_level = "Good"
    ev.recommendation = "Accepted"
    ev.evaluated_at = datetime.now(timezone.utc)

    db = MagicMock()
    user = MagicMock()
    user.id = 7
    ai = MagicMock()
    ai.review_status = "automated_low_ai_risk"
    ai.ai_probability = 0.1
    ai.detection_result = "authentic"
    ai.admin_remarks = None

    with patch.object(evaluations_routes.eval_crud, "list_for_user", return_value=[ev]):
        with patch.object(evaluations_routes.eval_crud, "ai_by_media_ids", return_value={90: ai}):
            with patch.object(evaluations_routes, "chains_by_ids", return_value={}):
                with patch(
                    "app.services.supabase_storage.normalize_supabase_storage_url",
                    side_effect=AssertionError("list must not normalize/sign"),
                ):
                    with patch(
                        "app.services.supabase_storage._resolve_supabase_storage_ref",
                        side_effect=AssertionError("list must not resolve refs"),
                    ):
                        out = evaluations_routes.list_evaluations(
                            mine=True, media_id=None, db=db, current_user=user
                        )

    assert len(out) == 1
    row = out[0]
    assert row.file_url == ref
    assert row.overall_score == 0.84
    assert row.quality_level == "Good"
    parsed = json.loads(row.criteria_json or "{}")
    assert isinstance(parsed.get("criteria"), list)
    assert parsed["criteria"][0]["name"] == "Sharpness"
    assert parsed.get("scoring_formula_version") == "v2"
    assert parsed.get("ai_detection", {}).get("verdict") == "authentic"


def test_media_id_detail_keeps_full_criteria_without_signing() -> None:
    ref = f"{SUPABASE_STORAGE_REF_PREFIX}bucket/path/photo.jpg"
    criteria = json.dumps(_full_criteria())
    ev = MagicMock()
    ev.id = 1
    ev.media_id = 42
    ev.media.uploaded_by = 7
    ev.media.file_name = "photo.jpg"
    ev.media.file_url = ref
    ev.media.storage_removed_at = None
    ev.media.submission_chain_id = None
    ev.media.replaces_media_id = None
    ev.media.replacement_lifecycle = None
    ev.criteria_json = criteria
    ev.overall_score = 0.84
    ev.feedback = "ok"
    ev.sharpness_score = 0.8
    ev.brightness_score = 0.8
    ev.contrast_score = 0.8
    ev.blur_score = 0.8
    ev.noise_score = 0.2
    ev.quality_level = "Good"
    ev.recommendation = "Accepted"
    ev.evaluated_at = datetime.now(timezone.utc)

    db = MagicMock()
    user = MagicMock()
    user.id = 7

    with patch.object(evaluations_routes.eval_crud, "get_for_media", return_value=ev):
        with patch.object(evaluations_routes.eval_crud, "get_ai_for_media", return_value=None):
            with patch(
                "app.services.supabase_storage._resolve_supabase_storage_ref",
                side_effect=AssertionError("detail row must not sign either"),
            ):
                out = evaluations_routes.list_evaluations(
                    mine=True, media_id=42, db=db, current_user=user
                )

    assert len(out) == 1
    parsed = json.loads(out[0].criteria_json or "{}")
    assert isinstance(parsed.get("criteria"), list)
    assert len(parsed["criteria"]) == 3
    assert out[0].file_url == ref


def test_held_scores_remain_redacted_on_list() -> None:
    held = _full_criteria(released=False)
    held["ai_detection"] = {
        "verdict": "suspicious",
        "confidence": 0.5,
        "requires_review": True,
    }
    criteria = json.dumps(held)
    ev = MagicMock()
    ev.id = 2
    ev.media_id = 50
    ev.media.uploaded_by = 7
    ev.media.file_name = "held.jpg"
    ev.media.file_url = "/uploads/held.jpg"
    ev.media.storage_removed_at = None
    ev.media.submission_chain_id = None
    ev.media.replaces_media_id = None
    ev.media.replacement_lifecycle = None
    ev.criteria_json = criteria
    ev.overall_score = 0.9
    ev.feedback = "secret scores"
    ev.sharpness_score = 0.9
    ev.brightness_score = 0.9
    ev.contrast_score = 0.9
    ev.blur_score = 0.9
    ev.noise_score = 0.1
    ev.quality_level = "Excellent"
    ev.recommendation = "Accepted"
    ev.evaluated_at = datetime.now(timezone.utc)

    ai = MagicMock()
    ai.review_status = "needs_further_review"
    ai.ai_probability = 0.4
    ai.detection_result = "suspicious"
    ai.admin_remarks = None

    db = MagicMock()
    user = MagicMock()
    user.id = 7

    with patch.object(evaluations_routes.eval_crud, "list_for_user", return_value=[ev]):
        with patch.object(evaluations_routes.eval_crud, "ai_by_media_ids", return_value={50: ai}):
            with patch.object(evaluations_routes, "chains_by_ids", return_value={}):
                out = evaluations_routes.list_evaluations(
                    mine=True, media_id=None, db=db, current_user=user
                )

    row = out[0]
    assert row.overall_score == 0.0
    assert row.quality_level is None
    parsed = json.loads(row.criteria_json or "{}")
    assert parsed.get("member_scores_released") is False
    assert "criteria" not in parsed
    assert MEMBER_UNDER_REVIEW_MESSAGE in (parsed.get("review_gate_message") or row.feedback or "")
