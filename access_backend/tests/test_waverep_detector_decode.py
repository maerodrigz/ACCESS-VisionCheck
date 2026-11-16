"""WaveRep G4 frame sampling and decode retry helpers (no model inference)."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
import cv2
import numpy as np

import sys
from pathlib import Path as _Path

_BACKEND = _Path(__file__).resolve().parents[1]
sys.path.insert(0, str(_BACKEND / "ml" / "waverep"))
import waverep_detector as wrd  # noqa: E402


class WaverepSamplingTests(unittest.TestCase):
    def test_last_seekable_avoids_tail_for_416(self) -> None:
        self.assertEqual(wrd._last_seekable_frame_index(416), 411)

    def test_old_last_index_would_include_414(self) -> None:
        old_last = max(0, 416 - 2)
        indices = np.linspace(0, old_last, 20, dtype=int)
        self.assertIn(414, indices)

    def test_new_sampling_excludes_414(self) -> None:
        indices = wrd._build_sample_indices(416, 20)
        self.assertEqual(len(indices), 20)
        self.assertNotIn(414, indices)
        self.assertLessEqual(max(indices), 411)

    def test_short_video_single_frame(self) -> None:
        indices = wrd._build_sample_indices(1, 20)
        self.assertEqual(indices, [0])

    def test_retry_offsets_bounded(self) -> None:
        cands = wrd._candidate_read_indices(10, 411)
        self.assertLessEqual(len(cands), len(wrd._READ_RETRY_OFFSETS))
        self.assertEqual(cands[0], 10)

    def test_no_duplicate_candidates(self) -> None:
        cands = wrd._candidate_read_indices(0, 50)
        self.assertEqual(len(cands), len(set(cands)))


class WaverepSyntheticVideoTests(unittest.TestCase):
    def _write_test_video(self, path: Path, frame_count: int) -> None:
        fourcc = cv2.VideoWriter_fourcc(*"mp4v")
        writer = cv2.VideoWriter(str(path), fourcc, 10.0, (64, 64))
        self.assertTrue(writer.isOpened())
        for i in range(frame_count):
            color = (i % 256, (i * 2) % 256, (i * 3) % 256)
            writer.write(np.full((64, 64, 3), color, dtype=np.uint8))
        writer.release()

    def test_decode_twenty_samples_on_synthetic_416(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            video = Path(tmp) / "synthetic.mp4"
            self._write_test_video(video, 416)

            cap = cv2.VideoCapture(str(video))
            total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
            cap.release()
            self.assertGreater(total, 0)

            indices = wrd._build_sample_indices(total, 20)
            max_index = wrd._last_seekable_frame_index(total)
            used: set[int] = set()
            failed = []
            for req in indices:
                ok = False
                for cand in wrd._candidate_read_indices(req, max_index):
                    if cand in used:
                        continue
                    cap = cv2.VideoCapture(str(video))
                    success, _ = wrd._read_frame_at(cap, cand)
                    cap.release()
                    if success:
                        used.add(cand)
                        ok = True
                        break
                if not ok:
                    failed.append(req)

            self.assertEqual(len(failed), 0)
            self.assertEqual(len(used), 20)
            self.assertEqual(len(used), len(set(used)))


if __name__ == "__main__":
    unittest.main()
