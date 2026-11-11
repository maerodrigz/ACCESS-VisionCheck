# CLIP noisiness controlled feasibility report

Generated (UTC): 2026-11-09T00:14:30.539164+00:00
Method: `clip_noisiness_antonyms_vitb32_openai`
Model: OpenCLIP `ViT-B-32` pretrained=`openai`
Prompts (fixed): `Noise-free image` / `noisy image`

## Scope honors

- Research-only under `research_clip_noise/`
- No production / Flutter / EfficientNet / sandbox / criteria changes
- No NR001–NR015 or frozen-pilot photographs or human ratings
- No 1–5 badge mapping; raw noisiness only
- One model, one prompt pair, one controlled run

## Development set

Synthetic procedural RGB panels; never NR001-015 or frozen pilot photographs.

Sources: DEV-FLAT, DEV-MILD, DEV-TEX. AWGN σ ∈ [0, 5, 10, 20, 40].

## Raw noisiness response (P(noisy image))

| Source | σ=0 | σ=5 | σ=10 | σ=20 | σ=40 | Spearman ρ | Monotone ↑ | Δ(40−0) |
|--------|----:|----:|-----:|-----:|-----:|-----------:|:----------:|--------:|
| DEV-FLAT | 0.2215 | 0.2463 | 0.2235 | 0.2312 | 0.1491 | -0.300 | no | -0.0724 |
| DEV-MILD | 0.2106 | 0.2865 | 0.2567 | 0.2446 | 0.2654 | 0.300 | no | 0.0548 |
| DEV-TEX | 0.2339 | 0.2583 | 0.2660 | 0.2886 | 0.2588 | 0.700 | no | 0.0249 |

Full table: `raw_noisiness_response.csv`

## Gate evaluation

- S1 flat Spearman ≥ 0.80: **FAIL** (ρ=-0.3)
- Flat monotonic nondecreasing: **FAIL**
- Directional consistency (≥2/3 sources positive ρ and Δ): **PASS** (2/3)

## Runtime and resources

- Device: `cpu`
- Model load: 850.428 s
- Inference mean/median/max: 217.31 / 214.88 / 249.93 ms
- Images scored: 15
- RSS before/after load/end (MB): None / None / None
- tracemalloc peak (MB): 146.08
- Wall time: 855.22 s

## Recommendation

**NO-GO**

Does not meet controlled-response gates; do not advance without a new approved plan.

A GO does **not** authorize production deployment or ACCESS badge mapping.

