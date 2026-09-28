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
from app.services.efficientnet_synthetic_iqa import (  # noqa: E402
    labels_vector,
    synthesize_iqa_sample,
)


class SyntheticIQADataset(Dataset):
    def __init__(self, size: int = 512) -> None:
        self.size = size

    def __len__(self) -> int:
        return self.size

    def __getitem__(self, idx: int) -> tuple[torch.Tensor, torch.Tensor]:
        _ = idx
        img, label_map = synthesize_iqa_sample()
        tensor = torch.from_numpy(img).permute(2, 0, 1).float() / 255.0
        mean = torch.tensor([0.485, 0.456, 0.406]).view(3, 1, 1)
        std = torch.tensor([0.229, 0.224, 0.225]).view(3, 1, 1)
        tensor = (tensor - mean) / std
        return tensor, torch.tensor(labels_vector(label_map), dtype=torch.float32)


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
