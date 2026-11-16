# Four-Criterion Video Quality Validation Report

**Date:** 2026-11-09  
**Scope:** Color Balance, Color Saturation, Motion Stability, Flickering  
**Mode:** Non-destructive (no DB writes, no scoring/API/UI/weight changes)

## Setup

| Item | Value |
|---|---|
| Source | Synthetic OpenCV still (colorful documentation-like blocks + texture + text) |
| Clip params | 640×360, 10 fps, 2.0 s, H.264 (`libx264`, CRF 18) |
| Evaluation | `evaluate_video(..., include_authenticity=False)` |
| Quality engine | **efficientnet-b0** on all clips (`opencv_fallback=false`) |
| Frame sampling | Existing FFmpeg pipeline, **4 frames** per clip |
| Determinism | 2 repeats per clip → **identical** four-criterion scores |
| Artifacts | `tools/quality_validation/video_four_criteria_validation/assets/` |
| Raw JSON | `out/four_criterion_video_validation.json` |

## Compact comparison table

| Criterion | Altered input | Baseline | Altered | Expected | Actual | Verdict |
|---|---|---:|---:|---|---|---|
| Color Balance | Strong global hue tint | 5 | 4 | lower | lower | **pass** |
| Color Balance | Temporal tint (2nd half) | 5 | 4 | lower | lower | **pass** (mid-frame caught tint) |
| Color Saturation | Desaturated | 5 | N/A | N/A or lower | N/A | **pass** |
| Color Saturation | Oversaturated | 5 | 3 | lower | lower | **pass** |
| Motion Stability | Geometric crop shake | 5 | 5 | lower | unchanged | **inconclusive** |
| Motion Stability | Alternating sharp/heavy blur | 5 | 4 | lower | lower | **pass** |
| Flickering | Mild FFmpeg brightness sine | 5 | 5 | lower | unchanged | **inconclusive** |
| Flickering | Extreme dark/bright alternation | 5 | 5 | lower | unchanged | **fail** (proxy insensitive) |

## Criterion verdicts

### Color Balance — functionally responsive; limited measurement validity
- Heuristic mid-frame cast estimate moves in the expected direction under strong tint (5→4).
- Coarse 1–5 + mild-cast band means strong synthetic tint only dropped one level (not to 2).
- Mid-frame-only design: temporal tint still scored 4 because a sampled mid frame landed in the tinted half; a tint confined to unsampled moments could be missed.

### Color Saturation — functionally responsive for intended bands
- Desaturation correctly yields **N/A** (muted/mono gate), not a punitive low score.
- Oversaturation drops 5→3 as designed.
- Not a measure of artistic quality; synthetic only.

### Motion Stability — proxy works only when sharpness varies
- Pure geometric shake (crop oscillation): **no score change** (sharpness deltas tiny).
- Alternating sharp vs heavy blur: **5→4** (ENET sharpness ~0.49→0.19 across samples).
- Does **not** measure camera motion directly; optical-flow-free sharpness jitter only.
- Soft-score bias + 4-frame sampling hide modest deltas.

### Flickering — functionally incorrect under EfficientNet brightness
- Mild oscillation: unchanged at 5 (sparse samples + soft score).
- Extreme dark/bright frames (pixel mean ~22 vs ~232; OpenCV brightness ~0.09 vs ~0.93): **still score 5**.
- Root cause: Flickering uses **ENET `brightness` head**, which barely moved (~0.54→0.58) despite large luminance swings. OpenCV mean brightness would have detected it.
- Sparse sampling further averages consecutive same-state pairs.

## Functional correctness vs measurement validity

| Criterion | Functional (code path runs, deterministic, expected gates) | Measurement validity (distinguishes real video conditions) |
|---|---|---|
| Color Balance | Yes for global mid-frame cast | Partial; mid-frame-only; coarse bands |
| Color Saturation | Yes for mute N/A and oversat | Partial; heuristic thresholds only |
| Motion Stability | Yes when sharpness varies | Weak for true shake without blur change |
| Flickering | Path runs; scores deterministic | **Poor under ENET** for luminance flicker |

These synthetic tests do **not** claim scientific accuracy or human-rater agreement.

## Limitations (cross-cutting)
1. Four-frame sampling misses high-frequency flicker/motion between samples.
2. Soft-score (`metric*0.5+0.42`) keeps many mid/high metrics at **5**.
3. Discrete 1–5 hides continuous metric movement until thresholds are crossed.
4. Video color uses a single mid extracted frame, not temporal aggregation.
5. No DB persistence; authenticity deferred in this run.
