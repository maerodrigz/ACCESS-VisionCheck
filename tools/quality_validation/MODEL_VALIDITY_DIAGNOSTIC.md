# ACCESS VisionCheck — EfficientNet-B0 model validity diagnostic

**Status:** Inspection only. No retraining, no weight changes, no production scoring edits, no database writes.

**This is not a scientific validation of EfficientNet-B0.** It explains why current technical quality scores disagree with KonIQ-10k published overall MOS.

Sources: `access_backend/scripts/train_efficientnet_heads.py`, `access_backend/app/services/efficientnet_b0_scorer.py`, `access_backend/app/services/media_evaluator.py`, `access_backend/ml/efficientnet_b0_heads.pt`, Run 001 `workspace/datasets/koniq10k/metadata/output/run_001/`, Run 002 `workspace/datasets/koniq10k/run_002/output/`.

---

## 1. Confirmed findings (with evidence)

### 1.1 Training data are synthetic, not human-rated photographs

The training script states this in its module docstring: "Train EfficientNet-B0 criterion heads on synthetic degradations."

`SyntheticIQADataset` builds 224×224 canvases filled with a random solid color, random rectangles, and a line (`train_efficientnet_heads.py`). It then applies procedural Gaussian blur, Gaussian noise, brightness/contrast scaling, JPEG re-encode, and unsharp-style ringing.

Labels are **not** human MOS and **not** KonIQ/SPAQ/LIVE scores. They are the random degradation amounts plus two OpenCV statistics:

- sharpness = `1 - blur_amount`
- blur = `blur_amount`
- noise = `noise_amount`
- brightness = mean grayscale / 255
- contrast = grayscale std / 72, clipped to 1
- blocking / ringing = the random amounts used to degrade the canvas

There is no loader for real photographs, no KonIQ CSV, and no ACCESS criterion rater files in the training script. The backbone is ImageNet-1K (`EfficientNet_B0_Weights.IMAGENET1K_V1`). Only the linear head is trained (`features.requires_grad = False`). Default run: **640 samples, 4 epochs, batch 16, Adam 1e-3, MSE, CPU**.

**Conclusion:** The heads were trained to regress synthetic degradation knobs on cartoon-like 224×224 patches, not to predict human overall quality on real photos.

### 1.2 Architecture and weights

Inference model (`efficientnet_b0_scorer.py`):

- EfficientNet-B0 ImageNet backbone (`features` + `avgpool`)
- Dropout 0.15 (disabled at `model.eval()`)
- Linear head `1280 → 7` then **sigmoid** (outputs in 0–1)
- Seven keys: sharpness, blur, noise, brightness, contrast, blocking_artifacts, ringing_artifacts

Saved file `ml/efficientnet_b0_heads.pt` (~16.4 MB): 360 tensors, **4,058,580** parameters, of which **8,967** are `head.weight` `(7, 1280)` and `head.bias` `(7,)`. `load_state_dict(..., strict=False)` finds **no missing and no unexpected keys**. Inference is using this checkpoint, not OpenCV, on both KonIQ runs.

**Trainer vs scorer mismatch (maintenance defect, not an inference bug):** `train_efficientnet_heads.py` imports `EfficientNetB0IQA` from the scorer module, but that class is nested inside `_build_iqa_model()` and is not exported. Re-running the current trainer as written would fail until that import is aligned. The existing `.pt` file still loads in production.

### 1.3 Preprocessing

Inference: EXIF transpose (`oriented_pil_image`), convert RGB, skip if `< 8×8`, **resize to 224×224** (`antialias=True`), ImageNet mean/std. Training tensors are already 224×224 with the same mean/std. KonIQ Run 002 images are 1024×768, so they are downsampled ~4.6× before the network sees them.

Outputs are clipped to `[0, 1]` again after sigmoid.

### 1.4 Run 002 engine usage

From `run_002/output/per_image_results.csv` (n = 100):

| Field | Result |
|---|---|
| `quality_engine` | `efficientnet-b0` on **100/100** |
| `opencv_fallback` | `False` on **100/100** |
| `efficientnet_used` | `True` on **100/100** |
| `analysis_status` | `ok` on **100/100** |
| Failures | **0** |

Weak MOS agreement is **not** caused by OpenCV fallback or failed evaluations. Run 001 was also 40/40 EfficientNet-B0.

### 1.5 Score conversion compresses and quantizes the 1–5 scale

Production `_soft_score` (`media_evaluator.py`) does:

```
boosted = clip(metric * 0.5 + 0.42, 0, 1)
```

then bins to integers 5/4/3/2/1 at thresholds 0.80 / 0.64 / 0.46 / 0.28.

For any metric in `[0, 1]`:

- metric `0` → boosted `0.42` → **integer 2**
- integer **1 is unreachable** (`boosted < 0.28` would require a negative metric)
- integer 5 requires metric ≥ 0.76

Overall is the **mean of the seven integers**, rounded to 2 decimals. That mean can only take values `k/7`. Run 002 overall used **only 6 distinct values** (3.29, 3.43, 3.57, 3.71, 3.86, 4.14). Observed overall range **3.29–4.14** (span 0.85) vs MOS **1.588–4.009** (span 2.42).

Blur / Noise / Blocking / Ringing invert the 0–1 head (`1 - metric`) before `_soft_score`. Noise is further capped: `1 - min(noise, 0.85)`. Brightness is not the head output: it is `_brightness_metric(mean_luminance)` peaked at 0.48. These conversions are production behavior, not KonIQ-specific.

### 1.6 Criterion heads show little usable variation on real photos

Run 002 integer frequencies (n = 100):

| Criterion | 1 | 2 | 3 | 4 | 5 | Unique | Mean | SD |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Sharpness | 0 | 0 | 71 | 29 | 0 | 2 | 3.29 | 0.45 |
| Blur | 0 | 0 | 81 | 19 | 0 | 2 | 3.19 | 0.39 |
| Noise | 0 | 0 | 22 | 77 | 1 | 3 | 3.79 | 0.43 |
| Brightness | 0 | 0 | 0 | 36 | 64 | 2 | 4.64 | 0.48 |
| Contrast | 0 | 2 | 96 | 2 | 0 | 3 | 3.00 | 0.20 |
| Blocking Artifacts | 0 | 0 | 46 | 53 | 1 | 3 | 3.55 | 0.52 |
| Ringing Artifacts | 0 | 0 | 49 | 51 | 0 | 2 | 3.51 | 0.50 |

No criterion used 1. Contrast is **96/100 at 3** (near-constant). Brightness is 4 or 5 on every image. Sharpness and Blur never leave {3, 4}.

These are **displayed integers after `_soft_score`**, not raw 0–1 head logits. Low variation can come from the head, from `_soft_score`, or both. This audit did not dump raw 0–1 tensors (that would be a follow-up measurement, not a scoring change).

Exploratory Pearson vs published **overall** MOS (not criterion ground truth): Contrast −0.009, Brightness −0.063, Blocking 0.091, Ringing 0.137, Sharpness 0.182, Blur 0.222, Noise **−0.273**. Even as proxies for overall MOS, most heads are weak; Noise moves **opposite** overall MOS. **Do not treat these as criterion accuracy.**

### 1.7 Systematic over-scoring of low-MOS photos

Run 002 overall vs published MOS, by empirical quintile (seed 20261107):

| Stratum | n | Mean MOS | Mean system overall | Bias (system − MOS) | MAE |
|---|---:|---:|---:|---:|---:|
| Q1 very low | 20 | 2.358 | 3.521 | **+1.163** | 1.163 |
| Q2 low | 20 | 2.988 | 3.535 | +0.547 | 0.547 |
| Q3 mid | 20 | 3.298 | 3.628 | +0.330 | 0.343 |
| Q4 high | 20 | 3.527 | 3.607 | +0.080 | 0.169 |
| Q5 very high | 20 | 3.811 | 3.544 | **−0.267** | 0.289 |

System stratum means sit in **3.52–3.63** while MOS means go **2.36–3.81**. The model is nearly **constant mid-band**; it does not follow the quality axis that KonIQ raters used.

Run 002 aggregate (matches the completed run): Pearson **0.109** (p = 0.281), Spearman **0.095** (p = 0.345), MAE **0.502**, RMSE **0.647**, bias **+0.371**, 0 failures. Rank correlation is not distinguishable from zero at n = 100.

Run 001 (narrower MOS, n = 40): Pearson 0.209, Spearman 0.125, MAE 0.439. Broadening the MOS range in Run 002 **did not improve** rank agreement.

### 1.8 Construct mismatch (confirmed by design, not a code crash)

- KonIQ MOS: crowdsourced **overall** aesthetic/technical ACR on real photos.
- ACCESS overall: mean of **seven technical** integers from a synthetic-trained head.
- KonIQ does not provide Sharpness/Blur/Noise/… labels in the ACCESS sense. Overall MOS must not be copied into those seven columns.

Agreement was never a like-for-like test of the seven heads.

---

## 2. Confirmed implementation notes vs model limitations vs untested hypotheses

### Confirmed (repository + Run 002 numbers)

1. Training set is synthetic geometry with scripted degradations, not human-rated photos.
2. Backbone is frozen ImageNet; only a 7-way linear head was trained on 640 samples / 4 epochs.
3. Run 002 used EfficientNet-B0 on all 100 images; OpenCV did not run.
4. `_soft_score` makes integer 1 unreachable and packs most metrics into 2–4.
5. Displayed criteria are heavily quantized; Contrast is almost constant.
6. System overall does not track MOS across quintiles; low-MOS photos are over-scored by about 1.16 points.
7. Checkpoint keys match the inference module (`strict` would also succeed).
8. The current trainer import of `EfficientNetB0IQA` does not match the nested class in the scorer.

### Model / design limitations (expected given the above, not KonIQ labeling bugs)

1. Synthetic labels cannot teach KonIQ overall quality.
2. 224×224 resize can hide 1024×768 compression and fine noise.
3. Sharpness and blur training labels are the same random variable inverted.
4. Brightness head is trained as mean luminance, then remapped by a triangular "good exposure" curve.
5. Overall-as-mean-of-seven-integers cannot represent a continuous overall MOS even if heads were perfect.

### Untested hypotheses (do not treat as facts)

1. Raw 0–1 head outputs might vary more than the integers; `_soft_score` may be the main bottleneck **or** the heads may already be saturated. Needs a read-only dump of pre-`_soft_score` metrics.
2. KonIQ raters may weight aesthetics/content that ACCESS never scores.
3. ImageNet features may be a poor basis for IQA even with a better head.
4. Negative Noise–MOS association might be a real construct clash or noise in n = 100.

**Not found:** evaluation crashes, MOS/file mismatches, OpenCV silently replacing EfficientNet, or invented criterion MOS.

---

## 3. Prioritized recommendations (do not implement in this audit)

1. **Stop using KonIQ overall MOS as a pass/fail for the seven ACCESS heads.** Keep it only as an overall-construct check. Do not back-fill criterion CSVs from MOS.
2. **Collect criterion-specific human ratings** (ACCESS rubric, ≥3 raters) on a stratified real-photo set, including low-MOS KonIQ Q1. That is the only evidence that can say whether Sharpness/Blur/Noise heads are wrong.
3. **If retraining:** use real photographs with labels that match each head (human ACCESS scores, or published attributes with a documented mapping such as SPAQ after inversion where required). Do **not** retrain on the current `SyntheticIQADataset`. Freeze vs unfreeze the backbone is a later choice, after labels exist.
4. **If recalibrating `_soft_score`:** first log raw 0–1 metrics on Run 002 (read-only) and compare integer vs continuous correlation with **criterion** ratings, not KonIQ MOS. Changing `_soft_score` now would move every production badge without proving human agreement. Integer 1 being unreachable is a candidate defect **if** the product intends a true 1–5 scale.
5. **If changing architecture** (multi-scale input, separate quality backbone, no 7-way mean as "overall"): justify only after (2) or a documented overall IQA dataset trained as an **eighth overall head**, not by averaging synthetic technical scores.
6. **Do not quote an accuracy percentage** from MAE or `|error| ≤ 1` rates (Run 002 `abs_error_le_1_rate` = 0.87 is not accuracy).
7. Preserve Run 001 and Run 002 outputs as the baseline before any future change.

---

## 4. What would justify retrain vs recalibrate vs architecture

| Action | Justified when | Not justified by |
|---|---|---|
| **Retrain heads** (new real labels, same 7 constructs) | Criterion-specific human (or mapped published) labels exist; synthetic trainer is the documented data gap | KonIQ overall MOS alone; Run 002 MAE 0.50 |
| **Recalibrate `_soft_score` / clipping** | Raw 0–1 metrics track criterion ratings, but integers do not; or product requires reachable 1 and 5 | MOS quintile bias alone (bias is also consistent with a constant model) |
| **Change scoring architecture** (overall head, input size, unfrozen backbone) | After real labels, a linear 224×224 head still cannot fit criterion ratings, or overall must match MOS by design | Weak KonIQ correlation without criterion labels |
| **Leave production unchanged** | Current scores are treated as coarse technical heuristics, not MOS predictors | Desire for a higher Pearson number without new labels |

**Present evidence supports: do not retrain on the synthetic generator; do not ship `_soft_score` or weight edits yet; gather criterion-level real-world labels and optional raw-metric logs first.**

---

## 5. Limitations of this audit

- Did not run new inference or print raw 0–1 head values.
- Did not open individual JPEGs for qualitative review.
- Did not train or load alternative checkpoints.
- KonIQ MOS remains overall-only.
- Trainer hyperparameters (640 / 4 epochs) are script defaults; the stored `.pt` is assumed to come from that script family because no other trainer exists in-repo. Training logs are not in git.

Run 001 and Run 002 result files were not modified.