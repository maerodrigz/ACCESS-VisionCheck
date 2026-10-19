"""Practice evaluation video guardrails (duration + provenance policy) — unittest, no pytest deps."""

from __future__ import annotations

import unittest
from unittest.mock import MagicMock, patch

from fastapi import HTTPException

from app.services.media_upload_config import (
    EvaluationVideoDurationError,
    assert_evaluation_video_duration,
    check_evaluation_video_duration,
)
from app.services.probe_provenance_policy import apply_probe_provenance_policy
from app.services.camera_provenance import CameraProvenanceResult


def _check_with_max(db: MagicMock, *, max_seconds: int, probed_duration: float) -> None:
    with patch(
        "app.services.media_upload_config.evaluation_rules",
        return_value={"max_video_seconds": max_seconds},
    ):
        with patch(
            "app.services.media_upload_config.is_video_extension",
            return_value=True,
        ):
            with patch(
                "app.services.ffmpeg_frames.probe_video_duration_from_bytes",
                return_value=probed_duration,
            ):
                check_evaluation_video_duration(db, ".mp4", b"fake")


class PracticeEvaluationVideoGuardrailsTest(unittest.TestCase):
    def test_check_duration_accepts_within_limit(self) -> None:
        db = MagicMock()
        for seconds in (10.0, 20.0, 29.0, 30.0):
            with self.subTest(seconds=seconds):
                _check_with_max(db, max_seconds=30, probed_duration=seconds)

    def test_check_duration_rejects_over_max(self) -> None:
        db = MagicMock()
        for seconds in (31.0, 45.0, 60.0, 90.0):
            with self.subTest(seconds=seconds):
                with self.assertRaises(EvaluationVideoDurationError) as ctx:
                    _check_with_max(db, max_seconds=30, probed_duration=seconds)
                self.assertEqual(ctx.exception.max_seconds, 30)
                self.assertEqual(
                    str(ctx.exception),
                    "Video duration must not exceed 30 seconds.",
                )

    def test_check_duration_rejects_unknown_length(self) -> None:
        db = MagicMock()
        for probed in (0.0, -1.0):
            with self.subTest(probed=probed):
                with self.assertRaises(EvaluationVideoDurationError) as ctx:
                    _check_with_max(db, max_seconds=30, probed_duration=probed)
                self.assertIsNone(ctx.exception.actual_seconds)

    def test_assert_duration_maps_to_http_422(self) -> None:
        db = MagicMock()
        with patch(
            "app.services.media_upload_config.evaluation_rules",
            return_value={"max_video_seconds": 30},
        ):
            with patch(
                "app.services.media_upload_config.is_video_extension",
                return_value=True,
            ):
                with patch(
                    "app.services.ffmpeg_frames.probe_video_duration_from_bytes",
                    return_value=45.0,
                ):
                    with self.assertRaises(HTTPException) as ctx:
                        assert_evaluation_video_duration(db, ".mp4", b"fake")
        self.assertEqual(ctx.exception.status_code, 422)
        self.assertEqual(ctx.exception.detail, "Video duration must not exceed 30 seconds.")

    def test_partial_provenance_low_risk_incomplete_identity_needs_review(self) -> None:
        base = {
            "verdict": "authentic",
            "probability": 0.05,
            "raw_detector_probability": 0.05,
            "risk_level": "low",
            "requires_review": False,
            "detail": "Low risk.",
        }
        out = apply_probe_provenance_policy(
            base,
            CameraProvenanceResult(
                "partial",
                reasons=["Partial camera tag (test)."],
                safe_fields=[{"key": "Make", "label": "Make", "value": "Apple"}],
            ),
            file_name="club_event.jpg",
        )
        self.assertTrue(out["requires_review"])
        self.assertEqual(out["provenance_policy_outcome"], "source_unverified")

    def test_download_filename_photo_needs_review(self) -> None:
        base = {
            "verdict": "authentic",
            "probability": 0.05,
            "raw_detector_probability": 0.05,
            "risk_level": "low",
            "requires_review": False,
            "detail": "Low risk.",
            "exif_metadata": {"has_exif": True, "flags": [], "fields": []},
        }
        strong = CameraProvenanceResult(
            "strong",
            reasons=["Camera make/model present (test)."],
            safe_fields=[
                {"key": "Make", "label": "Make", "value": "Canon"},
                {"key": "Model", "label": "Model", "value": "EOS"},
            ],
        )
        out = apply_probe_provenance_policy(base, strong, file_name="images (1).jpg")
        self.assertTrue(out["requires_review"])

    def test_gallery_numeric_video_filename_forces_review(self) -> None:
        base = {
            "verdict": "authentic",
            "probability": 0.03,
            "raw_detector_probability": 0.03,
            "risk_level": "low",
            "requires_review": False,
            "detail": "Low risk.",
        }
        strong_encoder_only = CameraProvenanceResult(
            "strong",
            reasons=["Container creation time with mobile/video encoder hints."],
            safe_fields=[{"key": "creation_time", "label": "creation_time", "value": "2026-01-01"}],
            is_video=True,
        )
        out = apply_probe_provenance_policy(
            base,
            strong_encoder_only,
            file_name="1000442341",
        )
        self.assertTrue(out["requires_review"])
        self.assertEqual(out["provenance_policy_outcome"], "source_partially_verified")


if __name__ == "__main__":
    unittest.main()
