"""WaveRep scaffolding: default off preserves PROBE video path; enabled path does not call PROBE."""

from __future__ import annotations

import unittest
from unittest.mock import MagicMock, patch

from app.services.ai_review_workflow import initial_review_status
from app.services.waverep_g4_detector import (
    detect_ai_generated_video,
    is_waverep_video_detection_enabled,
    waverep_analysis_unavailable_payload,
    waverep_enabled,
    waverep_runtime_status,
)


class WaverepScaffoldingTests(unittest.TestCase):
    def test_default_flag_off(self) -> None:
        self.assertFalse(waverep_enabled())
        self.assertFalse(is_waverep_video_detection_enabled())

    def test_runtime_status_flag_off(self) -> None:
        status = waverep_runtime_status()
        self.assertFalse(status["enabled"])
        self.assertTrue(status["module_file_exists"])
        self.assertTrue(status["checkpoint_exists"])

    def test_unavailable_payload_requires_review(self) -> None:
        payload = waverep_analysis_unavailable_payload("test")
        self.assertTrue(payload["requires_review"])
        self.assertEqual(payload["detector_backend"], "waverep_g4")
        self.assertTrue(payload["waverep_analysis_unavailable"])

    def test_initial_review_status_waverep_unavailable(self) -> None:
        ai = waverep_analysis_unavailable_payload("no checkpoint")
        status = initial_review_status("suspicious", 0.0, ai_detection=ai)
        self.assertEqual(status, "needs_further_review")

    @patch("app.services.ai_authenticity_detector.active_ai_detector_backend", return_value="probe")
    @patch("app.services.ai_authenticity_detector.detect_ai_generated")
    def test_probe_still_used_when_waverep_disabled(
        self,
        mock_detect: MagicMock,
        _mock_backend: MagicMock,
    ) -> None:
        from app.services.ai_authenticity_detector import detect_ai_generated_from_frames

        mock_detect.return_value = {
            "verdict": "authentic",
            "probability": 0.1,
            "confidence": 0.9,
            "detector_backend": "probe",
        }
        with patch("app.services.waverep_g4_detector.is_waverep_video_detection_enabled", return_value=False):
            out = detect_ai_generated_from_frames(
                [b"frame"],
                file_name="clip.mp4",
                video_content=b"video-bytes",
                video_ext=".mp4",
            )
        mock_detect.assert_called()
        self.assertEqual(out.get("detector_backend"), "probe")

    @patch("app.services.waverep_g4_detector.is_waverep_video_detection_enabled", return_value=True)
    @patch("app.services.waverep_g4_detector.detect_ai_generated_video")
    @patch("app.services.ai_authenticity_detector.detect_ai_generated")
    def test_waverep_enabled_skips_probe_on_frames(
        self,
        mock_probe: MagicMock,
        mock_waverep: MagicMock,
        _mock_flag: MagicMock,
    ) -> None:
        from app.services.ai_authenticity_detector import detect_ai_generated_from_frames

        mock_waverep.return_value = {
            "verdict": "suspicious",
            "probability": 0.4,
            "detector_backend": "waverep_g4",
            "requires_review": True,
        }
        out = detect_ai_generated_from_frames(
            [b"frame"],
            file_name="clip.mp4",
            video_content=b"video-bytes",
            video_ext=".mp4",
        )
        mock_waverep.assert_called_once()
        mock_probe.assert_not_called()
        self.assertEqual(out["detector_backend"], "waverep_g4")

    @patch("app.services.waverep_g4_detector._run_waverep_inference", return_value=None)
    @patch("app.services.waverep_g4_detector._detector_init_error", new="missing module")
    def test_enabled_without_module_no_probe_fallback(self, _mock_run: MagicMock) -> None:
        out = detect_ai_generated_video(b"video", video_ext=".mp4", file_name="a.mp4")
        self.assertTrue(out["requires_review"])
        self.assertTrue(out["waverep_analysis_unavailable"])
        self.assertEqual(out["detector_backend"], "waverep_g4")


if __name__ == "__main__":
    unittest.main()
