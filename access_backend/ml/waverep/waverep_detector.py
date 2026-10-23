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

from utils import create_transform, create_model


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

        # Avoid the final reported frame because some files
        # cannot seek reliably to that frame.
        last_index = max(0, total - 2)

        indices = np.linspace(
            0,
            last_index,
            min(self.samples, total),
            dtype=int
        )

        frame_results = []
        failed_indices = []

        try:
            with torch.inference_mode():
                for index in indices:
                    index = int(index)

                    cap.set(cv2.CAP_PROP_POS_FRAMES, index)
                    success, frame = cap.read()

                    if not success:
                        failed_indices.append(index)
                        continue

                    frame = Image.fromarray(
                        cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                    )

                    tensor = self.transform(frame)
                    tensor = tensor.unsqueeze(0).to(self.device)

                    logit = self.model(tensor)[0, -1].item()

                    frame_results.append({
                        "index": index,
                        "logit": float(logit)
                    })

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
            "frame_results": frame_results
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
