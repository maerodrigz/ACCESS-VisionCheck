"""Preview metadata must not bypass server video authenticity (WaveRep / PROBE-on-save)."""

from __future__ import annotations

import json
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from app.models.media_constants import MEDIA_CATEGORY_EVALUATION
from app.services.deferred_media_pipeline import run_deferred_media_pipeline_job
from app.services.media_evaluator import deferred_authenticity_preview
from app.services.media_pipeline import (
    _payload_from_preview_metadata,
    is_evaluation_category_video,
    run_pipeline,
)


def _fake_full_preview_metadata() -> str:
    return json.dumps(
        {
            "criteria": [{"name": "Sharpness", "score": 4, "label": "Good"}],
            "overall_score": 4.0,
            "legacy": {"overall_score": 0.8},
            "scoring_engine": "efficientnet-b0+ffmpeg",
            "ai_detection": {
                "verdict": "authentic",
                "probability": 0.01,
                "confidence": 0.99,
                "detector_backend": "probe",
                "requires_review": False,
            },
        }
    )


def _quality_only_metadata() -> str:
    return json.dumps(
        {
            "criteria": [{"name": "Sharpness", "score": 4, "label": "Good"}],
            "overall_score": 4.0,
            "legacy": {"overall_score": 0.8},
            "scoring_engine": "efficientnet-b0+ffmpeg",
            "ai_detection": deferred_authenticity_preview(),
        }
    )


def _video_media() -> SimpleNamespace:
    return SimpleNamespace(
        id=91,
        media_category=MEDIA_CATEGORY_EVALUATION,
        file_name="practice clip",
        file_url="/uploads/videos/abc.mp4",
        file_type="video",
        uploaded_by=None,
    )


def _photo_media() -> SimpleNamespace:
    return SimpleNamespace(
        id=92,
        media_category=MEDIA_CATEGORY_EVALUATION,
        file_name="shot.jpg",
        file_url="/uploads/images/abc.jpg",
        file_type="photo",
        uploaded_by=None,
    )


def test_full_preview_still_allowed_for_photos() -> None:
    assert _payload_from_preview_metadata(_fake_full_preview_metadata()) is not None


def test_evaluation_video_detected_by_url_extension() -> None:
    assert is_evaluation_category_video(_video_media()) is True
    assert is_evaluation_category_video(_photo_media()) is False


def test_video_full_preview_bypass_blocked_in_run_pipeline() -> None:
    db = MagicMock()
    media = _video_media()
    waverep_ai = {
        "verdict": "suspicious",
        "probability": 0.4,
        "detector_backend": "waverep_g4",
        "requires_review": True,
    }

    analyzed = {
        "criteria": [{"name": "Sharpness", "score": 4}],
        "overall_score": 4.0,
        "legacy": {"overall_score": 0.8},
        "ai_detection": waverep_ai,
    }
    with patch("app.services.waverep_g4_detector.is_waverep_video_detection_enabled", return_value=True):
        with patch("app.services.media_pipeline.eval_crud.get_for_media", return_value=None):
            with patch(
                "app.services.media_pipeline.evaluate_authenticity_bytes",
            ) as auth_only:
                with patch("app.services.media_pipeline.evaluate_bytes", return_value=analyzed) as full_eval:
                    with patch("app.services.media_pipeline.eval_crud.create_evaluation", return_value=MagicMock()):
                        with patch("app.services.media_pipeline.eval_crud.create_ai_result") as create_ai:
                            with patch(
                                "app.services.ai_review_workflow.initial_review_status",
                                return_value="needs_further_review",
                            ):
                                run_pipeline(
                                    db,
                                    media,
                                    b"video-bytes",
                                    evaluation_metadata=_fake_full_preview_metadata(),
                                    require_full_analysis=True,
                                )

    full_eval.assert_called_once()
    auth_only.assert_not_called()
    ai_kwargs = create_ai.call_args[0][1]
    assert ai_kwargs["detection_result"] == "suspicious"


def test_video_quality_only_preview_runs_server_authenticity() -> None:
    db = MagicMock()
    media = _video_media()
    server_ai = {"verdict": "suspicious", "probability": 0.5, "detector_backend": "waverep_g4", "requires_review": True}

    with patch("app.services.media_pipeline.eval_crud.get_for_media", return_value=None):
        with patch("app.services.media_pipeline.evaluate_authenticity_bytes", return_value=server_ai) as auth:
            with patch("app.services.media_pipeline.eval_crud.create_evaluation", return_value=MagicMock()):
                with patch("app.services.media_pipeline.eval_crud.create_ai_result") as create_ai:
                    with patch(
                        "app.services.ai_review_workflow.initial_review_status",
                        return_value="needs_further_review",
                    ):
                        run_pipeline(
                            db,
                            media,
                            b"video-bytes",
                            evaluation_metadata=_quality_only_metadata(),
                            require_full_analysis=True,
                        )

    auth.assert_called_once()
    assert create_ai.call_args[0][1]["detection_result"] == "suspicious"


def test_video_no_metadata_uses_evaluate_bytes() -> None:
    db = MagicMock()
    media = _video_media()
    analyzed = {
        "criteria": [{"name": "Sharpness", "score": 4}],
        "overall_score": 4.0,
        "legacy": {"overall_score": 0.8},
        "ai_detection": {"verdict": "suspicious", "probability": 0.5, "detector_backend": "waverep_g4"},
    }

    with patch("app.services.media_pipeline.eval_crud.get_for_media", return_value=None):
        with patch("app.services.media_pipeline.evaluate_bytes", return_value=analyzed) as full_eval:
            with patch("app.services.media_pipeline.eval_crud.create_evaluation", return_value=MagicMock()):
                with patch("app.services.media_pipeline.eval_crud.create_ai_result", return_value=MagicMock()):
                    with patch(
                        "app.services.ai_review_workflow.initial_review_status",
                        return_value="needs_further_review",
                    ):
                        run_pipeline(
                            db,
                            media,
                            b"video-bytes",
                            evaluation_metadata=None,
                            require_full_analysis=True,
                        )

    full_eval.assert_called_once()


def test_waverep_unavailable_not_authentic() -> None:
    db = MagicMock()
    media = _video_media()
    unavailable = {
        "verdict": "suspicious",
        "probability": None,
        "detector_backend": "waverep_g4",
        "requires_review": True,
        "waverep_analysis_unavailable": True,
    }

    with patch("app.services.media_pipeline.eval_crud.get_for_media", return_value=None):
        with patch("app.services.media_pipeline.evaluate_authenticity_bytes", return_value=unavailable):
            with patch("app.services.media_pipeline.eval_crud.create_evaluation", return_value=MagicMock()):
                with patch("app.services.media_pipeline.eval_crud.create_ai_result") as create_ai:
                    with patch(
                        "app.services.ai_review_workflow.initial_review_status",
                        return_value="needs_further_review",
                    ):
                        run_pipeline(
                            db,
                            media,
                            b"video-bytes",
                            evaluation_metadata=_quality_only_metadata(),
                            require_full_analysis=True,
                        )

    assert create_ai.call_args[0][1]["review_status"] == "needs_further_review"


def test_deferred_video_loads_bytes_despite_full_preview_metadata() -> None:
    mock_db = MagicMock()
    media = _video_media()

    with patch("app.services.deferred_media_pipeline.SessionLocal", return_value=mock_db):
        with patch("app.services.deferred_media_pipeline.media_crud.get", return_value=media):
            with patch("app.services.deferred_media_pipeline.eval_crud.get_for_media", return_value=None):
                with patch(
                    "app.services.deferred_media_pipeline.take_evaluation_upload",
                    return_value=b"stored-video",
                ) as take:
                    with patch(
                        "app.services.deferred_media_pipeline.read_media_file_bytes",
                    ) as read_remote:
                        with patch(
                            "app.services.deferred_media_pipeline.run_pipeline",
                            return_value=(MagicMock(), MagicMock()),
                        ) as run_pl:
                            run_deferred_media_pipeline_job(91, _fake_full_preview_metadata())

    take.assert_called_once_with(91)
    read_remote.assert_not_called()
    assert run_pl.call_args[0][2] == b"stored-video"


def test_deferred_photo_still_skips_bytes_when_full_preview() -> None:
    mock_db = MagicMock()
    media = _photo_media()

    with patch("app.services.deferred_media_pipeline.SessionLocal", return_value=mock_db):
        with patch("app.services.deferred_media_pipeline.media_crud.get", return_value=media):
            with patch("app.services.deferred_media_pipeline.eval_crud.get_for_media", return_value=None):
                with patch("app.services.deferred_media_pipeline.take_evaluation_upload") as take:
                    with patch(
                        "app.services.deferred_media_pipeline.run_pipeline",
                        return_value=(MagicMock(), MagicMock()),
                    ) as run_pl:
                        run_deferred_media_pipeline_job(92, _fake_full_preview_metadata())

    take.assert_not_called()
    assert run_pl.call_args[0][2] == b""
