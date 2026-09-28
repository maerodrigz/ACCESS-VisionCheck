"""Standalone PROBE-DINOv2 inference (official patch-mean-logit + sigmoid)."""

from __future__ import annotations

import sys
from io import BytesIO
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
import torchvision.transforms as transforms
from PIL import Image

_PROBE_ROOT = Path(__file__).resolve().parent
_VENDOR = _PROBE_ROOT / "vendor_lib"
if str(_VENDOR) not in sys.path:
    sys.path.insert(0, str(_VENDOR))

from transformers import AutoConfig, AutoModel  # noqa: E402

# Official util (evaluation defaults); util imports matplotlib but unused on infer path
sys.path.insert(0, str(_PROBE_ROOT / "official_detector"))
from util import data_augment, pad_image  # noqa: E402

CROP_SIZE = 336
IMAGENET_MEAN = [0.485, 0.456, 0.406]
IMAGENET_STD = [0.229, 0.224, 0.225]
HF_MODEL_ID = "facebook/dinov2-with-registers-large"

DEFAULT_AUG_PARAMS = {
    "blur_prob": 0.0,
    "blur_sig_min": 0.0,
    "blur_sig_max": 3.0,
    "blur_sig": 0.0,
    "jpeg_prob": 0.0,
    "jpeg_quality_min": 60,
    "jpeg_quality_max": 100,
    "jpeg_quality": 100,
    "cutout_prob": 0.0,
    "cutout_ratio_min": 0.1,
    "cutout_ratio_max": 0.5,
    "noise_prob": 0.0,
    "noise_std_min": 0.0,
    "noise_std_max": 50.0,
    "noise_std": 0.0,
    "resize_prob": 0.0,
    "resize_scale_min": 0.5,
    "resize_scale_max": 2.0,
    "resize_scale": 1.0,
    "pad_mode": "repeat",
}


class DinoClassifier(nn.Module):
    """Matches Amamiya-C/PROBE-AIGI-Detection Detector/model/dino_classifier.py (linear head)."""

    def __init__(self, model_id: str = HF_MODEL_ID, *, hf_cache: str | None = None):
        super().__init__()
        config = AutoConfig.from_pretrained(model_id, cache_dir=hf_cache)
        self.backbone = AutoModel.from_config(config)
        self.fc = nn.Linear(config.hidden_size, 1)

    def forward(self, input: torch.Tensor) -> torch.Tensor:
        outputs = self.backbone(input)
        sequence_output = outputs[0]
        cls_token = sequence_output[:, 0]
        return self.fc(cls_token)


def load_probe_dino_checkpoint(ckpt_path: Path, *, hf_cache: Path) -> DinoClassifier:
    model = DinoClassifier(hf_cache=str(hf_cache))
    checkpoint = torch.load(str(ckpt_path), map_location="cpu", weights_only=False)
    if "model_state_dict" not in checkpoint:
        raise ValueError(f"Unexpected checkpoint keys: {list(checkpoint.keys())}")
    model.load_state_dict(checkpoint["model_state_dict"], strict=True)
    model.eval()
    return model


def _resize_long_edge(image: Image.Image, max_long_edge: int) -> Image.Image:
    """Downscale so max(width, height) == max_long_edge; never upscale."""
    width, height = image.size
    long_edge = max(width, height)
    if long_edge <= max_long_edge:
        return image
    scale = max_long_edge / float(long_edge)
    new_w = max(1, int(round(width * scale)))
    new_h = max(1, int(round(height * scale)))
    return image.resize((new_w, new_h), Image.Resampling.LANCZOS)


def generate_sliding_patches(image: Image.Image, crop_size: int, transform) -> torch.Tensor:
    """Official evaluate_dino.py sliding patches (stride = crop_size)."""
    img_tensor = transform(image)
    _c, h, w = img_tensor.shape
    ps = crop_size
    stride = crop_size
    if h < ps or w < ps:
        return torch.zeros(0, 3, ps, ps)
    patches = img_tensor.unfold(1, ps, stride).unfold(2, ps, stride)
    patches = patches.permute(1, 2, 0, 3, 4).contiguous()
    patches = patches.view(-1, 3, ps, ps)
    return patches


def probe_image_scores(
    model: DinoClassifier,
    content: bytes,
    *,
    device: torch.device,
    patch_batch_size: int = 8,
    max_long_edge: int | None = None,
) -> tuple[float, float, int, tuple[int, int]]:
    """
    Returns (mean_logit, sigmoid(mean_logit), num_patches, (width, height)).
    P(fake) = sigmoid(mean patch logits).
    (width, height) are dimensions used for inference (after optional max_long_edge resize).
    """
    image = Image.open(BytesIO(content)).convert("RGB")
    if max_long_edge is not None:
        image = _resize_long_edge(image, max_long_edge)
    width, height = image.size
    aug = data_augment(image, data_augment_params=DEFAULT_AUG_PARAMS, mode="fix", crop_size=CROP_SIZE)
    transform = transforms.Compose(
        [transforms.ToTensor(), transforms.Normalize(mean=IMAGENET_MEAN, std=IMAGENET_STD)]
    )
    patches = generate_sliding_patches(aug, CROP_SIZE, transform)
    num_patches = int(patches.shape[0])
    if num_patches == 0:
        return 0.0, float(torch.sigmoid(torch.tensor(0.0)).item()), 0, (width, height)

    logits_list: list[torch.Tensor] = []
    with torch.no_grad():
        for start in range(0, num_patches, patch_batch_size):
            batch = patches[start : start + patch_batch_size].to(device)
            logit = model(batch).squeeze(-1)
            logits_list.append(logit.detach().cpu())
    all_logits = torch.cat(logits_list, dim=0)
    mean_logit = float(all_logits.mean().item())
    prob = float(torch.sigmoid(torch.tensor(mean_logit)).item())
    return mean_logit, prob, num_patches, (width, height)
