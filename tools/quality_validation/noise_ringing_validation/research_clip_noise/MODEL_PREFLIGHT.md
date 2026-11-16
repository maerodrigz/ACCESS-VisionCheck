# CLIP noisiness feasibility — model preflight (before download)

**Date:** 2026-11-09  
**Purpose:** Verify source, license, size, and deps before the one-time download.

## Selected model (locked by feasibility report)

| Field | Value |
|-------|-------|
| Method | CLIP-IQA noisiness antonym scoring (Wang et al., AAAI 2023) |
| Implementation | Local OpenCLIP load + antonym softmax (**not** pyiqa, **not** IceClear CLIP-IQA code) |
| Backbone | OpenAI CLIP **ViT-B/32** via `open_clip` (`ViT-B-32`, `pretrained='openai'`) |
| Prompt pair (fixed) | `"Noise-free image"` / `"noisy image"` |
| Output | Raw noisiness = softmax probability of `"noisy image"` (higher = more noisy). No 1–5 mapping. |

## License

| Component | License / terms |
|-----------|-----------------|
| `open_clip_torch` package | MIT (mlfoundations/open_clip) |
| OpenAI CLIP ViT-B/32 weights | OpenAI CLIP release (research use; see OpenAI CLIP LICENSE) |
| pyiqa / IceClear CLIP-IQA | **Not used** (non-commercial packaging) |

## Download size (verified HEAD request)

| Asset | URL host | Content-Length |
|-------|----------|----------------|
| `ViT-B-32.pt` (openai) | `openaipublic.azureedge.net` | **353,976,522 bytes (~354 MB)** |

Disk free at preflight: ~22 GB. Size is acceptable for a one-time research download.

## Python dependencies

Already present in `access_backend/venv312`: PyTorch (CPU), torchvision, Pillow, numpy, huggingface_hub, timm.

To install for this research folder only: `open_clip_torch` (+ `ftfy`, `regex`, `tiktoken`, `wcwidth` as declared deps).

## Blockers that would stop the run

- Weight download > ~1 GB or disk free < 2 GB
- Unable to install OpenCLIP / load ViT-B/32
- Silent substitution with a different backbone

## Status

Preflight **PASS**. Proceed to install OpenCLIP and run the single controlled feasibility test.

## Post-run note

Single controlled run completed 2026-11-09. Outcome: **NO-GO** (see `CLIP_NOISE_FEASIBILITY_REPORT.md`). OpenCLIP logged a QuickGELU config warning; no second experiment was started.
