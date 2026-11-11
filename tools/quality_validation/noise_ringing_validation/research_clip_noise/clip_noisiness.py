"""Research-only CLIP noisiness antonym scorer (no production use).

Method: CLIP-IQA-style antonym prompts on OpenAI CLIP ViT-B/32 via OpenCLIP.
Fixed prompts: 'Noise-free image' / 'noisy image'. No prompt search.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

import torch
from PIL import Image

PROMPT_CLEAN = "Noise-free image"
PROMPT_NOISY = "noisy image"
MODEL_NAME = "ViT-B-32"
PRETRAINED = "openai"
METHOD_ID = "clip_noisiness_antonyms_vitb32_openai"


@dataclass(frozen=True)
class NoisinessResult:
    noisiness: float  # P(noisy); higher = more noisy
    noise_free: float  # P(Noise-free)
    model_id: str
    prompts: tuple[str, str]


class ClipNoisinessEvaluator:
    """Lazy-loaded OpenCLIP ViT-B/32 noisiness scorer."""

    def __init__(self, device: str | None = None) -> None:
        self.device = device or ("cuda" if torch.cuda.is_available() else "cpu")
        self._model: Any = None
        self._preprocess: Any = None
        self._tokenizer: Any = None
        self._text_features: torch.Tensor | None = None

    def load(self) -> None:
        if self._model is not None:
            return
        import open_clip

        model, _, preprocess = open_clip.create_model_and_transforms(
            MODEL_NAME,
            pretrained=PRETRAINED,
            device=self.device,
        )
        model.eval()
        tokenizer = open_clip.get_tokenizer(MODEL_NAME)
        tokens = tokenizer([PROMPT_CLEAN, PROMPT_NOISY]).to(self.device)
        with torch.no_grad():
            text_features = model.encode_text(tokens)
            text_features = text_features / text_features.norm(dim=-1, keepdim=True)
        self._model = model
        self._preprocess = preprocess
        self._tokenizer = tokenizer
        self._text_features = text_features

    @torch.inference_mode()
    def score_pil(self, image: Image.Image) -> NoisinessResult:
        self.load()
        assert self._model is not None and self._preprocess is not None
        assert self._text_features is not None
        rgb = image.convert("RGB")
        tensor = self._preprocess(rgb).unsqueeze(0).to(self.device)
        image_features = self._model.encode_image(tensor)
        image_features = image_features / image_features.norm(dim=-1, keepdim=True)
        logits = (100.0 * image_features @ self._text_features.T).squeeze(0)
        probs = torch.softmax(logits, dim=-1)
        noise_free = float(probs[0].item())
        noisiness = float(probs[1].item())
        return NoisinessResult(
            noisiness=noisiness,
            noise_free=noise_free,
            model_id=METHOD_ID,
            prompts=(PROMPT_CLEAN, PROMPT_NOISY),
        )
