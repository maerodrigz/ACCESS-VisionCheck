"""
One-off Step 2 validation (run manually). Does not change .env.

Usage:
  cd access_backend
  python scripts/validate_probe_integration_step2.py
"""

from __future__ import annotations

import hashlib
import json
import os
import sys
import time
from io import BytesIO
from pathlib import Path
from unittest import mock

# Select PROBE for this process only (before app imports).
os.environ["AI_DETECTOR_BACKEND"] = "probe"

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from PIL import Image  # noqa: E402

from app.config import settings  # noqa: E402
from app.services import dedicated_ai_detector as det  # noqa: E402
from app.services import probe_dino_detector as probe_det  # noqa: E402
from app.services.ai_authenticity_detector import detect_ai_generated  # noqa: E402

TEST_IMAGE = Path.home() / "Desktop" / "fresh_validation" / "ai" / "gemini" / "e1e19a80-d7c6-4a54-a354-97aeef47fc18.jpeg"


def file_sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> None:
    if settings.ai_detector_backend != "probe":
        raise SystemExit(f"Expected probe backend in-process, got {settings.ai_detector_backend!r}")

    ckpt = probe_det.checkpoint_path()
    if not ckpt.is_file():
        raise SystemExit(f"BLOCKED: checkpoint missing at {ckpt}")

    if not TEST_IMAGE.is_file():
        raise SystemExit(f"BLOCKED: missing test image {TEST_IMAGE}")

    content = TEST_IMAGE.read_bytes()
    sha = file_sha256(TEST_IMAGE)
    with Image.open(BytesIO(content)) as im:
        w, h = im.size

    univfd_called = False
    probe_wrapper_called = False
    real_probe = probe_det.probe_ai_probability

    def traced_probe(content_bytes: bytes):
        nonlocal probe_wrapper_called
        probe_wrapper_called = True
        return real_probe(content_bytes)

    def block_univfd(_content: bytes):
        nonlocal univfd_called
        univfd_called = True
        raise AssertionError("UnivFD path must not run when backend=probe")

    t0 = time.perf_counter()
    with mock.patch.object(det, "_univfd_ai_probability", side_effect=block_univfd):
        with mock.patch.object(probe_det, "probe_ai_probability", side_effect=traced_probe):
            prob = det.dedicated_ai_probability(content)
    wall = time.perf_counter() - t0

    model = probe_det._get_model()
    infer_w = infer_h = None
    n_patches = None
    if model is not None:
        import torch

        _, probe_scores = probe_det._get_probe_inference()
        _, _, n_patches, (infer_w, infer_h) = probe_scores(
            model,
            content,
            device=torch.device("cpu"),
            patch_batch_size=probe_det.PATCH_BATCH_SIZE,
            max_long_edge=probe_det.max_long_edge(),
        )

    result = {
        "backend_in_process": det.active_ai_detector_backend(),
        "routing_probe_called": probe_wrapper_called,
        "routing_univfd_not_called": not univfd_called,
        "test_image": {
            "filepath": str(TEST_IMAGE),
            "ground_truth_folder": "fresh_validation/ai/gemini",
            "dimensions": f"{w}x{h}",
            "file_size_bytes": len(content),
            "sha256": sha,
        },
        "checkpoint": {
            "path": str(ckpt),
            "sha256": probe_det.EXPECTED_CHECKPOINT_SHA256,
            "verification": "passed" if model is not None else "failed_or_none",
        },
        "direct_probe": {
            "P_fake": prob,
            "inference_width": infer_w,
            "inference_height": infer_h,
            "patches": n_patches,
            "wall_seconds": wall,
            "error": None if prob is not None else "returned None",
        },
    }

    if prob is not None:
        auth = detect_ai_generated(content, file_name=TEST_IMAGE.name)
        result["authenticity_diagnostic"] = {
            "raw_probe_P_fake": prob,
            "fused_ai_probability": auth.get("probability"),
            "verdict": auth.get("verdict"),
            "confidence": auth.get("confidence"),
            "signals": auth.get("signals"),
        }

    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
