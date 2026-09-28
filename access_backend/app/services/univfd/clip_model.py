"""CLIP:ViT-L/14 + linear head — mirrors UniversalFakeDetect models/clip_models.py."""

from __future__ import annotations

import torch.nn as nn

from app.services.univfd.clip.clip import load

UNIVFD_CLIP_ARCH = "ViT-L/14"
UNIVFD_FC_IN_FEATURES = 768


class CLIPModel(nn.Module):
    """Official UnivFD architecture: CLIP encode_image -> Linear(768, 1) logit."""

    def __init__(self, *, clip_backbone_path: str, num_classes: int = 1) -> None:
        super().__init__()
        self.model, _preprocess = load(clip_backbone_path, device="cpu", jit=False)
        self.fc = nn.Linear(UNIVFD_FC_IN_FEATURES, num_classes)

    def forward(self, x, return_feature: bool = False):
        features = self.model.encode_image(x)
        if return_feature:
            return features
        return self.fc(features)
