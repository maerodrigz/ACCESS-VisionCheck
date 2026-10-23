"""WaveRep G4 adapter compatibility (mocked; no real inference)."""

from __future__ import annotations

import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

from app.services.ai_authenticity_detector import detect_ai_generated, detect_ai_generated_from_frames
from app.services.waverep_g4_detector import (
    _map_waverep_raw_to_ai_payload,
    _normalize_prediction,
    _run_waverep_inference,
    detect_ai_generated_video,
    waverep_analysis_unavailable_payload,
)


def _complete_raw(*, processed: int = 20, requested: int = 20, ai_score: float = 0.12) -> dict:
    return {
        "model": "WaveRep G4",
        "video": "clip.mp4",
        "total_frames": 600,
        "requested_frames": requested,
        "processed_frames": processed,
        "failed_frames": [],
        "status": "complete",
        "mean_logit": -2.0,
        "ai_score": ai_score,
        "ai_percentage": ai_score * 100,
        "prediction": "Real / Non-AI",
        "threshold": 0.5,
        "frame_results": [{"index": 0, "logit": -2.0}],
    }


class WaverepAdapterTests(unittest.TestCase):
    def test_normalize_prediction_strings(self) -> None:
        self.assertEqual(_normalize_prediction("AI-generated"), "ai_generated")
        self.assertEqual(_normalize_prediction("Real / Non-AI"), "real")

    def test_ai_score_zero_to_one(self) -> None:
        out = _map_waverep_raw_to_ai_payload(_complete_raw(ai_score=0.12))
        self.assertEqual(out["probability"], 0.12)
        self.assertEqual(out["verdict"], "authentic")

    def test_complete_twenty_frames_success(self) -> None:
        out = _map_waverep_raw_to_ai_payload(_complete_raw(processed=20, requested=20))
        self.assertEqual(out["waverep_frames_analyzed"], 20)
        self.assertFalse(out["requires_review"])
        self.assertIn("waverep_frame_results", out["waverep_supplementary"])

    def test_partial_status_requires_review(self) -> None:
        raw = _complete_raw(processed=18, requested=20, ai_score=0.05)
        raw["status"] = "partial"
        raw["failed_frames"] = [100, 200]
        out = _map_waverep_raw_to_ai_payload(raw)
        self.assertTrue(out["requires_review"])
        self.assertEqual(out["waverep_processing_status"], "partial")
        self.assertEqual(out["waverep_failed_frames"], 2)
        self.assertEqual(out["verdict"], "suspicious")

    def test_min_processed_frames_enforced(self) -> None:
        from app.config import settings

        with patch.object(settings, "waverep_min_successful_frames", 5):
            out = _map_waverep_raw_to_ai_payload(_complete_raw(processed=2, requested=20))
        self.assertTrue(out["waverep_analysis_unavailable"])

    def test_failed_frames_list_length(self) -> None:
        raw = _complete_raw(processed=19, requested=20)
        raw["status"] = "partial"
        raw["failed_frames"] = [1, 2, 3]
        out = _map_waverep_raw_to_ai_payload(raw)
        self.assertEqual(out["waverep_failed_frames"], 3)

    @patch("app.services.waverep_g4_detector._resolve_detector_instance")
    def test_analyze_path_and_temp_cleanup(self, mock_resolve: MagicMock) -> None:
        seen: list[str] = []

        def _analyze(path: str) -> dict:
            seen.append(path)
            self.assertTrue(Path(path).is_file())
            return _complete_raw()

        inst = MagicMock()
        inst.analyze.side_effect = _analyze
        mock_resolve.return_value = inst

        result = _run_waverep_inference(b"fake-video-bytes", video_ext=".mp4", file_name="clip.mp4")
        self.assertIsNotNone(result)
        self.assertEqual(len(seen), 1)
        self.assertFalse(Path(seen[0]).exists())
        inst.analyze.assert_called_once()

    @patch("app.services.waverep_g4_detector._resolve_detector_instance", return_value=None)
    @patch("app.services.waverep_g4_detector._detector_init_error", "init failed")
    def test_init_failure_unavailable(self, _mock_det: MagicMock) -> None:
        out = detect_ai_generated_video(b"x", video_ext=".mp4")
        self.assertTrue(out["waverep_analysis_unavailable"])

    @patch("app.services.waverep_g4_detector.importlib.import_module")
    def test_constructor_uses_weights_device_samples(self, mock_import: MagicMock) -> None:
        import app.services.waverep_g4_detector as mod

        mod._detector_instance = None
        mod._detector_init_error = None

        class FakeDetector:
            def __init__(self, weights, device, samples):
                self.kwargs = {"weights": weights, "device": device, "samples": samples}

            def analyze(self, path):
                return _complete_raw()

        fake_module = MagicMock()
        fake_module.WaveRepDetector = FakeDetector
        mock_import.return_value = fake_module

        ckpt = mod.waverep_checkpoint_path()
        with patch.object(Path, "is_file", return_value=True):
            inst = mod._resolve_detector_instance()
        self.assertIsNotNone(inst)
        self.assertEqual(inst.kwargs["device"], "cpu")
        self.assertEqual(inst.kwargs["samples"], 20)
        self.assertTrue(str(inst.kwargs["weights"]).endswith("weights_dinov2_G4.ckpt"))

        mod._detector_instance = None
        mod._detector_init_error = None

    @patch("app.services.waverep_g4_detector.is_waverep_video_detection_enabled", return_value=True)
    @patch("app.services.waverep_g4_detector.detect_ai_generated_video")
    @patch("app.services.ai_authenticity_detector.detect_ai_generated")
    def test_no_probe_video_when_enabled(
        self,
        mock_probe: MagicMock,
        mock_waverep: MagicMock,
        _flag: MagicMock,
    ) -> None:
        mock_waverep.return_value = {"detector_backend": "waverep_g4", "requires_review": True}
        detect_ai_generated_from_frames([b"f"], video_content=b"v", video_ext=".mp4")
        mock_waverep.assert_called_once()
        mock_probe.assert_not_called()

    @patch("app.services.waverep_g4_detector.is_waverep_video_detection_enabled", return_value=False)
    @patch("app.services.ai_authenticity_detector.detect_ai_generated")
    def test_probe_video_when_disabled(self, mock_probe: MagicMock, _flag: MagicMock) -> None:
        mock_probe.return_value = {"detector_backend": "probe", "probability": 0.1}
        out = detect_ai_generated_from_frames([b"f"], video_content=b"v", video_ext=".mp4")
        mock_probe.assert_called()
        self.assertEqual(out["detector_backend"], "probe")

    @patch("app.services.ai_authenticity_detector.active_ai_detector_backend", return_value="probe")
    @patch("app.services.ai_authenticity_detector.dedicated_ai_probability", return_value=0.1)
    def test_probe_image_unchanged(self, _p: MagicMock, _b: MagicMock) -> None:
        with patch("app.services.waverep_g4_detector.waverep_enabled", return_value=False):
            out = detect_ai_generated(b"\xff\xd8\xff" + b"x" * 100, file_name="photo.jpg")
        self.assertIn("detector_backend", out)
        self.assertEqual(out["detector_backend"], "probe")


if __name__ == "__main__":
    unittest.main()
