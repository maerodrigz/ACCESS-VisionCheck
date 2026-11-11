# CLIP noisiness controlled feasibility report

Generated (UTC): 2026-11-09T00:29:02.883462+00:00  
Method: `clip_noisiness_antonyms_vitb32_openai`  
Model: OpenCLIP `ViT-B-32` pretrained=`openai`  
Prompts (fixed): `Noise-free image` / `noisy image`  
Raw signal: `P(noisy image)` from antonym softmax (higher = more noisy). No 1–5 mapping.

## Preflight (before download)

| Check | Result |
|-------|--------|
| Source | OpenCLIP + OpenAI CLIP ViT-B/32 (not pyiqa / IceClear) |
| License path | open_clip_torch MIT; OpenAI CLIP weights via OpenCLIP |
| Weight size (HEAD on openai Azure URL) | ~354 MB (acceptable; ~22 GB free) |
| Deps | `open_clip_torch` installed into research venv |
| Incompatible / too large? | No hard blocker. OpenCLIP emitted a QuickGELU config warning; run continued once (no second experiment). |

See `MODEL_PREFLIGHT.md`.

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

Full table: `output/clip_noise_feasibility_20261109T002902Z/raw_noisiness_response.csv`

## Gate evaluation

- S1 flat Spearman ≥ 0.80: **FAIL** (ρ=-0.3)
- Flat monotonic nondecreasing: **FAIL**
- Directional consistency (≥2/3 sources positive ρ and Δ): **PASS** (2/3)

Observation: on the flat panel, noisiness **fell** at σ=40 relative to clean, i.e. the wrong direction for a usable noise amount signal.

## Runtime and resources

- Device: `cpu`
- Model load: 27.013 s
- Inference mean/median/max: 208.73 / 198.85 / 413.07 ms
- Images scored: 15
- Process RSS (Windows API): unavailable in this run
- tracemalloc peak: 145.93 MB
- Wall time: 31.82 s

## Recommendation

**NO-GO**

Controlled AWGN response is weak, non-monotonic, and fails the flat-ladder Spearman gate. Do not advance this CLIP noisiness antonym signal to further ACCESS evaluation without a new approved plan. Do not map to badges. Do not touch production.

A GO would only have meant eligibility for further independent evaluation, not validation or production approval.

