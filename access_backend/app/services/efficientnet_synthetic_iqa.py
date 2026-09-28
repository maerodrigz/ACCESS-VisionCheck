"""Synthetic IQA samples for training and benchmarking EfficientNet-B0."""

from __future__ import annotations

import random
from typing import Any

import cv2
import numpy as np

from app.services.efficientnet_b0_scorer import CRITERION_KEYS


def synthesize_iqa_sample(*, rng: random.Random | None = None) -> tuple[np.ndarray, dict[str, float]]:
    """Build one 224x224 image with known 0-1 criterion targets."""
    r = rng or random.Random()
    h = w = 224
    base = np.zeros((h, w, 3), dtype=np.uint8)
    color = np.array([r.randint(40, 219) for _ in range(3)], dtype=np.uint8)
    base[:, :] = color

    for _ in range(r.randint(3, 10)):
        x1, y1 = r.randint(0, w - 40), r.randint(0, h - 40)
        x2, y2 = x1 + r.randint(10, 60), y1 + r.randint(10, 60)
        cv2.rectangle(
            base,
            (x1, y1),
            (x2, y2),
            color=(int(r.randint(0, 255)), int(r.randint(0, 255)), int(r.randint(0, 255))),
            thickness=-1 if r.random() > 0.5 else 2,
        )
    cv2.line(base, (0, r.randint(0, h)), (w, r.randint(0, h)), (255, 255, 255), 2)

    blur_amount = r.uniform(0, 1)
    sigma = blur_amount * 3.5
    if sigma > 0.05:
        k = int(max(3, round(sigma * 4))) | 1
        base = cv2.GaussianBlur(base, (k, k), sigma)

    noise_amount = r.uniform(0, 1)
    if noise_amount > 0.05:
        std = noise_amount * 35
        noise = np.fromiter(
            (r.gauss(0, std) for _ in range(base.size)),
            dtype=np.float32,
            count=base.size,
        ).reshape(base.shape)
        base = np.clip(base.astype(np.float32) + noise, 0, 255).astype(np.uint8)

    brightness_shift = r.uniform(-0.35, 0.35)
    base = np.clip(base.astype(np.float32) * (1 + brightness_shift) + brightness_shift * 40, 0, 255).astype(np.uint8)
    brightness_val = float(np.mean(cv2.cvtColor(base, cv2.COLOR_BGR2GRAY)) / 255.0)

    contrast_amount = r.uniform(0.3, 1.0)
    base = np.clip((base.astype(np.float32) - 127.5) * contrast_amount + 127.5, 0, 255).astype(np.uint8)
    contrast_val = float(np.std(cv2.cvtColor(base, cv2.COLOR_BGR2GRAY)) / 72.0)

    blocking_amount = r.uniform(0, 1)
    if blocking_amount > 0.2:
        quality = max(5, int(100 - blocking_amount * 90))
        ok, encoded = cv2.imencode(".jpg", base, [int(cv2.IMWRITE_JPEG_QUALITY), quality])
        if ok:
            base = cv2.imdecode(encoded, cv2.IMREAD_COLOR)

    ringing_amount = r.uniform(0, 1)
    if ringing_amount > 0.25:
        amount = 1 + ringing_amount * 2.5
        blurred = cv2.GaussianBlur(base, (0, 0), 1.0)
        base = np.clip(cv2.addWeighted(base, amount, blurred, 1 - amount, 0), 0, 255).astype(np.uint8)

    labels = {
        "sharpness": float(np.clip(1.0 - blur_amount, 0, 1)),
        "blur": float(np.clip(blur_amount, 0, 1)),
        "noise": float(np.clip(noise_amount, 0, 1)),
        "brightness": brightness_val,
        "contrast": float(min(contrast_val, 1.0)),
        "blocking_artifacts": float(np.clip(blocking_amount, 0, 1)),
        "ringing_artifacts": float(np.clip(ringing_amount, 0, 1)),
    }
    return base, labels


def encode_jpeg_bgr(image_bgr: np.ndarray, *, quality: int = 92) -> bytes:
    ok, encoded = cv2.imencode(".jpg", image_bgr, [int(cv2.IMWRITE_JPEG_QUALITY), quality])
    if not ok:
        raise RuntimeError("Failed to encode synthetic JPEG")
    return encoded.tobytes()


def labels_vector(labels: dict[str, float]) -> list[float]:
    return [float(labels[key]) for key in CRITERION_KEYS]
