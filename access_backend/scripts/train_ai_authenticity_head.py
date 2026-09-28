"""
Train EfficientNet-B0 AI authenticity head on synthetic natural vs AI-like images.

Run once after installing torch/torchvision:
  cd access_backend
  python scripts/train_ai_authenticity_head.py
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

from app.services.ai_authenticity_model import AiAuthenticityNet  # noqa: E402

WEIGHTS_PATH = ROOT / "ml" / "ai_authenticity_head.pt"


class SyntheticAuthenticityDataset(Dataset):
    def __init__(self, size: int = 640) -> None:
        self.size = size

    def __len__(self) -> int:
        return self.size

    def __getitem__(self, idx: int) -> tuple[torch.Tensor, torch.Tensor]:
        _ = idx
        is_ai = random.random() > 0.5
        img = _synthesize_ai_like() if is_ai else _synthesize_natural()
        tensor = torch.from_numpy(img).permute(2, 0, 1).float() / 255.0
        mean = torch.tensor([0.485, 0.456, 0.406]).view(3, 1, 1)
        std = torch.tensor([0.229, 0.224, 0.225]).view(3, 1, 1)
        tensor = (tensor - mean) / std
        label = torch.tensor([1.0 if is_ai else 0.0], dtype=torch.float32)
        return tensor, label


def _base_scene(h: int = 224, w: int = 224) -> np.ndarray:
    base = np.zeros((h, w, 3), dtype=np.uint8)
    base[:, :] = np.random.randint(30, 200, size=3)
    for _ in range(random.randint(4, 12)):
        x1, y1 = random.randint(0, w - 30), random.randint(0, h - 30)
        x2, y2 = x1 + random.randint(12, 70), y1 + random.randint(12, 70)
        cv2.rectangle(
            base,
            (x1, y1),
            (x2, y2),
            color=(int(np.random.randint(0, 255)), int(np.random.randint(0, 255)), int(np.random.randint(0, 255))),
            thickness=-1 if random.random() > 0.4 else 2,
        )
    cv2.line(base, (0, random.randint(0, h)), (w, random.randint(0, h)), (255, 255, 255), 2)
    return base


def _synthesize_natural() -> np.ndarray:
    base = _base_scene()
    if random.random() > 0.3:
        std = random.uniform(2.5, 12.0)
        noise = np.random.normal(0, std, base.shape).astype(np.float32)
        base = np.clip(base.astype(np.float32) + noise, 0, 255).astype(np.uint8)
    if random.random() > 0.5:
        quality = random.randint(55, 88)
        ok, encoded = cv2.imencode(".jpg", base, [int(cv2.IMWRITE_JPEG_QUALITY), quality])
        if ok:
            base = cv2.imdecode(encoded, cv2.IMREAD_COLOR)
    if random.random() > 0.6:
        sigma = random.uniform(0.2, 1.2)
        k = int(max(3, round(sigma * 4))) | 1
        base = cv2.GaussianBlur(base, (k, k), sigma)
    return base


def _synthesize_ai_like() -> np.ndarray:
    base = _base_scene()
    base = cv2.bilateralFilter(base, d=9, sigmaColor=75, sigmaSpace=75)
    if random.random() > 0.25:
        amount = random.uniform(1.4, 2.8)
        blurred = cv2.GaussianBlur(base, (0, 0), 1.0)
        base = np.clip(cv2.addWeighted(base, amount, blurred, 1 - amount, 0), 0, 255).astype(np.uint8)
    if random.random() > 0.35:
        base = cv2.resize(base, (112, 112), interpolation=cv2.INTER_AREA)
        base = cv2.resize(base, (224, 224), interpolation=cv2.INTER_CUBIC)
    if random.random() > 0.4:
        base = cv2.GaussianBlur(base, (3, 3), 0.4)
    return base


def train(*, epochs: int = 5, batch_size: int = 16, samples: int = 768) -> Path:
    device = torch.device("cpu")
    model = AiAuthenticityNet().to(device)

    for param in model.features.parameters():
        param.requires_grad = False

    loader = DataLoader(SyntheticAuthenticityDataset(samples), batch_size=batch_size, shuffle=True)
    criterion = nn.BCELoss()
    optimizer = torch.optim.Adam(
        list(model.head.parameters()) + list(model.dropout.parameters()),
        lr=1e-3,
    )

    model.train()
    for epoch in range(epochs):
        total_loss = 0.0
        correct = 0
        total = 0
        for batch_x, batch_y in loader:
            batch_x = batch_x.to(device)
            batch_y = batch_y.to(device)
            optimizer.zero_grad()
            pred = model(batch_x)
            loss = criterion(pred, batch_y)
            loss.backward()
            optimizer.step()
            total_loss += float(loss.item())
            predicted = (pred >= 0.5).float()
            correct += int((predicted == batch_y).sum().item())
            total += batch_y.numel()
        acc = correct / max(total, 1)
        print(f"epoch {epoch + 1}/{epochs}  loss={total_loss / len(loader):.4f}  acc={acc:.3f}")

    WEIGHTS_PATH.parent.mkdir(parents=True, exist_ok=True)
    torch.save(model.state_dict(), WEIGHTS_PATH)
    print(f"saved {WEIGHTS_PATH}")
    return WEIGHTS_PATH


if __name__ == "__main__":
    train()
