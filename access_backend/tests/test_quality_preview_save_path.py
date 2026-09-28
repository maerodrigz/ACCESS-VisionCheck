"""Save path: reuse POST /media/evaluate quality, run PROBE only on stored bytes."""

from __future__ import annotations

import json
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from app.services.media_evaluator import deferred_authenticity_preview
from app.services.media_pipeline import _quality_preview_from_metadata, run_pipeline


def _quality_preview_metadata() -> str:
    payload = {
        "criteria": [{"name": "Sharpness", "score": 4, "label": "Good"}],
        "overall_score": 4.0,
        "legacy": {"overall_score": 0.8},
        "scoring_engine": "efficientnet-b0+ffmpeg",
        "ai_detection": deferred_authenticity_preview(),
    }
    return json.dumps(payload)


def test_quality_preview_parsed_when_authenticity_deferred() -> None:
    preview = _quality_preview_from_metadata(_quality_preview_metadata())
    assert preview is not None
    assert preview["overall_score"] == 4.0


def test_run_pipeline_quality_preview_runs_authenticity_only() -> None:
    db = MagicMock()
    media = SimpleNamespace(
        id=1,
        file_name="clip.mp4",
        file_url="/uploads/videos/x.mp4",
        file_type="video",
        uploaded_by=None,
    )
    ai_detection = {"verdict": "authentic", "probability": 0.05}

    with patch("app.services.media_pipeline.eval_crud.get_for_media", return_value=None):
        with patch(
            "app.services.media_pipeline.evaluate_authenticity_bytes",
            return_value=ai_detection,
        ) as auth_only:
            with patch("app.services.media_pipeline.evaluate_bytes") as full_eval:
                with patch("app.services.media_pipeline.eval_crud.create_evaluation", return_value=MagicMock()):
                    with patch("app.services.media_pipeline.eval_crud.create_ai_result", return_value=MagicMock()):
                        with patch(
                            "app.services.ai_review_workflow.initial_review_status",
                            return_value="automated_low_ai_risk",
                        ):
                            run_pipeline(
                                db,
                                media,
                                b"video-bytes",
                                evaluation_metadata=_quality_preview_metadata(),
                                require_full_analysis=True,
                            )

    auth_only.assert_called_once()
    full_eval.assert_not_called()
