"""Practice evaluation video guardrails (duration + provenance policy) — unittest, no pytest deps."""

from __future__ import annotations

import unittest
from unittest.mock import MagicMock, patch

from app.services.media_upload_config import (
    EvaluationVideoDurationError,
    check_evaluation_video_duration,
)
from app.services.probe_provenance_policy import apply_probe_provenance_policy
from app.services.camera_provenance import CameraProvenanceResult


class PracticeEvaluationVideoGuardrailsTest(unittest.TestCase):
    def test_check_duration_rejects_over_max(self) -> None:
        db = MagicMock()
        with patch(
            "app.services.media_upload_config.evaluation_rules",
            return_value={"max_video_seconds": 60},
        ):
            with patch(
                "app.services.media_upload_config.is_video_extension",
                return_value=True,
            ):
                with patch(
                    "app.services.ffmpeg_frames.probe_video_duration_from_bytes",
                    return_value=90.0,
                ):
                    with self.assertRaises(EvaluationVideoDurationError) as ctx:
                        check_evaluation_video_duration(db, ".mp4", b"fake")
        self.assertEqual(ctx.exception.max_seconds, 60)
        self.assertEqual(ctx.exception.actual_seconds, 90)

    def test_partial_provenance_low_risk_requires_review(self) -> None:
        base = {
            "verdict": "authentic",
            "probability": 0.05,
            "raw_detector_probability": 0.05,
            "risk_level": "low",
            "requires_review": False,
            "detail": "Low risk.",
        }
        out = apply_probe_provenance_policy(base, CameraProvenanceResult("partial", reasons=["test"]))
        self.assertTrue(out["requires_review"])
        self.assertEqual(out["provenance_policy_outcome"], "source_partially_verified")


if __name__ == "__main__":
    unittest.main()
