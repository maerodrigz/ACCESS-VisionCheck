import sys
import json
import cv2
import torch
import numpy as np
from pathlib import Path
from PIL import Image
from scipy.special import expit

BASE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BASE_DIR / "demo"))

from inference_utils import create_model, create_transform

# Stay below reported tail indices; phone MP4 often fails seek/read near EOF.
_TAIL_SEEK_MARGIN = 4
# Per sample slot: initial seek + nearby alternates (bounded, no infinite loop).
_READ_RETRY_OFFSETS = (0, -1, -2, 1, -3, 2)


def _last_seekable_frame_index(total: int) -> int:
    """Upper inclusive frame index safe for OpenCV CAP_PROP_POS_FRAMES."""
    if total <= 1:
        return 0
    margin = min(_TAIL_SEEK_MARGIN, max(0, total - 1))
    return max(0, total - 1 - margin)


def _build_sample_indices(total: int, samples: int) -> list[int]:
    """Evenly spaced unique frame indices, avoiding unreliable tail positions."""
    count = max(1, min(int(samples), int(total)))
    last_index = _last_seekable_frame_index(total)
    if last_index <= 0:
        return [0]

    spaced = np.linspace(0, last_index, count, dtype=int)
    indices: list[int] = []
    seen: set[int] = set()
    for raw in spaced:
        idx = int(raw)
        if idx not in seen:
            seen.add(idx)
            indices.append(idx)
    return indices


def _candidate_read_indices(requested_index: int, max_index: int) -> list[int]:
    out: list[int] = []
    seen: set[int] = set()
    for offset in _READ_RETRY_OFFSETS:
        idx = requested_index + offset
        if idx < 0 or idx > max_index:
            continue
        if idx in seen:
            continue
        seen.add(idx)
        out.append(idx)
        if len(out) >= len(_READ_RETRY_OFFSETS):
            break
    return out


def _read_frame_at(cap: cv2.VideoCapture, index: int) -> tuple[bool, object | None]:
    cap.set(cv2.CAP_PROP_POS_FRAMES, index)
    success, frame = cap.read()
    if not success or frame is None:
        return False, None
    return True, frame


class WaveRepDetector:
    def __init__(self, weights=None, device="cpu", samples=20):
        self.device = torch.device(device)
        self.samples = int(samples)

        if self.samples < 1:
            raise ValueError("samples must be at least 1")

        self.cropping = 504
        self.arc = "vit_base_patch14_reg4_dinov2.lvd142m"

        self.weights = str(
            Path(weights)
            if weights
            else BASE_DIR / "demo" / "weights" / "weights_dinov2_G4.ckpt"
        )

        self.transform = create_transform(self.cropping)

        self.model = create_model(
            self.weights,
            self.arc,
            self.cropping,
            self.device
        )

        self.model.eval()

    def analyze(self, video_path):
        video_path = str(Path(video_path).resolve())

        cap = cv2.VideoCapture(video_path)

        if not cap.isOpened():
            raise RuntimeError("Cannot open video: " + video_path)

        total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

        if total <= 0:
            cap.release()
            raise RuntimeError("Invalid video frame count")

        max_index = _last_seekable_frame_index(total)
        indices = _build_sample_indices(total, self.samples)

        frame_results = []
        failed_indices = []
        frame_recoveries = []
        used_indices: set[int] = set()

        try:
            with torch.inference_mode():
                for requested_index in indices:
                    success = False
                    frame = None
                    used_index = None

                    for candidate in _candidate_read_indices(requested_index, max_index):
                        if candidate in used_indices:
                            continue
                        ok, frame = _read_frame_at(cap, candidate)
                        if not ok:
                            continue
                        success = True
                        used_index = candidate
                        if candidate != requested_index:
                            frame_recoveries.append(
                                {
                                    "requested_index": int(requested_index),
                                    "used_index": int(candidate),
                                }
                            )
                        break

                    if not success or frame is None or used_index is None:
                        failed_indices.append(int(requested_index))
                        continue

                    used_indices.add(int(used_index))

                    frame = Image.fromarray(
                        cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                    )

                    tensor = self.transform(frame)
                    tensor = tensor.unsqueeze(0).to(self.device)

                    logit = self.model(tensor)[0, -1].item()

                    item = {
                        "index": int(used_index),
                        "logit": float(logit),
                    }
                    if used_index != requested_index:
                        item["requested_index"] = int(requested_index)
                    frame_results.append(item)

        finally:
            cap.release()

        if not frame_results:
            raise RuntimeError("No frames could be analyzed")

        logits = [item["logit"] for item in frame_results]

        mean_logit = float(np.mean(logits))
        ai_score = float(expit(mean_logit))

        # This threshold is provisional for prototype testing.
        prediction = (
            "AI-generated"
            if ai_score >= 0.5
            else "Real / Non-AI"
        )

        return {
            "model": "WaveRep G4",
            "video": Path(video_path).name,
            "total_frames": total,
            "requested_frames": len(indices),
            "processed_frames": len(frame_results),
            "failed_frames": failed_indices,
            "frame_recoveries": frame_recoveries,
            "status": (
                "complete"
                if len(frame_results) == len(indices)
                else "partial"
            ),
            "mean_logit": mean_logit,
            "ai_score": ai_score,
            "ai_percentage": round(ai_score * 100, 4),
            "prediction": prediction,
            "threshold": 0.5,
            "frame_results": frame_results,
        }


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("--video", required=True)
    parser.add_argument("--samples", type=int, default=20)
    parser.add_argument("--device", default="cpu")
    args = parser.parse_args()

    detector = WaveRepDetector(
        device=args.device,
        samples=args.samples
    )

    result = detector.analyze(args.video)

    print(json.dumps(result, indent=2))
