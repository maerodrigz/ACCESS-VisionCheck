# SPAQ 200 ACCESS technical scorer evaluation

**Generated:** 2026-11-07T08:01:07.145470+00:00  
**Status:** `scored`  
**n:** 200 / 200 successful, all EfficientNet-B0, 0 OpenCV fallback, 0 failures.

Research only. Production scoring, weights, API, Flutter, XP, authenticity, Gemini, and MUSIQ were not changed. Human ratings were not rewritten. No retraining, fine-tuning, or recalibration. MAE was not used.

Per-image CSV: `workspace/datasets/spaq/output/run_001/spaq_200_machine_scores.csv`  
Metrics JSON: `workspace/datasets/spaq/output/run_001/spaq_200_metrics.json`

Because every image used EfficientNet with no fallback, **all-ok and EfficientNet-only tables are identical**.

---

## Inference / fallback / errors

| Group | n |
|-------|---|
| Images presented | 200 |
| Successful (`analysis_status=ok`) | 200 |
| Failed (kept in CSV if any) | 0 |
| EfficientNet, no fallback | 200 |
| OpenCV fallback | 0 |

Engine availability at start: EfficientNet true (`efficientnet-b0` 1.0, `access_backend/ml/efficientnet_b0_heads.pt`), OpenCV true. No image was silently dropped.

---

## Primary correlations

SPAQ values remain 0-100. ACCESS values are member-facing integer badges (overall is the mean of seven badges). Pearson mixes those scales. Spearman is rank-based. 95% CIs are percentile bootstrap, seed `20261107`, 1000 resamples. n=200 for every primary pair.

| Pair | Comparability | Pearson r (95% CI) | Spearman r (95% CI) | Badge unique values |
|------|---------------|--------------------|---------------------|---------------------|
| SPAQ MOS vs ACCESS overall | related proxy | **-0.080** (-0.230, 0.054) | **-0.067** (-0.221, 0.066) | 8 (range 3.00–4.00) |
| SPAQ noisiness inverted (`100-raw`) vs ACCESS Noise | after invert | **0.279** (0.145, 0.420) | **0.264** (0.130, 0.396) | 3 |
| SPAQ Sharpness vs ACCESS Sharpness | related proxy | **0.081** (-0.047, 0.206) | **0.086** (-0.041, 0.215) | 3 |
| SPAQ Brightness vs ACCESS Brightness | related proxy | **0.063** (-0.083, 0.199) | **0.045** (-0.098, 0.175) | 3 |
| SPAQ Contrast vs ACCESS Contrast | related proxy | **-0.025** (-0.139, 0.089) | **-0.028** (-0.150, 0.098) | 3 |

p-values: MOS 0.34 (Spearman); Noise 0.00016; Sharpness 0.23; Brightness 0.53; Contrast 0.70.

### Noise direction check

| Series vs ACCESS Noise | Spearman r |
|------------------------|------------|
| SPAQ noisiness uninverted (high = more noise) | **-0.264** |
| `100 - noisiness` (high = cleaner) | **+0.264** |

The sign flip matches the intended polarity: ACCESS Noise is a cleanliness badge. The invert is therefore the correct primary pairing. The association is **weak**, not a claim of human-level accuracy.

---

## Badge distributions (n=200)

No head was constant, but all labeled badges are heavily tied. Score 1 never appeared. Overall never left 3.00–4.00.

| Score | n unique | min–max | mean | histogram 1–5 | Floor@1 | Ceiling@5 |
|-------|----------|---------|------|---------------|---------|-----------|
| overall | 8 | 3.00–4.00 | 3.50 | (mean of badges; top 3.57×60, 3.43×58) | n/a | n/a |
| Sharpness | 3 | 2–4 | 3.22 | 0 / 1 / 154 / 45 / 0 | 0 | 0 |
| Noise | 3 | 3–5 | 3.69 | 0 / 0 / 67 / 129 / 4 | 0 | 4 |
| Brightness | 3 | 3–5 | 4.72 | 0 / 0 / 2 / 52 / **146** | 0 | **146** |
| Contrast | 3 | 2–4 | 2.93 | 0 / 20 / 174 / 6 / 0 | 0 | 0 |

Unlabeled (machine only; **no SPAQ human correlation**):

| Criterion | unique | min–max | histogram 1–5 |
|-----------|--------|---------|---------------|
| Blur | 3 | 2–4 | 0 / 2 / 180 / 18 / 0 |
| Blocking Artifacts | 2 | 3–4 | 0 / 0 / 131 / 69 / 0 |
| Ringing Artifacts | 2 | 3–4 | 0 / 0 / 94 / 106 / 0 |

Brightness is ceiling-limited (73% at 5). Contrast and Sharpness sit on 3. Overall std is 0.19 versus SPAQ MOS std 20.7. That compression is the main reason MOS-vs-overall rank correlation is indistinguishable from zero.

---

## Secondary raw-head diagnostics

Raw 0–1 EfficientNet heads from the same inference (not shown to members). Each raw series had 200 unique values (no integer ties).

| Pair | Pearson r | Spearman r (95% CI) |
|------|-----------|---------------------|
| SPAQ MOS vs mean of seven raw heads | 0.189 | 0.171 (0.037, 0.302) |
| SPAQ noisiness vs raw noise **amount** (no invert) | 0.293 | 0.290 (0.161, 0.419) |
| SPAQ Sharpness vs raw sharpness | 0.117 | 0.117 (-0.017, 0.254) |
| SPAQ Brightness vs raw brightness | -0.073 | -0.075 (-0.227, 0.069) |
| SPAQ Contrast vs raw contrast | -0.125 | -0.147 (-0.270, -0.007) |

The weak MOS association that exists on **raw** mean heads (Spearman 0.17, CI excludes 0) **disappears** after `_soft_score` integer badges and averaging (Spearman -0.07, CI includes 0). That is a quantization / mapping limitation, not a new training run.

Raw contrast vs SPAQ contrast is weakly **negative**. Do not treat that as a validated inverse without a construct review. No recalibration was applied.

---

## What these results support

1. On this MOS-stratified 200-image SPAQ subset, ACCESS **Noise** badges have a **weak, correctly oriented** association with SPAQ noisiness after invert (Spearman 0.26, CI 0.13–0.40).
2. ACCESS member-facing badges are **compressed**: typically two or three integers, Brightness mostly 5, overall stuck in 3–4. That is measured, not hypothetical.
3. EfficientNet ran on all 200 photos; fallback did not confound the tables.

## What they do not support

1. Human-rated validation of **Blur, Blocking, or Ringing**.
2. Human-rated validation of **Sharpness, Brightness, Contrast, or overall quality**. Those Spearman CIs include 0 (except raw-head MOS, which is still weak and is not the member badge).
3. Any claim that ACCESS overall_score tracks SPAQ MOS. The point estimate is slightly negative and not distinguishable from zero.
4. Exact human-rating accuracy, calibration, or a mandate to retrain. High correlation was not observed except the weak Noise pair. MAE was not computed.

## Most important accuracy limitations

1. **Badge quantization:** `_soft_score` plus 1–5 integers collapse continuous heads. MOS association present at raw-mean 0.17 is gone at overall badge -0.07.
2. **Ceiling / pile-up:** Brightness 146/200 at 5; Contrast 174/200 at 3; Sharpness 154/200 at 3; Noise 129/200 at 4. Rank tests have little machine variation to work with.
3. **Construct mismatch:** SPAQ attributes are lab opinions on 0–100; ACCESS badges come from synthetic-distortion EfficientNet heads, not SPAQ raters.
4. **Training overlap:** heads were trained on `SyntheticIQADataset`, not SPAQ. This is an out-of-domain check.
5. **Subset:** n=200 of 11,125, MOS-stratified (seed 20261107), not a random full-database estimate.
6. **Scale:** Pearson compares 0–100 humans to 1–5 integers. Spearman is the more appropriate rank summary here.

No accuracy improvements were implemented from this evaluation.
