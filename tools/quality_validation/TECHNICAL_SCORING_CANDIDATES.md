# ACCESS VisionCheck Phase 9: Technical Scoring Candidates

**Status:** complete (research only).  
**Date:** 2026-11-07.  
**Input:** Phase 8 `raw_predictions.csv`, n = 370 (10 KonIQ originals × 8 distortion families + original).  
**Outputs:** `workspace/datasets/controlled_distortion/output/run_scoring_candidates_001/` (`candidate_scores.csv`, `monotonicity.csv`, `metrics.json`).  
**Script:** `tools/quality_validation/scoring_candidates.py`.  
**Tests:** `tools/quality_validation/tests/test_scoring_candidates.py`.

Production `_soft_score`, EfficientNet heads, overall_score, XP, Flutter, React Admin, PROBE, WaveRep, Gemini, and MUSIQ were not modified. No mapping was percentile-fitted on these 370 files. No human ratings were invented. MUSIQ MOS is overall-only and was not used as criterion ground truth. Knob Spearman is not ACCESS perceptual accuracy.

---

## 1. What was inspected

### 1.1 Production mapping (`_soft_score`)

Copied for the baseline only:

```
boosted = clip(metric * 0.5 + 0.42, 0, 1)
5 if boosted >= 0.80 else 4 if >= 0.64 else 3 if >= 0.46 else 2 if >= 0.28 else 1
```

At metric = 0, boosted = 0.42, which is already a 3. Rating 1 is unreachable for any metric in [0, 1]. Tests confirm `production_soft_score(0.0) == 2` and the minimum over 0.00–1.00 is 2.

Brightness uses a triangle around mean luma 0.48. Noise is capped `min(n, 0.85)` before invert. Defect heads (Blur, Noise, Blocking, Ringing) are inverted so displayed integers are “higher = better.”

### 1.2 Raw directionality (kept explicit)

| Signal | Higher raw value means | Quality q used here |
|--------|------------------------|---------------------|
| ENET / OpenCV Sharpness | more predicted sharpness | q = raw |
| ENET / OpenCV Blur | more predicted blur | q = 1 − raw |
| ENET / OpenCV Noise | more predicted noise | q = 1 − min(raw, 0.85) |
| ENET / OpenCV Brightness | mean luma (not “better”) | q = triangle(mean, 0.48) |
| ENET / OpenCV Contrast | more predicted contrast | q = clip(raw) |
| ENET / OpenCV Blocking | more predicted blocking | q = 1 − raw |
| ENET / OpenCV Ringing | more predicted ringing | q = 1 − raw |
| Classical Laplacian | more high-frequency energy | q = clip(lap / 420) |
| Classical blur quality | same Laplacian axis | q = sharpness (duplicate by design) |
| Classical Immerkaer | more estimated noise σ | q = 1 − σ/35 |
| Classical exposure | mid-gray plus clip | q = triangle × (1 − clip_frac) |
| Classical contrast | RMS plus clip | q = clip(rms) × (1 − clip_frac) |
| Classical blocking | 8×8 boundary energy ratio | q = 1 / (1 + max(0, ratio − 1)) |
| Classical ringing | edge-Laplacian energy | q = 1 − energy/40 |

Scales 420 / 35 / 40 / 1 are production OpenCV or trainer knobs, not fitted on this CSV.

---

## 2. Mapping candidates

| ID | Definition | Can emit 1? | Can emit 5? | Use |
|----|------------|-------------|-------------|-----|
| `baseline_soft_int` | production `_soft_score` | No (in [0,1]) | Yes | frozen production baseline |
| `equal_bin_int` | 1 + int(q×5), q=1 → 5 | Yes | Yes | monotone 1–5 display |
| `linear_round_int` | round(1+4q) clipped 1–5 | Yes (q≈0) | Yes (q≈1) | alternative integer |
| `linear_continuous` | 1+4q float | n/a (1.0 at q=0) | n/a (5.0 at q=1) | analysis / ranking |

Sources: `enet`, `opencv`, `classical`. All combinations are in `candidate_scores.csv`.

---

## 3. Score distributions (all 370 files)

Integer counts. These ladders mix clean originals with heavy distortion, so a “balanced” histogram is not a success criterion.

### 3.1 EfficientNet + production `_soft_score` (what members/admins see today)

| Criterion | 1 | 2 | 3 | 4 | 5 |
|-----------|--:|--:|--:|--:|--:|
| Sharpness | 0 | 0 | 266 | 104 | 0 |
| Blur | 0 | 0 | 311 | 59 | 0 |
| Noise | 0 | 0 | 83 | 267 | 20 |
| Exposure | 0 | 0 | 29 | 107 | 234 |
| Contrast | 0 | 2 | 360 | 8 | 0 |
| Blocking | 0 | 0 | 81 | 282 | 7 |
| Ringing | 0 | 0 | 151 | 219 | 0 |

Rating 1 never appears. Contrast is 360/370 at 3. Sharpness/Blur/Ringing never leave {3,4}.

### 3.2 EfficientNet + equal-width bins

| Criterion | 1 | 2 | 3 | 4 | 5 |
|-----------|--:|--:|--:|--:|--:|
| Sharpness | 11 | 188 | 169 | 2 | 0 |
| Blur | 13 | 243 | 109 | 5 | 0 |
| Noise | 3 | 51 | 177 | 135 | 4 |
| Exposure | 0 | 13 | 46 | 115 | 196 |
| Contrast | 138 | 203 | 28 | 1 | 0 |
| Blocking | 0 | 56 | 266 | 44 | 4 |
| Ringing | 4 | 96 | 245 | 25 | 0 |

Equal-bin can emit 1 for Sharpness, Blur, Noise, Contrast, Ringing. It does not magically create a 5 on Sharpness: raw ENET sharpness never reaches the top bin on this set. Contrast piles at 1–2 because raw contrast values sit low, not because bins were “unfair.”

### 3.3 EfficientNet + linear_round

Linear-round still never emits 1 for Sharpness/Blur/Noise/Blocking/Ringing on this CSV (q never near 0). Contrast: 34/290/46/0/0. Exposure: 0/4/65/182/119.

### 3.4 Classical + equal-bin (a priori scales)

| Criterion | 1 | 2 | 3 | 4 | 5 |
|-----------|--:|--:|--:|--:|--:|
| Sharpness / Blur (same axis) | 133 | 30 | 23 | 6 | 178 |
| Noise | 7 | 14 | 22 | 29 | 298 |
| Exposure | 66 | 68 | 53 | 68 | 115 |
| Contrast | 34 | 65 | 94 | 90 | 87 |
| Blocking | 6 | 10 | 14 | 14 | 326 |
| Ringing | 166 | 30 | 56 | 62 | 56 |

Sharpness is bimodal because Laplacian/420 saturates many originals at q=1 and many blurred frames at q=0. That is scale saturation, not evidence that 420 is “correct.” Do not retune 420 on this CSV to flatten the histogram.

---

## 4. Severity-ranking agreement

Median Spearman of **quality vs distortion severity** (expect **negative**). n = originals with a non-constant series (integer maps often have n < 10 because the ladder is flat).

| Family | Criterion | ENET baseline | ENET equal-bin | ENET continuous | Classical equal-bin |
|--------|-----------|--------------:|---------------:|----------------:|--------------------:|
| gaussian_blur | blur | N/A (n=0) | −0.828 (n=4) | −0.943 (n=10) | −0.845 (n=7) |
| awgn | noise | −0.655 (n=2) | −0.828 (n=5) | −0.829 (n=10) | −0.941 (n=10) |
| underexposure | exposure | 0.000 (n=5) | 0.000 (n=7) | −0.100 (n=10) | −0.975 (n=9) |
| overexposure | exposure | +0.354 (n=7) | +0.289 (n=9) | +0.400 (n=10) | −0.894 (n=9) |
| low_contrast | contrast | −0.707 (n=1) | 0.000 (n=8) | −0.100 (n=10) | −0.949 (n=10) |
| high_contrast | contrast | N/A (n=0) | +0.707 (n=6) | +0.100 (n=10) | **−0.866 (n=9)** |
| jpeg | blocking | −0.655 (n=2) | **+0.655 (n=2)** | −0.086 (n=10) | **−0.971 (n=10)** |
| ringing | ringing | N/A (n=0) | N/A (n=0) | −0.600 (n=10) | −0.828 (n=6) |

OpenCV continuous blur vs Gaussian σ: median Spearman −1.0 (n=10). OpenCV continuous noise vs AWGN: −1.0 (n=10). OpenCV continuous blocking vs JPEG quality knob: −0.943 (n=10), but OpenCV blocking is **flat-patch energy**, not 8×8 boundaries (Phase 7/8 construct issue).

### Reading the table

- Integer `_soft_score` often has **undefined** Spearman (n=0): every step maps to the same integer.
- Equal-bin on a weak ENET JPEG blocking ladder **flipped sign** (+0.655) with n=2. Continuous on the same ladders is −0.086. Do not treat that equal-bin number as “blocking got worse.”
- High-contrast: ENET/OpenCV **reward** RMS gain (positive Spearman). Classical RMS×clip **penalizes** clipping (negative). That is a construct difference, not a win for “accuracy.”
- Overexposure ENET Spearman is **positive**: the brightness head does not track EV the way the triangle+clip map does.

---

## 5. Sensitivity (small vs large steps)

Median score change from original → lightest step vs original → heaviest step. Negative = quality fell.

| Ladder / map | Smallest step | Largest step |
|--------------|--------------:|-------------:|
| Gaussian blur, ENET `_soft_score` integer | 0 | 0 |
| Gaussian blur, ENET continuous | −0.006 | −0.304 |
| Gaussian blur, classical/OpenCV integer | 0 | −2 |
| Gaussian blur, classical continuous | −0.093 | −2.217 |
| AWGN, ENET integer (all three maps) | 0 | 0 |
| AWGN, ENET continuous | −0.020 | −0.302 |
| AWGN, classical equal-bin | 0 | −3 |
| AWGN, classical continuous | −0.225 | −2.830 |
| JPEG, classical equal-bin blocking | −1 | −3 |
| JPEG, ENET integer blocking | 0 | 0 |
| Ringing, ENET integer | 0 | 0 |
| Ringing, ENET continuous | ~0 | −0.023 |
| Ringing, classical continuous | −0.177 | −0.537 |

`_soft_score` hides small and often large ENET movement. Continuous scores still move. Classical JPEG boundary ratio moves at both ends of the quality knob. ENET ringing barely moves even as a float.

---

## 6. Saturation (fraction of 10 originals whose entire ladder is a constant integer)

| Family | ENET baseline | ENET equal-bin | Classical equal-bin |
|--------|--------------:|---------------:|--------------------:|
| gaussian_blur | 1.00 | 0.60 | 0.30 |
| awgn | 0.80 | 0.50 | 0.00 |
| underexposure | 0.50 | 0.30 | 0.10 |
| overexposure | 0.30 | 0.10 | 0.10 |
| low_contrast | 0.90 | 0.20 | 0.00 |
| high_contrast | 1.00 | 0.40 | 0.10 |
| jpeg | 0.80 | 0.80 | 0.00 |
| ringing | 1.00 | 1.00 | 0.40 |

Equal-bin reduces saturation versus `_soft_score` for blur/noise/contrast, but **not** for ENET JPEG or ENET ringing. Classical JPEG never saturates (0.00).

---

## 7. Sharpness vs Blur (redundancy)

On originals + Gaussian ladder (n=60):

| Source / map | Pearson | Spearman |
|--------------|--------:|---------:|
| ENET baseline integers | 0.704 | 0.704 |
| ENET equal-bin | 0.627 | 0.610 |
| ENET continuous | 0.892 | 0.871 |
| OpenCV any map | 1.000 | 1.000 |
| Classical any map | 1.000 | 1.000 |

OpenCV Blur is defined as `1 − Sharpness`. Classical Phase 9 blur quality is the **same Laplacian channel** as sharpness (explicit duplicate). Averaging Sharpness and Blur into `overall_score` double-counts one axis. ENET heads are correlated, not identical: they are still not two independent human criteria.

Phase 8 already showed AWGN **raises** ENET sharpness (Spearman +0.77 on raw). Here, AWGN vs classical equal-bin **sharpness** = +0.655 (Laplacian treats grain as detail) while AWGN vs classical **noise** = −0.941.

---

## 8. Cross-criterion interference

Median Spearman of a **non-primary** score vs that family’s severity:

| Probe | Median Spearman |
|-------|----------------:|
| AWGN vs ENET equal-bin sharpness | +0.131 |
| AWGN vs classical equal-bin sharpness | +0.655 |
| AWGN vs classical equal-bin noise | −0.941 |
| Gaussian blur vs ENET equal-bin noise | +0.655 |
| Ringing vs ENET equal-bin sharpness | +0.655 |

Laplacian / ENET sharpness are not noise-safe. Blurring can move the noise head. Unsharp-mask “ringing” moves sharpness. A seven-number mean will mix these.

---

## 9. Measurement candidates vs EfficientNet heads

ACCESS 1–5 rubric is used only as a **label vocabulary** (1 = fails the named construct, 5 = meets it). No rater scores were created.

### 9.1 Focus / blur (one channel)

- **Keep one high-frequency channel.** Laplacian variance tracks Gaussian σ (continuous Spearman −1.0). ENET blur amount also tracks σ (continuous −0.943) but `_soft_score` saturates (n=0).
- **Do not ship Blur as `1 − Sharpness`.** That is duplication, not defocus/motion.
- Grain raises Laplacian: any focus score needs a noise caveat or a joint estimator. Knob correlation ≠ “this looks sharp to a coach.”

### 9.2 Noise vs texture

- Immerkaer (classical) vs AWGN: equal-bin −0.941, continuous −1.0, saturation 0.00. Smallest integer step is still often 0; large step −3.
- ENET noise amount tracks AWGN in the continuous map (−0.829) but integers stay flat on 80% of `_soft_score` ladders.
- Texture/grain in real ACCESS photos is not AWGN. Do not claim Immerkaer “detects sensor noise” from this set.

### 9.3 Exposure vs mean brightness

- Triangle-on-mean (ENET brightness head): underexposure ~0 Spearman; overexposure **positive**.
- Triangle × clip fraction (classical): underexposure −0.975, overexposure −0.894 (equal-bin).
- Mean luma alone cannot encode highlight/shadow clip. Clip penalty is a **construct** improvement, not a validated perceptual model.

### 9.4 Contrast + clipping

- Low contrast: OpenCV/classical RMS fall with the gain-down knob (continuous −1.0). ENET contrast barely tracks (−0.10 continuous).
- High contrast: OpenCV RMS **rises** (+0.975 continuous). ACCESS rubric for “contrast quality” should **not** reward clipped harsh gain. Classical RMS×clip reverses the sign (−0.866 equal-bin, −1.0 continuous except one image at +0.3).
- That reversal is why this candidate deserves human review, not because the Spearman is prettier.

### 9.5 JPEG block boundaries

- Classical 8×8 boundary ratio vs JPEG quality knob: equal-bin −0.971, continuous −1.0, saturation 0.00, large-step −3.
- ENET blocking: continuous −0.086, integer saturation 0.80, equal-bin sign flip on n=2.
- OpenCV “blocking” tracks the knob but measures flatness (Phase 7). Do not promote it as JPEG blocking.

### 9.6 Ringing / halo

- ENET ringing integers: saturation 1.00; continuous median Δ at max step −0.023.
- Classical edge-Laplacian: equal-bin −0.828 (n=6), continuous −0.941 (n=6), large-step −1 integer / −0.54 continuous.
- Unsharp-mask is a crude halo proxy. Real JPEG ringing and overshoot need a different stimulus plus humans.

---

## 10. Proposed nonredundant technical summary (not production)

Do **not** change `overall_score`, XP, or recommendation copy.

If a later research UI shows technical diagnostics beside MUSIQ overall, use **six distinct constructs**, not seven overlapping integers:

1. **Overall perceptual (separate track):** MUSIQ OPQ / official TF Hub, never as a criterion GT.
2. **Focus/detail:** one Laplacian **or** ENET sharpness, with a noise-interference flag. Drop Blur from any mean until a motion/defocus detector exists that is not `1 − sharpness`.
3. **Noise:** Immerkaer or inverted ENET noise amount; report “grain vs texture unresolved.”
4. **Exposure:** mid-gray triangle × clip fraction.
5. **Contrast:** RMS × clip fraction (so harsh gain is not a 5).
6. **Blocking:** 8×8 boundary ratio.
7. **Ringing:** edge-Laplacian, labeled as halo-energy proxy.

Display: keep **continuous 1–5 internally**; round only for a badge. Prefer `equal_bin_int` over `_soft_score` if a 1–5 badge is required, knowing Sharpness 5 may still be empty if the raw head never reaches 0.8.

A research-only mean of {focus, noise, exposure, contrast, blocking, ringing} is for ablation, not XP.

---

## 11. What deserves further validation on real ACCESS photos

Promote to a **human / real-world** protocol (below):

| Candidate | Why |
|-----------|-----|
| ENET blur/noise **raw or continuous**, not `_soft_score` | Tracks knobs; integers hide it |
| `equal_bin_int` or `linear_continuous` as display maps | Can emit 1–5; do not retune bins on this CSV |
| Classical JPEG boundary ratio | Strong knob response **and** matching construct |
| Classical exposure × clip, contrast × clip | Fixes known construct failures of mean/RMS-only |
| Immerkaer noise | Strong AWGN ranking; needs texture check on real photos |
| Single focus channel | Removes Sharpness/Blur double count |

Do **not** promote without independent reference:

| Candidate | Why not |
|-----------|---------|
| ENET brightness / contrast heads | Fail EV and RMS knobs; sometimes reverse |
| ENET blocking / ringing | Weak, saturated, possible sign flips |
| OpenCV blocking as JPEG | Wrong construct |
| Dual Sharpness+Blur in a mean | Identity or r≈0.87 |
| Any map retuned so histograms look uniform | Explicitly forbidden |
| “Classical beats ENET because Spearman is −1” | Synthetic knobs, not coaches |

---

## 12. Recommended next validation protocol (Phase 10, research only)

**Goal:** decide which *constructs and maps* survive on real ACCESS stills, using the ACCESS 1–5 rubric as rater instructions, not as fabricated labels.

**Do not:** change production scoring; fit bins on the evaluation set; use MUSIQ MOS as Sharpness/Blur/Noise/… GT; claim criterion accuracy from Phase 8/9 Spearmans.

### 12.1 Materials

- 80–120 real ACCESS member photos (practice stills), stratified by sport/indoor/outdoor/phone, **not** the 10 KonIQ CTRL images used here.
- Optional: 20 of those photos with a **single** mild + strong operator (blur, JPEG, EV) applied, shown as pairs, not mixed into the main MOS pool.

### 12.2 Ratings (pre-register)

- Two trained raters, ACCESS rubric **one criterion per pass** (do not rate seven sliders at once).
- First pass: overall technical 1–5.
- Separate passes: Focus, Noise, Exposure, Contrast. Blocking and Ringing only if the rater can see the artifact; allow “not present / N/A.”
- Do **not** ask for both Sharpness and Blur unless a written distinction exists (detail vs smear). Default: one Focus score.
- Resolve disagreements >1 point; report IRR (quadratic weighted kappa).

### 12.3 Frozen candidates (no peeking)

Lock, before ratings exist:

- ENET continuous 1–5 for blur and noise quality.
- Classical focus (Laplacian/420), noise (Immerkaer/35), exposure×clip, contrast×clip, JPEG boundary ratio.
- Maps: `linear_continuous` (primary correlation), `equal_bin_int` (badge), `baseline_soft_int` (production comparison).

### 12.4 Analyses

- Spearman/Pearson vs **human criterion** (not vs knobs) for the matching construct only.
- Confusion: Focus vs Noise (grain-as-detail).
- Badge agreement: production integer vs equal-bin vs human, with 1–5 histograms **descriptive only**.
- Stop rule: if a candidate’s Spearman vs its human criterion is not reliably above production `_soft_score` on the same criterion, do not recommend replacement.

### 12.5 Out of scope

Retraining EfficientNet, replacing MUSIQ, API/DB fields, XP, Flutter/React copy.

---

## 13. Files

| Path | Role |
|------|------|
| `tools/quality_validation/scoring_candidates.py` | Mappings + evaluation |
| `tools/quality_validation/tests/test_scoring_candidates.py` | 1 unreachable under `_soft_score`; equal-bin emits 1 and 5 |
| `.../run_scoring_candidates_001/candidate_scores.csv` | 370 rows × all maps |
| `.../run_scoring_candidates_001/monotonicity.csv` | Per family/source/map Spearman |
| `.../run_scoring_candidates_001/metrics.json` | Distributions, saturation, sensitivity, interference |
| `.../run_scoring_candidates_001/TECHNICAL_SCORING_CANDIDATES_AUTO.md` | Machine summary |

---

## 14. Production

Unchanged.

Stopped for review.
