# ACCESS VisionCheck — Technical quality criteria audit (Phase 7)

**Status: audit complete.** Research only. Production scoring, `_soft_score`, EfficientNet weights, API, XP, Flutter, React Admin, PROBE, WaveRep, and Gemini were not modified. No models were retrained. No human criterion ratings were invented.

**MUSIQ is out of scope as criterion evidence.** Official TF Hub MUSIQ PaQ-2-PiQ vs LIVEC MOS was Pearson **0.805**, Spearman **0.770** (n=1,162). That is overall perceptual quality only. It does not validate Sharpness, Blur, Noise, Brightness, Contrast, Blocking, or Ringing.

Companions: `SCORING_CONTRACT.md`, `MODEL_VALIDITY_DIAGNOSTIC.md`, `HUMAN_RATING_RUBRIC.md`, `HUMAN_VALIDATION_PROTOCOL.md`, `MEDIA_QUALITY_ACCURACY_IMPROVEMENT_PLAN.md`.

---

## 0. What production actually does

Preferred engine: EfficientNet-B0, ImageNet backbone frozen at train time, linear head `1280 → 7`, sigmoid, **resize 224×224**. Fallback: OpenCV heuristics (`analysis.opencv_fallback`). Displayed badges are integers 1–5 after `_soft_score`. `overall_score` is the **mean of those integers** (photo 7, video 9). That mean is a separate product field, not a criterion.

Sources: `media_evaluator.py` (`_photo_criteria`, `_soft_score`, `_brightness_metric`), `efficientnet_b0_scorer.py`, `opencv_quality.py`, `train_efficientnet_heads.py`.

Shared mapping (all seven, plus video extras):

```
boosted = clip(metric * 0.5 + 0.42, 0, 1)
```

Bins: 5 ≥ 0.80, 4 ≥ 0.64, 3 ≥ 0.46, 2 ≥ 0.28, else 1.

| Input metric in [0, 1] | Integer |
|------------------------|---------|
| 0.00 | **2** |
| 0.76 | 5 |
| need 1 | **impossible** (would need metric &lt; −0.28) |

Run 002 (n=100, EfficientNet on 100/100): **no criterion used 1**.

---

## 1. Criterion-by-criterion audit

Intended meaning is the ACCESS rubric (higher displayed score = better), not MUSIQ MOS.

### 1.1 Sharpness

| | |
|--|--|
| **Intended** | Fine detail / micro-contrast on the subject (hair, fabric, text). Not blur, not noise, not JPEG. |
| **Learned raw** | Head index 0 `sharpness` in [0, 1]. Train label = `1 - blur_amount` (the Gaussian-blur knob), **not** a sharpness statistic on the final canvas. |
| **OpenCV raw** | Laplacian variance / 420, clipped to [0, 1]. |
| **Display** | `_soft_score(sharpness)`. |
| **Does it measure the property?** | **Weak / confounded.** Training never labeled remaining texture after other distortions. After noise, JPEG, and unsharp, the label is still `1 - blur_amount`. OpenCV Laplacian responds to noise and ringing as “sharp.” 224×224 erases KonIQ-scale micro-detail. |
| **Observed (Run 002 integers)** | Only {3, 4}: 71 at 3, 29 at 4. Mean 3.29. |

### 1.2 Blur

| | |
|--|--|
| **Intended** | Freedom from **defocus or motion smear** (disks, streaks). Distinct from Sharpness. |
| **Learned raw** | Head `blur`. Train label = `blur_amount` (isotropic Gaussian only). **No motion blur, no disk PSF.** |
| **OpenCV raw** | `blur = 1 - sharpness` (**identically** the inverse of Laplacian sharpness). |
| **Display** | `_soft_score(1 - blur)`. |
| **Does it measure the property?** | **No, as a separate construct, in the fallback path.** OpenCV Sharpness and Blur are one measurement inverted. EfficientNet labels are the same pair (`s = 1 - b`). Product overall **double-counts** the same axis. Rubric allows high Blur (in focus) with lower Sharpness (mushy texture); the trainer cannot represent that. |
| **Observed** | Only {3, 4}: 81 at 3, 19 at 4. Mean 3.19. |

### 1.3 Noise

| | |
|--|--|
| **Intended** | Freedom from grain / chroma splotch. |
| **Learned raw** | Head `noise`. Train label = `noise_amount` (AWGN std up to 35). |
| **OpenCV raw** | std of `|gray − GaussianBlur(5×5)|` / 36. High-frequency energy, not a noise σ estimator. Texture and grain both raise it. |
| **Display** | `_soft_score(1 - min(noise, 0.85))`. Cap 0.85 **floors** worst-case quality. |
| **DB polarity** | `legacy.noise_score` / column `noise_score` stores `1 - Noise/5` (high stored value = more noise). Display inverts again. Easy to misread in admin dumps. |
| **Does it measure the property?** | **Partially, and inverted vs overall MOS.** Run 002 Pearson of Noise integer vs KonIQ **overall** MOS was **−0.273** (wrong construct, but the sign is a warning). Texture-rich photos can look “noisy” to residual-std. 224×224 averages grain away. |
| **Observed** | 22 at 3, 77 at 4, 1 at 5. Mean 3.79. No 1–2. |

### 1.4 Brightness

| | |
|--|--|
| **Intended** | Subject well exposed (under **and** over are bad). Non-monotonic. |
| **Learned raw** | Head `brightness` trained to **mean luminance / 255**, a monotonic gray mean, **not** “good exposure.” |
| **Then discarded for display** | `_brightness_metric(v) = 1 - |v - 0.48| * 2.2`. Peak 0.48. Head output is only used as a luminance proxy. |
| **OpenCV** | Mean gray / 255, then the same triangle. |
| **Does it measure the property?** | **Wrong training target, plausible display curve.** Global mean is not subject exposure (backlit face). Peak 0.48 is arbitrary. Overexposure and underexposure are folded together, so coaching cannot say which. |
| **Observed** | Only {4, 5}: 36 at 4, 64 at 5. Mean 4.64. Never “too dark/bright” as 1–3. |

### 1.5 Contrast

| | |
|--|--|
| **Intended** | Usable tonal separation **without** harsh clip as the main look. |
| **Learned raw** | Head `contrast`. Train label = gray std / 72 after a random gain around 127.5 (range 0.3–1.0). Never labeled “harsh.” |
| **OpenCV** | Same: gray std / 72. |
| **Display** | `_soft_score(min(contrast, 1.0))`. Higher RMS = higher score, so crushed blacks + blown whites can score **well**. Opposite of the rubric’s “harsh clip” penalty. |
| **Does it measure the property?** | **No for ACCESS contrast.** It is global RMS energy. |
| **Observed** | **96/100 at 3**, 2 at 2, 2 at 4. Near-constant. Almost no decision information. |

### 1.6 Blocking Artifacts

| | |
|--|--|
| **Intended** | Visible 8×8 (or similar) tiles in flat regions. |
| **Learned raw** | Head `blocking_artifacts`. Train label = random `blocking_amount`. JPEG re-encode only if amount &gt; 0.2; if not, label can still be up to 0.2 with **no JPEG**. Amount is not a measured blockiness. |
| **OpenCV** | Fraction of 8×8 patches with **variance &lt; 8**. That is **flatness / sky**, not block boundaries. A clean wall scores “blocked.” |
| **Display** | `_soft_score(1 - blocking)`. |
| **Does it measure the property?** | **OpenCV: no (wrong construct). EfficientNet: unproven**, and 224×224 **smears the JPEG grid** on 1024×768 photos. |
| **Observed** | 46 at 3, 53 at 4, 1 at 5. Mean 3.55. |

### 1.7 Ringing Artifacts

| | |
|--|--|
| **Intended** | Halos / ghost ridges (unsharp or codec ringing). |
| **Learned raw** | Head `ringing_artifacts`. Train label = unsharp-mask **amount** (`addWeighted` vs Gaussian), not a halo metric. Applied **after** JPEG. No JPEG2000. |
| **OpenCV** | Canny pixels where consecutive row diffs change sign. Texture and noise also oscillate. |
| **Display** | `_soft_score(1 - ringing)`. |
| **Does it measure the property?** | **Weak proxy.** Sign-flips ≠ halos. Unsharp training ≠ phone sharpening or JP2K ringing. |
| **Observed** | 49 at 3, 51 at 4. Mean 3.51. No 1, 2, or 5. |

---

## 2. Cross-cutting defects

1. **Synthetic trainer, not photos.** 224×224 rectangles, 640 samples, 4 epochs, frozen ImageNet, MSE. Labels are knobs and OpenCV stats.
2. **Stacked degradations, independent labels.** Blur, noise, exposure, contrast, JPEG, unsharp are applied in sequence; each label ignores the others.
3. **`_soft_score`:** 1 unreachable; 5 needs metric ≥ 0.76; mid-band pile-up. Changing it would move XP-adjacent overall without proving humans.
4. **Sharpness/Blur collinearity** in OpenCV and in training labels. Mean-of-seven **double-counts** that axis. Video **Motion Stability** is mean |sharpness| delta, a third use of the same signal.
5. **224×224** hides blocking, fine grain, and ringing on documentation stills.
6. **Compressed histograms** (Run 002): Contrast almost constant; Brightness only 4–5; Sharpness/Blur only 3–4.
7. **No raw 0–1 dump in prior audits.** Integer compression vs saturated heads is still an **untested split**. Required before any `_soft_score` change.
8. **KonIQ/LIVEC MOS** must not be copied into criterion columns. Run 002 head-vs-MOS Pearsons are not criterion accuracy.
9. **OpenCV fallback** is a different construct (especially Blocking). Engine must stay logged.
10. **Trainer import defect:** `train_efficientnet_heads.py` imports `EfficientNetB0IQA` but the class is nested in `_build_iqa_model()`. Re-running the trainer as written would fail. Existing `.pt` still loads.

---

## 3. Public datasets (criterion-specific or controlled)

Do not use KonIQ MOS, LIVEC MOS, or MUSIQ scores as Sharpness/Blur/… labels.

| Need | Dataset | What it gives | Limits / license caution |
|------|---------|---------------|--------------------------|
| Smartphone attributes | **SPAQ** (11,125) | brightness, colorfulness, contrast, **noisiness**, **sharpness**, plus overall MOS | No Blur split, no Blocking, no Ringing. Noisiness high = more noise (invert). Research/educational terms historically; **evaluation-only** unless permission. |
| JPEG / JP2K / noise / blur knobs | **LIVE IQA**, **CSIQ**, **TID2013**, **KADID-10k** | Distortion **type + level**, not ACCESS 1–5 | Synthetic. LIVE JPEG ≫ typical phone JPEG. Map amount → quality by inversion. Follow each lab’s request form. |
| Authentic blur | **BID**, **CID2013** | Blur-centric MOS | Often one blur MOS, not Sharpness vs Blur. |
| Noise (denoise pairs) | **SIDD**, **DND** | Clean/noisy pairs, **no MOS** | Good for σ / residual tests, not ACCESS 1–5. |
| ACCESS construct | **Human pack** (`HUMAN_VALIDATION_PROTOCOL.md`) | Independent 1–5 per criterion, ≥3 raters | **Required** before any “accuracy” claim. Not collected in this phase. |

SPAQ is the closest public multi-attribute set. It still collapses Blur into Sharpness and omits codec artifacts.

---

## 4. Independent validation methods (per criterion)

Global rules: Spearman (and Pearson) vs **matching** labels; IRR before machine comparison; record engine; higher display = better; invert “amount of defect” labels; no `|error|≤1` as accuracy; no MUSIQ MOS as GT.

| Criterion | Reference A (human) | Reference B (public / controlled) | Direction / spread checks |
|-----------|---------------------|-----------------------------------|---------------------------|
| Sharpness | ACCESS Sharpness median | SPAQ sharpness (0–100); **not** Blur MOS | Histogram not stuck on {3,4}; distinct from Blur on in-focus mushy shots |
| Blur | ACCESS Blur median | BID/CID or LIVE Gaussian/motion **inverted** | Motion vs defocus split if possible; not 1 − Sharpness |
| Noise | ACCESS Noise median | SPAQ noisiness inverted; SIDD residual vs σ | Monotone vs added AWGN; texture-only images must not tank |
| Brightness | ACCESS Brightness median | SPAQ brightness **after** confirming overexposure coding | Non-monotonic vs EV: peak mid, drop both sides |
| Contrast | ACCESS Contrast median | SPAQ contrast **and** a harsh-clip set | RMS-only metric should **lose** if it rewards crush |
| Blocking | ACCESS Blocking median | LIVE/TID/KADID JPEG quality ladder | Flat sky without tiles must **not** score poor; 100% crop |
| Ringing | ACCESS Ringing median | Unsharp ladder + LIVE JP2K (codec only) | Do not treat JP2K as phone unsharp |

ACCESS human pack remains the only pass/fail for production badges.

---

## 5. Established metrics vs current EfficientNet heads

Recommendation is **evaluation order**, not a production swap.

| Criterion | Prefer to **benchmark first** | Why vs current heads |
|-----------|------------------------------|----------------------|
| Sharpness | Laplacian / Tenengrad **baselines**; CPBD as blur-adjacent | Cheap, inspectable; Laplacian still noise-sensitive (document it) |
| Blur | **CPBD / JNB / FISH**; separate motion kernel if added | Current OpenCV Blur is not independent |
| Noise | Immerkaer σ, wavelet MAD, high-frequency residual with texture guard | Better than `1-min(n,0.85)` until humans exist |
| Brightness | Keep a **two-sided** exposure curve; add clip-fraction (highlight/shadow mass) | Head trained on mean gray is the wrong target |
| Contrast | RMS **plus** a clip/harshness penalty; Michelson as second baseline | RMS-only fights the rubric |
| Blocking | NR-JPEG **boundary** metrics (e.g. Wang 2002-style 8×8 discontinuities), not flat-patch rate | Current OpenCV metric is false construct |
| Ringing | Edge-halo energy (overshoot around Canny/Sobel) | Sign-flip rate is too generic |

Specialized learned attribute models (SPAQ multi-task, etc.) only if **license allows evaluation**. Do not ship pyiqa. Do not retrain EfficientNet on `SyntheticIQADataset`. MUSIQ stays **OPQ-only**.

**Judgement:** for Blocking, Contrast, and Sharpness/Blur overlap, classical metrics are **more appropriate to try** than the synthetic 7-head. For Noise and Ringing, classical NR metrics are the right **baselines**; heads are unproven until raw 0–1 + humans exist. EfficientNet is not shown to be better than OpenCV on any criterion (no criterion GT yet).

---

## 6. Controlled tests (research scripts later; not run here)

Use one sharp, well-exposed ACCESS-like still (or a small frozen set). Apply **one** distortion family at a time. Score with production `evaluate_bytes` **read-only** and, in parallel, candidate metrics. Expect **monotone** displayed quality vs distortion amount (except Brightness/Contrast, which are non-monotonic).

| Family | Stimulus | Expectation if the badge is valid |
|--------|----------|-----------------------------------|
| Blur | Gaussian σ ladder; **separately** linear motion length | Blur 1–5 falls as σ grows; Sharpness may fall too but **ranks** should not be identical on a mixed defocus+texture pack |
| Noise | AWGN σ ladder | Noise quality falls; Sharpness must not **rise** (Laplacian trap) |
| Exposure | EV / gain ladder around mid-gray | Brightness peaks near mid; both dark and clipped white score low |
| Contrast | Gain around mean; plus a crush+clip set | Rubric Contrast should drop on fog **and** on extreme crush, not only on fog |
| JPEG blocking | `cv2.IMWRITE_JPEG_QUALITY` 10…95 | Blocking quality rises with quality; **flat** uncompressed PNG should stay high |
| Ringing | Unsharp `addWeighted` amount ladder | Ringing quality falls as halo grows; in-focus unsharp image may keep Blur high |

Report Spearman of displayed score vs **known amount** (invert amounts). This is construct sensitivity, not human accuracy.

**Sharpness vs Blur double-counting test:** on the Gaussian ladder, correlate the two integers. If r ≈ 1.0 (or OpenCV identity), they are not independent. Add an in-focus, low-microcontrast image (downscale then upscale): Sharpness should drop more than Blur.

Do not use LIVEC MOS as the y-axis.

---

## 7. Sharpness vs Blur (keep distinct)

Rubric: Blur = optical/motion; Sharpness = remaining texture.

Production today:

- Train: `sharpness_label = 1 - blur_amount`.
- OpenCV: `blur = 1 - sharpness`.
- Overall mean includes **both**.
- Motion Stability reuses sharpness deltas.

**Roadmap rule:** one of (a) drop Blur from the mean and keep it as a diagnostic, (b) replace Blur with a motion/defocus detector that is not `1 − sharpness`, or (c) merge to a single “focus/detail” badge. Do not keep two badges that are linear inverses.

---

## 8. Improvement roadmap and acceptance criteria

No production change in this phase. Later work uses flags default **off**, rollback by flag, existing `test_media_quality_eval_correctness.py` green, authenticity/Gemini untouched.

| Step | Work | Measurable accept | Fail / stop |
|------|------|-------------------|-------------|
| **7.1 Read-only dump** | Log pre-`_soft_score` 0–1 heads on frozen Run 002 + OpenCV on same files | CSV of 7 raw keys + integers; no scoring change | If dump requires scoring edits, abort |
| **7.2 Controlled ladders** | Section 6 on production engine (read-only) | Per family: Spearman vs amount **≥ 0.80** (Brightness: peak within documented EV) | Blocking fails JPEG ladder or flags clean flats |
| **7.3 ACCESS human pilot** | Protocol already written, ≥3 raters, no MOS shown | IRR: off-by-more-than-1 rate documented; **do not** start if IRR is unusable | Invented scores |
| **7.4 Criterion Spearman** | Machine integer **and** raw 0–1 vs human median | Per criterion Spearman **≥ 0.60** on held-out images to call a badge “directionally useful”; **≥ 0.75** to consider replacing a heuristic | Using MOS instead of criterion medians |
| **7.5 Candidate metrics** | Classical NR vs same humans (section 5) | Winner per criterion by Spearman + usable 1–5 histogram (not one bin) | Shipping pyiqa |
| **7.6 `_soft_score` v2** | Only if 7.1 shows raw tracks humans and integers do not | 1 and 5 reachable on controlled worst/best; Run 002 rank vs humans **does not drop** | Changing bins from MOS bias alone |
| **7.7 Shadow sidecar** | New Blocking/Blur/… behind flags; `overall_score` **unchanged** until product says | Payload extra keys only; XP identical when flag off | Silent swap of overall/XP |
| **7.8 Retrain** | Only after real labels; **not** `SyntheticIQADataset` | Held-out human Spearman beats frozen `.pt` and beats the classical winner | Retrain on MOS or synthetic knobs |

**Do not** average MUSIQ into these badges. OPQ remains a separate channel (Phase 4–6).

---

## 9. Findings (short)

1. Five of seven badges are **construct-mismatched** in at least one of: training label, OpenCV formula, or display map (especially **Blocking = flatness**, **Contrast = RMS**, **Sharpness/Blur = one axis**, **Brightness head = mean gray**).
2. **`_soft_score` makes 1 unreachable** and Run 002 never used it; Contrast is almost constant.
3. **MUSIQ LIVEC 0.805 / 0.770 is not criterion validation.**
4. Public SPAQ/LIVE/TID labels can **stress-test** instruments; ACCESS humans are required for production claims.
5. Classical NR metrics are the right next **benchmarks** for Blocking, Blur, and Contrast; EfficientNet heads are not shown to be better.
6. Safe path: dump raw 0–1 → controlled ladders → human pilot → per-criterion Spearman gates → flag-shadow replacements. No retrain on synthetic data.

Stopped for review.
