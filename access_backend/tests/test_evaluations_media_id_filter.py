"""GET /evaluations?media_id= returns a single member row."""

from __future__ import annotations

from datetime import datetime, timezone
from unittest.mock import MagicMock, patch

from app.api.routes import evaluations as evaluations_routes


def test_list_evaluations_media_id_returns_one_row() -> None:
    ev = MagicMock()
    ev.media_id = 42
    ev.media.uploaded_by = 7
    ev.media.file_name = "practice.jpg"
    ev.media.file_url = "/uploads/x.jpg"
    ev.media.storage_removed_at = None
    ev.criteria_json = '{"overall_score": 4}'
    ev.overall_score = 4.0
    ev.feedback = "ok"
    ev.sharpness_score = 0.8
    ev.brightness_score = 0.8
    ev.contrast_score = 0.8
    ev.blur_score = 0.8
    ev.noise_score = 0.2
    ev.quality_level = "Good"
    ev.recommendation = "Accepted"
    ev.evaluated_at = datetime.now(timezone.utc)
    ev.id = 1

    db = MagicMock()
    user = MagicMock()
    user.id = 7

    with patch.object(evaluations_routes.eval_crud, "get_for_media", return_value=ev):
        with patch.object(evaluations_routes.eval_crud, "get_ai_for_media", return_value=None):
            with patch.object(
                evaluations_routes,
                "evaluation_row_for_member",
                return_value=(
                    ev.criteria_json,
                    ev.overall_score,
                    ev.feedback,
                    ev.sharpness_score,
                    ev.brightness_score,
                    ev.contrast_score,
                    ev.blur_score,
                    ev.noise_score,
                    ev.quality_level,
                    ev.recommendation,
                ),
            ):
                out = evaluations_routes.list_evaluations(
                    mine=True, media_id=42, db=db, current_user=user
                )

    assert len(out) == 1
    assert out[0].media_id == 42


def test_list_evaluations_media_id_not_owned_returns_empty() -> None:
    ev = MagicMock()
    ev.media.uploaded_by = 99
    db = MagicMock()
    user = MagicMock()
    user.id = 7

    with patch.object(evaluations_routes.eval_crud, "get_for_media", return_value=ev):
        out = evaluations_routes.list_evaluations(
            mine=True, media_id=42, db=db, current_user=user
        )
    assert out == []
