# Controlled distortion results (Phase 8)

**Status: complete.** Research-only. Source KonIQ JPEGs were not modified. Production FastAPI, `_soft_score`, EfficientNet weights, `overall_score`, XP, Flutter, React, PROBE, WaveRep, Gemini, and MUSIQ were not changed. No human criterion labels were invented.

Generated: 2026-11-07T00:34:31Z  
Seed: `20261107_phase8`  
Originals: **10** (KonIQ Run 001 folder, 1024×768)  
Scored files: **370** (10 originals + 8 families × 10 images × 4–5 levels)  
Wall time: **990 s** CPU  

Scripts: `tools/quality_validation/controlled_distortion.py`, `classical_quality_metrics.py`  
CSVs: `workspace/datasets/controlled_distortion/output/run_001/` (`originals_manifest.csv`, `raw_predictions.csv`, `monotonicity.csv`, `metrics.json`)

Spearman below is **metric vs distortion severity** (higher severity = stronger distortion), median across the 10 originals. Spearman is **undefined** when a series has zero variance (typical of saturated integers).

This is **construct sensitivity**, not human accuracy, and not MUSIQ.

---

## 1. Sample (read-only IDs)

| media_id | source_media_key |
|----------|------------------|
| CTRL-001 | 3491336743.jpg |
| CTRL-002 | 4541090785.jpg |
| CTRL-003 | 4611014636.jpg |
| CTRL-004 | 4918086314.jpg |
| CTRL-005 | 5205048751.jpg |
| CTRL-006 | 7574416384.jpg |
| CTRL-007 | 8460764072.jpg |
| CTRL-008 | 95721252.jpg |
| CTRL-009 | 9710823281.jpg |
| CTRL-010 | 9823108104.jpg |

Distorted copies: `workspace/datasets/controlled_distortion/generated/` (PNG except the JPEG family).

---

## 2. Ladders (deterministic)

| Family | Levels | Primary ACCESS badge |
|--------|--------|----------------------|
| gaussian_blur | σ = 0.5, 1, 2, 4, 8 | Blur |
| awgn | std = 5, 10, 20, 35, 50; RNG `sha256(seed:id:awgn:std)` | Noise |
| underexposure | gain = 0.70, 0.50, 0.35, 0.20 | Brightness |
| overexposure | gain = 1.30, 1.60, 2.00, 2.50 | Brightness |
| low_contrast | gain = 0.70, 0.50, 0.35, 0.20 around 127.5 | Contrast |
| high_contrast | gain = 1.40, 1.80, 2.40, 3.20 | Contrast |
| jpeg | quality = 70, 40, 25, 15, 8 | Blocking |
| ringing | unsharp amount = 1.4, 1.8, 2.2, 2.8, 3.5 | Ringing |

---

## 3. Integer 1 is still unreachable

Across **370** scored files (including σ=8 blur and JPEG quality 8):

| Criterion | 1 | 2 | 3 | 4 | 5 |
|-----------|--:|--:|--:|--:|--:|
| Sharpness | **0** | 0 | 266 | 104 | 0 |
| Blur | **0** | 0 | 311 | 59 | 0 |
| Noise | **0** | 0 | 83 | 267 | 20 |
| Brightness | **0** | 0 | 29 | 107 | 234 |
| Contrast | **0** | 2 | **360** | 8 | 0 |
| Blocking | **0** | 0 | 81 | 282 | 7 |
| Ringing | **0** | 0 | 151 | 219 | 0 |

Displayed badges stay in a 2–4 (mostly 3–4) band. Contrast is almost constant at 3. That matches `_soft_score` compression from Phase 7.

---

## 4. Do badges fall as the matching distortion grows?

**Displayed EfficientNet integers** (high = better). Median Spearman vs severity. `undef` = images with zero integer variance.

| Family | Primary | Median Spearman (integers) | Images with defined r | Verdict |
|--------|---------|---------------------------:|----------------------:|---------|
| gaussian_blur | Blur | **undefined on all 10** | 0 | Integers **do not move** even to σ=8 |
| awgn | Noise | −0.655 | 2 / 10 | Weak; 8/10 saturated |
| underexposure | Brightness | **0.00** | 5 / 10 | No consistent drop |
| overexposure | Brightness | **+0.35** | 7 / 10 | Wrong sign (looks *better* as it blows out) |
| low_contrast | Contrast | −0.707 | **1 / 10** | One image only |
| high_contrast | Contrast | undefined on all 10 | 0 | Integers do not move |
| jpeg | Blocking | −0.655 | 2 / 10 | Weak; 8/10 saturated |
| ringing | Ringing | undefined on all 10 | 0 | Integers do not move |

**EfficientNet raw 0–1 heads** (before `_soft_score`; for Blur/Noise/Blocking/Ringing this is **defect amount**, so Spearman vs severity should be **positive** if the head tracks the knob):

| Family | Raw column | Median Spearman | Interpretation |
|--------|------------|----------------:|----------------|
| gaussian_blur | `blur` | **+0.94** | Amount head tracks Gaussian σ |
| gaussian_blur | `sharpness` | **−1.00** | Sharpness head falls (same axis) |
| awgn | `noise` | **+0.94** | Amount head tracks AWGN |
| awgn | `sharpness` | **+0.77** | **Interference:** noise raises the sharpness head |
| underexposure | `brightness` | **+0.30** | Weak / mixed; not mean luminance |
| overexposure | `brightness` | **−0.10** | Does not track brighter mean |
| low_contrast | `contrast` | **−0.10** | Barely tracks RMS drop |
| high_contrast | `contrast` | **+0.10** | Barely tracks RMS rise |
| jpeg | `blocking` | **+0.43** | Weak / mixed |
| ringing | `ringing` | **+0.66** | Partial track of unsharp amount |

So several **raw** heads move in a usable direction on the matching ladder, then **`_soft_score` hides the movement**. Brightness and Contrast raw heads still do **not** follow their physical knobs.

---

## 5. Classical research metrics (same ladders)

Not assumed more accurate than humans. They **do** respond to the knobs they were written for:

| Family | Metric | Median Spearman vs severity | Expected |
|--------|--------|----------------------------:|----------|
| gaussian_blur | `blur_inv_laplacian` | **+1.00** | defect up |
| gaussian_blur | `laplacian_var` | **−1.00** | sharpness down |
| awgn | Immerkaer σ | **+1.00** | defect up |
| underexposure | exposure triangle 0.48 | **−1.00** | quality down |
| overexposure | highlight+shadow clip fraction | **+1.00** | clip up |
| low_contrast | RMS / 72 | **−1.00** | RMS down |
| high_contrast | RMS / 72 | **+1.00** | RMS up (rubric would want quality **down**) |
| jpeg | 8×8 **boundary** \|Δ\| ratio | **+1.00** | blocking up |
| jpeg | OpenCV-style **flat** 8×8 fraction | **+1.00** | also rises (still the wrong construct, but it co-moves here) |
| ringing | \|Laplacian\| on Canny edges | **+1.00** | halo energy up |

OpenCV **displayed** Blur on the Gaussian ladder: median Spearman **−0.93** on 7/10 images (integers actually move). That is stronger **displayed** sensitivity than EfficientNet Blur (0/10 defined).

---

## 6. Sharpness and Blur are duplicate signals

On originals + Gaussian ladder (n=60 scored files):

| Pair | Pearson | Spearman |
|------|--------:|---------:|
| EfficientNet **raw** sharpness vs raw blur | **−0.89** | **−0.87** |
| EfficientNet **integers** Sharpness vs Blur (both high=better) | **+0.70** | **+0.70** |
| OpenCV raw sharpness vs blur | **−1.00** | **−1.00** |
| OpenCV mean \|sharpness + blur − 1\| | **0.00** | exact inverse |

**Finding:** OpenCV Blur is identically `1 − Sharpness`. EfficientNet heads are not bitwise inverses, but they are **strongly anti-correlated** on a blur ladder, and the displayed pair still moves together (r=0.70). Putting both in `overall_score` double-counts focus/detail.

---

## 7. Cross-criterion interference

- **AWGN raises EfficientNet raw sharpness** (median Spearman +0.77). Laplacian-like energy from grain. Classical Laplacian would do the same; Immerkaer is the noise-specific channel.
- **Unsharp ringing** tends to raise displayed Sharpness integers when they move at all (Spearman +0.83 on 2 images).
- **Gaussian blur** Noise integers: mixed (median −0.13 on 4 images).

---

## 8. Comparison, not a winner declaration

| Need | EfficientNet displayed 1–5 | EfficientNet raw 0–1 | Classical (this study) |
|------|---------------------------|----------------------|-------------------------|
| Blur / sharpness | Saturated; duplicate | Tracks Gaussian; duplicate | Laplacian tracks σ perfectly; still one axis |
| Noise | Mostly saturated | Tracks AWGN | Immerkaer tracks σ perfectly |
| Exposure | Wrong sign on overexposure | Weak | Triangle / clip fraction track EV |
| Contrast | Stuck at 3 | Weak | RMS tracks gain; **does not** encode ACCESS “harsh clip is bad” |
| Blocking | Saturated | Weak | Boundary ratio tracks JPEG quality |
| Ringing | Saturated | Partial | Edge Laplacian tracks unsharp |

Classical metrics are **more sensitive to these knobs**. That is not the same as “more accurate for ACCESS documentation.” Human criterion ratings are still required (Phase 7). Do not swap production to classical from this run alone.

---

## 9. Reproduce

```powershell
cd C:\Users\Dell\Desktop\access_mobile
$env:PYTHONPATH = "access_backend;."
python tools/quality_validation/controlled_distortion.py --n 10
```

---

## 10. Production

Unchanged.

Stopped for review.
