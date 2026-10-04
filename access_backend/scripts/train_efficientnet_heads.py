"""
Train EfficientNet-B0 criterion heads on synthetic degradations.

Run once after installing torch/torchvision:
  cd access_backend
  python scripts/train_efficientnet_heads.py
"""

from __future__ import annotations

import random
import sys
from pathlib import Path

import cv2
import numpy as np
import torch
import torch.nn as nn
from torch.utils.data import DataLoader, Dataset

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from app.services.efficientnet_b0_scorer import (  # noqa: E402
    CRITERION_KEYS,
    EfficientNetB0IQA,
    weights_path,
)


class SyntheticIQADataset(Dataset):
    def __init__(self, size: int = 512) -> None:
        self.size = size

    def __len__(self) -> int:
        return self.size

    def __getitem__(self, idx: int) -> tuple[torch.Tensor, torch.Tensor]:
        _ = idx
        img, labels = _synthesize_sample()
        tensor = torch.from_numpy(img).permute(2, 0, 1).float() / 255.0
        mean = torch.tensor([0.485, 0.456, 0.406]).view(3, 1, 1)
        std = torch.tensor([0.229, 0.224, 0.225]).view(3, 1, 1)
        tensor = (tensor - mean) / std
        return tensor, torch.tensor(labels, dtype=torch.float32)


def _synthesize_sample() -> tuple[np.ndarray, list[float]]:
    h = w = 224
    base = np.zeros((h, w, 3), dtype=np.uint8)
    color = np.random.randint(40, 220, size=3)
    base[:, :] = color

    # Structured content (edges/textures help EfficientNet respond to blur/noise).
    for _ in range(random.randint(3, 10)):
        x1, y1 = random.randint(0, w - 40), random.randint(0, h - 40)
        x2, y2 = x1 + random.randint(10, 60), y1 + random.randint(10, 60)
        cv2.rectangle(
            base,
            (x1, y1),
            (x2, y2),
            color=(int(np.random.randint(0, 255)), int(np.random.randint(0, 255)), int(np.random.randint(0, 255))),
            thickness=-1 if random.random() > 0.5 else 2,
        )
    cv2.line(base, (0, random.randint(0, h)), (w, random.randint(0, h)), (255, 255, 255), 2)

    blur_amount = random.uniform(0, 1)
    sigma = blur_amount * 3.5
    if sigma > 0.05:
        k = int(max(3, round(sigma * 4))) | 1
        base = cv2.GaussianBlur(base, (k, k), sigma)

    noise_amount = random.uniform(0, 1)
    if noise_amount > 0.05:
        std = noise_amount * 35
        noise = np.random.normal(0, std, base.shape).astype(np.float32)
        base = np.clip(base.astype(np.float32) + noise, 0, 255).astype(np.uint8)

    brightness_shift = random.uniform(-0.35, 0.35)
    base = np.clip(base.astype(np.float32) * (1 + brightness_shift) + brightness_shift * 40, 0, 255).astype(np.uint8)
    brightness_val = float(np.mean(cv2.cvtColor(base, cv2.COLOR_BGR2GRAY)) / 255.0)

    contrast_amount = random.uniform(0.3, 1.0)
    base = np.clip((base.astype(np.float32) - 127.5) * contrast_amount + 127.5, 0, 255).astype(np.uint8)
    contrast_val = float(np.std(cv2.cvtColor(base, cv2.COLOR_BGR2GRAY)) / 72.0)

    blocking_amount = random.uniform(0, 1)
    if blocking_amount > 0.2:
        quality = max(5, int(100 - blocking_amount * 90))
        ok, encoded = cv2.imencode(".jpg", base, [int(cv2.IMWRITE_JPEG_QUALITY), quality])
        if ok:
            base = cv2.imdecode(encoded, cv2.IMREAD_COLOR)

    ringing_amount = random.uniform(0, 1)
    if ringing_amount > 0.25:
        amount = 1 + ringing_amount * 2.5
        blurred = cv2.GaussianBlur(base, (0, 0), 1.0)
        base = np.clip(cv2.addWeighted(base, amount, blurred, 1 - amount, 0), 0, 255).astype(np.uint8)

    sharpness = float(np.clip(1.0 - blur_amount, 0, 1))
    blur = float(np.clip(blur_amount, 0, 1))
    noise = float(np.clip(noise_amount, 0, 1))
    blocking = float(np.clip(blocking_amount, 0, 1))
    ringing = float(np.clip(ringing_amount, 0, 1))

    labels = [sharpness, blur, noise, brightness_val, min(contrast_val, 1.0), blocking, ringing]
    return base, labels


def train(*, epochs: int = 4, batch_size: int = 16, samples: int = 640) -> Path:
    device = torch.device("cpu")
    model = EfficientNetB0IQA().to(device)

    for param in model.features.parameters():
        param.requires_grad = False

    loader = DataLoader(SyntheticIQADataset(samples), batch_size=batch_size, shuffle=True)
    criterion = nn.MSELoss()
    optimizer = torch.optim.Adam(model.head.parameters(), lr=1e-3)

    model.train()
    for epoch in range(epochs):
        total_loss = 0.0
        for batch_x, batch_y in loader:
            batch_x = batch_x.to(device)
            batch_y = batch_y.to(device)
            optimizer.zero_grad()
            pred = model(batch_x)
            loss = criterion(pred, batch_y)
            loss.backward()
            optimizer.step()
            total_loss += float(loss.item())
        print(f"epoch {epoch + 1}/{epochs}  loss={total_loss / len(loader):.4f}")

    out = weights_path()
    out.parent.mkdir(parents=True, exist_ok=True)
    torch.save(model.state_dict(), out)
    print(f"saved {out}")
    return out


if __name__ == "__main__":
    train()
