"""Step 7A: deferred upload pipeline (mocked ML, no inference)."""

from __future__ import annotations

import json
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import pytest

from app.models.media_constants import MEDIA_CATEGORY_EVALUATION, MEDIA_CATEGORY_EVENT
from app.services.deferred_media_pipeline import (
    media_processing_status,
    run_deferred_media_pipeline_job,
    schedule_deferred_media_evaluation,
)
from app.services.media_pipeline import run_pipeline


def _evaluation_media(*, with_eval: bool = False) -> SimpleNamespace:
    ev = [SimpleNamespace(overall_score=4.2)] if with_eval else []
    return SimpleNamespace(
        id=42,
        media_category=MEDIA_CATEGORY_EVALUATION,
        file_url="/uploads/images/abc.jpg",
        file_name="practice.jpg",
        evaluations=ev,
        uploaded_by=7,
    )


def test_processing_status_processing_and_completed() -> None:
    assert media_processing_status(_evaluation_media(with_eval=False)) == "processing"
    assert media_processing_status(_evaluation_media(with_eval=True)) == "completed"
    event = SimpleNamespace(id=1, media_category=MEDIA_CATEGORY_EVENT, evaluations=[])
    assert media_processing_status(event) is None


def test_run_pipeline_idempotent_skips_second_run() -> None:
    db = MagicMock()
    media = SimpleNamespace(id=99)
    existing_ev = MagicMock()
    existing_ai = MagicMock()

    with patch("app.services.media_pipeline.eval_crud.get_for_media", return_value=existing_ev):
        with patch("app.services.media_pipeline.eval_crud.get_ai_for_media", return_value=existing_ai):
            with patch("app.services.media_pipeline.evaluate_bytes") as mock_eval:
                out = run_pipeline(db, media, b"bytes")

    mock_eval.assert_not_called()
    assert out == (existing_ev, existing_ai)


def test_require_full_analysis_no_placeholder_scores() -> None:
    db = MagicMock()
    media = SimpleNamespace(id=1, file_name="x.jpg", file_url="/uploads/x.jpg", file_type="photo")

    with patch("app.services.media_pipeline.eval_crud.get_for_media", return_value=None):
        with patch("app.services.media_pipeline._payload_from_preview_metadata", return_value=None):
            with patch("app.services.media_pipeline.evaluate_bytes", return_value=None):
                with patch("app.services.media_pipeline.eval_crud.create_evaluation") as create_ev:
                    out = run_pipeline(db, media, b"x", require_full_analysis=True)

    assert out is None
    create_ev.assert_not_called()


def test_deferred_job_uses_independent_session_and_skips_if_eval_exists() -> None:
    mock_db = MagicMock()
    media = SimpleNamespace(
        id=5,
        media_category=MEDIA_CATEGORY_EVALUATION,
        file_url="/uploads/images/a.jpg",
        file_name="a.jpg",
    )

    with patch("app.services.deferred_media_pipeline.SessionLocal", return_value=mock_db):
        with patch("app.services.deferred_media_pipeline.media_crud.get", return_value=media):
            with patch("app.services.deferred_media_pipeline.eval_crud.get_for_media", return_value=MagicMock()):
                with patch("app.services.deferred_media_pipeline.run_pipeline") as run_pl:
                    run_deferred_media_pipeline_job(5, None)

    run_pl.assert_not_called()
    mock_db.close.assert_called_once()


def test_deferred_job_runs_pipeline_on_success() -> None:
    mock_db = MagicMock()
    media = SimpleNamespace(
        id=6,
        media_category=MEDIA_CATEGORY_EVALUATION,
        file_url="/uploads/images/b.jpg",
        file_name="b.jpg",
    )

    with patch("app.services.deferred_media_pipeline.SessionLocal", return_value=mock_db):
        with patch("app.services.deferred_media_pipeline.media_crud.get", return_value=media):
            with patch("app.services.deferred_media_pipeline.eval_crud.get_for_media", return_value=None):
                with patch(
                    "app.services.deferred_media_pipeline._payload_from_preview_metadata",
                    return_value=None,
                ):
                    with patch(
                        "app.services.deferred_media_pipeline.read_media_file_bytes",
                        return_value=b"jpg-bytes",
                    ):
                        with patch(
                            "app.services.deferred_media_pipeline.run_pipeline",
                            return_value=(MagicMock(), MagicMock()),
                        ) as run_pl:
                            run_deferred_media_pipeline_job(6, '{"criteria":[]}')

    run_pl.assert_called_once()
    _, kwargs = run_pl.call_args
    assert kwargs.get("require_full_analysis") is True
    mock_db.close.assert_called_once()


def test_deferred_failure_no_pipeline_result_rolls_back() -> None:
    mock_db = MagicMock()
    media = SimpleNamespace(
        id=8,
        media_category=MEDIA_CATEGORY_EVALUATION,
        file_url="/uploads/images/c.jpg",
        file_name="c.jpg",
    )

    with patch("app.services.deferred_media_pipeline.SessionLocal", return_value=mock_db):
        with patch("app.services.deferred_media_pipeline.media_crud.get", return_value=media):
            with patch("app.services.deferred_media_pipeline.eval_crud.get_for_media", return_value=None):
                with patch(
                    "app.services.deferred_media_pipeline._payload_from_preview_metadata",
                    return_value=None,
                ):
                    with patch(
                        "app.services.deferred_media_pipeline.read_media_file_bytes",
                        return_value=b"x",
                    ):
                        with patch(
                            "app.services.deferred_media_pipeline.run_pipeline",
                            return_value=None,
                        ):
                            run_deferred_media_pipeline_job(8, None)

    mock_db.rollback.assert_called()
    mock_db.close.assert_called_once()


def test_schedule_uses_bounded_executor() -> None:
    mock_executor = MagicMock()
    with patch(
        "app.services.deferred_media_pipeline.get_media_evaluation_executor",
        return_value=mock_executor,
    ):
        schedule_deferred_media_evaluation(10, "meta")
    mock_executor.submit.assert_called_once()
    args = mock_executor.submit.call_args[0]
    assert args[0].__name__ == "run_deferred_media_pipeline_job"
    assert args[1:] == (10, "meta")


def test_duplicate_scheduling_does_not_run_pipeline_twice() -> None:
    mock_db = MagicMock()
    media = SimpleNamespace(
        id=77,
        media_category=MEDIA_CATEGORY_EVALUATION,
        file_url="/uploads/images/d.jpg",
        file_name="d.jpg",
    )
    completed = {"done": False}

    def get_for_media(_db, _mid):
        return MagicMock() if completed["done"] else None

    def fake_run_pipeline(*_a, **_k):
        completed["done"] = True
        return (MagicMock(), MagicMock())

    with patch("app.services.deferred_media_pipeline.SessionLocal", return_value=mock_db):
        with patch("app.services.deferred_media_pipeline.media_crud.get", return_value=media):
            with patch(
                "app.services.deferred_media_pipeline.eval_crud.get_for_media",
                side_effect=get_for_media,
            ):
                with patch(
                    "app.services.deferred_media_pipeline._payload_from_preview_metadata",
                    return_value={"criteria": [], "overall_score": 4, "ai_detection": {}},
                ):
                    with patch(
                        "app.services.deferred_media_pipeline.run_pipeline",
                        side_effect=fake_run_pipeline,
                    ) as run_pl:
                        run_deferred_media_pipeline_job(77, "{}")
                        run_deferred_media_pipeline_job(77, "{}")

    assert run_pl.call_count == 1


def test_preview_metadata_skips_byte_read() -> None:
    mock_db = MagicMock()
    media = SimpleNamespace(
        id=9,
        media_category=MEDIA_CATEGORY_EVALUATION,
        file_url="/uploads/images/e.jpg",
        file_name="e.jpg",
    )
    preview = {
        "criteria": [{"name": "Sharpness", "score": 4}],
        "overall_score": 4.0,
        "ai_detection": {"verdict": "authentic", "probability": 0.1},
        "scoring_model": "efficientnet-b0",
        "legacy": {"overall_score": 0.8},
        "xp_eligible": True,
    }

    with patch("app.services.deferred_media_pipeline.SessionLocal", return_value=mock_db):
        with patch("app.services.deferred_media_pipeline.media_crud.get", return_value=media):
            with patch("app.services.deferred_media_pipeline.eval_crud.get_for_media", return_value=None):
                with patch(
                    "app.services.deferred_media_pipeline._payload_from_preview_metadata",
                    return_value=preview,
                ):
                    with patch(
                        "app.services.deferred_media_pipeline.read_media_file_bytes",
                    ) as read_bytes:
                        with patch(
                            "app.services.deferred_media_pipeline.run_pipeline",
                            return_value=(MagicMock(), MagicMock()),
                        ) as run_pl:
                            run_deferred_media_pipeline_job(9, json.dumps(preview))

    read_bytes.assert_not_called()
    run_pl.assert_called_once()
    assert run_pl.call_args[0][2] == b""


def test_default_detector_still_univfd() -> None:
    from app.config import settings
    from app.services.dedicated_ai_detector import active_ai_detector_backend

    assert settings.ai_detector_backend == "univfd"
    assert active_ai_detector_backend() == "univfd"


def test_integrity_xp_pending_via_preview_payload() -> None:
    from app.services.integrity_evaluation_policy import apply_integrity_evaluation_policy, xp_award_points_from_payload

    payload = apply_integrity_evaluation_policy(
        {
            "criteria": [],
            "overall_score": 4.0,
            "legacy": {"overall_score": 0.8},
            "ai_detection": {"verdict": "suspicious", "probability": 0.4},
        }
    )
    assert payload["xp_pending"] is True
    assert xp_award_points_from_payload(payload) == 0
