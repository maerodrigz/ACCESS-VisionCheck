# ACCESS VisionCheck — Brightness and Contrast automated research (final report)

**Status:** automated diagnostic research complete for the approved scope.  
**Date compiled:** 2026-11-08.  
**Scope:** research documentation only. No production integration.

This report compiles verified outputs from:

1. Production EfficientNet-B0 / OpenCV controlled KonIQ diagnostic (`brightness_contrast_controlled`, generated 2026-11-08T00:44:09Z).
2. Research candidates B1/B2/C1/C2 on the same variants (`brightness_contrast_candidates`, generated 2026-11-08T01:13:54Z).
3. 200-image LIVEC evaluation (`run_bc_livec_001`, generated 2026-11-08T03:28:43Z, seed `20261108`).
4. Read-only review of 14 low-key B2 flags (saved CSV/JSON plus JPEG inspection).
5. `HUMAN_RATING_RUBRIC.md` and `HUMAN_VALIDATION_PROTOCOL.md`.

Locked SPAQ-200 was not used. Candidate parameters were not fit on any of these sets. No winner is selected.

---

## 1. Objectives and scope

**Product question:** are member-facing Brightness and Contrast 1–5 badges measuring *exposure quality* and *tonal-separation quality*, or mainly luminance/contrast *magnitude*?

**Approved work (automated, research-only):**

- Score existing production EfficientNet-B0 and OpenCV paths on controlled KonIQ variants.
- Score a priori candidates B1, B2, C1, C2 on the same variants and on 200 LIVEC test photos.
- Report distributions, saturation, disagreement, and heuristic false-positive flags.
- Treat LIVEC MOS as overall quality context only.

**Out of scope:** production code, Flutter, APIs, database, weights, `_soft_score` thresholds, Sharpness, Noise, SPAQ-200, fabricated human ratings, candidate retuning, deployment.

Human 1–5 collection is postponed (no available raters). Protocol and rubric exist; rating sheets were not filled.

---

## 2. Existing production scoring behavior

Member badges use production EfficientNet-B0 heads when available, with OpenCV as a separate engine in the controlled study (independent scoring, no silent substitution). Brightness `q` is a triangle around luma 0.48 (`_brightness_metric`). Contrast uses the raw head (OpenCV: grayscale std / 72). Integer badges use `_soft_score`: `boosted = clip(q * 0.5 + 0.42, 0, 1)` then bins at 0.80 / 0.64 / 0.46 / 0.28. Badge **1 is unreachable** for any `q` in [0, 1].

Verified on 40 KonIQ sources × 7 variants × 2 engines = **560 records, 0 failures**:

| Engine | n | Brightness hist 1–5 | Contrast hist 1–5 | Badge 1 reachable |
|--------|---|---------------------|-------------------|-------------------|
| EfficientNet-B0 | 280 | 0 / 0 / 12 / 91 / 177 | 0 / 3 / 263 / 14 / 0 | False |
| OpenCV | 280 | 0 / 18 / 98 / 80 / 84 | 0 / 2 / 98 / 65 / 115 | False |

Mean Brightness badge on **severely underexposed** (luma_mean 0.1044): ENET **4.725**, OpenCV **2.825**. ENET Brightness does not drop on severe under-exposure in this design.

Objective tracking (n=280): Spearman(ENET raw brightness, luma_mean) **0.154**; Spearman(ENET raw contrast, gray_std) **−0.191**. OpenCV raw brightness vs luma_mean **1.0**; raw contrast vs gray_std **0.991** (by construction).

Direction (40 sources): ENET Brightness `severely_underexposed <= 2`: **0**. OpenCV Contrast is monotone in magnitude on **40/40** and awards high badges to excessively high contrast (mean badge 4.725 on that variant).

These results are diagnostic of engine behavior. They are not human perceptual validation.

---

## 3. Research candidates (unchanged a priori)

Implemented in `brightness_contrast_candidates.py`. Parameters are placeholders. Diagnostic 1–5 anchors `[0.20, 0.40, 0.62, 0.82]` are **temporary and unvalidated**.

| ID | Construct | Core formula (research) |
|----|-----------|-------------------------|
| B1 | Luminance-distribution baseline | Triangle at mean luma 0.5, × mid-tone coverage |
| B2 | Clipping-aware exposure | Same triangle × bounded clip-spike penalty × bounded near-black/white *band* penalty |
| C1 | Global + local contrast | Saturating mix of luma std and block std; plateaus; no clip penalty |
| C2 | Clipping-aware contrast | C1 saturating score × one combined, bounded extremes fraction |

`detail_mid_raw` is recorded only. It is not in B or C quality. Video aggregation is not implemented.

---

## 4. Controlled evaluation (KonIQ 40 × 7)

**Method:** a priori gains: underexposed 0.55, severely_underexposed 0.25, overexposed 1.6, severely_overexposed 2.8, low_contrast 0.4, excessively_high_contrast 2.2, plus original. Same 280 PNGs for candidates. **280/280** candidate rows, 0 failures.

**Mean diagnostic labels (40 sources):**

| Variant | B1 | B2 | C1 | C2 | ENET B | OpenCV B | ENET C | OpenCV C |
|---------|----|----|----|----|--------|----------|--------|----------|
| original | 3.275 | 3.4 | 3.7 | 2.85 | 4.55 | 4.25 | 2.975 | 4.475 |
| underexposed | 2.4 | 2.575 | 2.925 | 2.425 | 4.7 | 3.575 | 3.05 | 3.525 |
| severely_underexposed | 1.2 | 1.425 | 2.075 | 1.575 | 4.725 | 2.825 | 3.1 | 2.975 |
| overexposed | 2.575 | 2.35 | 3.75 | 1.9 | 4.425 | 3.85 | 3.05 | 4.675 |
| severely_overexposed | 1.975 | 1.775 | 3.825 | 1.525 | 4.425 | 3.45 | 3.025 | 4.725 |
| low_contrast | 4.725 | 4.725 | 2.7 | 2.7 | 4.825 | 4.825 | 3.05 | 3.225 |
| excessively_high_contrast | 2.25 | 1.725 | 3.825 | 1.125 | 4.475 | 3.975 | 3.025 | 4.725 |

**Direction (n=40):** B1/B2 severe_under_low: **40/40**. ENET: **0/40**. C2 drops at excessive contrast: **31/40**. C1 drops at excessive: **0/40** (monotone 40/40). OpenCV contrast also **0** drops at excessive.

On **original** photos: 7 low-key (`luma_mean < 0.25`); B2 ≤ 2 with no clip spike: **4** sources. High-key with that B2 rule: **0**.

---

## 5. LIVEC sampling and evaluation

**Declared before scoring:** seed `20261108`, n=200 test images, 40 per MOS quintile of the 1,162 LIVEC test MOS values. Training `t1.bmp`–`t7.bmp` excluded. Controlled KonIQ stems excluded (0 collisions). Unique keys: 200. **200/200 ok**, 0 partial, 0 failed. Wall **38.71 s** (mean 193.5 ms/image). SPAQ-200 not accessed. Parameters not updated.

LIVEC MOS is overall LIVE Challenge quality. It is **not** ACCESS Brightness or Contrast ground truth.

---

## 6. Comparison of all six methods (LIVEC n=200)

Diagnostic candidate labels vs production badges. Integer gap ≥ 2 counts disagreement, not accuracy.

| Method | 1 | 2 | 3 | 4 | 5 | mean | floor% | ceiling% |
|--------|---|---|---|---|---|------|--------|----------|
| B1 | 11 | 17 | 27 | 80 | 65 | 3.855 | 5.5 | 32.5 |
| B2 | 10 | 15 | 33 | 62 | 80 | 3.935 | 5.0 | 40.0 |
| C1 | 0 | 1 | 63 | 136 | 0 | 3.675 | 0.0 | 0.0 |
| C2 | 13 | 10 | 111 | 66 | 0 | 3.15 | 6.5 | 0.0 |
| ENET Brightness | 0 | 0 | 1 | 50 | 149 | 4.74 | 0.0 | 74.5 |
| ENET Contrast | 0 | 25 | 173 | 2 | 0 | 2.885 | 0.0 | 0.0 |
| OpenCV Brightness | 0 | 1 | 21 | 49 | 129 | 4.53 | 0.0 | 64.5 |
| OpenCV Contrast | 0 | 0 | 17 | 77 | 106 | 4.445 | 0.0 | 53.0 |

Selected disagreements (n=200): ENET vs OpenCV **contrast 115**; C2 vs OpenCV contrast 63; B2 vs ENET brightness 48; C1 vs OpenCV contrast **1**; B1 vs B2 **2**.

Supplementary Spearman vs **overall MOS** (not attribute GT): C2 0.322, Q_B2 0.293, OpenCV brightness 0.294, B1 0.256, **ENET brightness 0.010**, **ENET contrast 0.005**. These numbers do not authorize replacing badges with MOS-aligned predictors.

---

## 7. Floor and ceiling

- Production `_soft_score` never produced Brightness or Contrast **1** on 280 controlled rows or 200 LIVEC photos.
- ENET Brightness on LIVEC: **74.5%** at 5. ENET Contrast: **86.5%** at 3 (173/200).
- OpenCV Contrast on LIVEC: **53.0%** at 5; on controlled excessive-contrast variants mean badge 4.725.
- C1 never reaches 5 on this LIVEC sample (saturating map). C2 never reaches 5 here either.
- B1/B2 can emit 1–2 because they are not passed through `_soft_score`. That is a display-map difference, not proof of better human agreement.

---

## 8. Low-key B2 cases (LIVEC, n=14)

Flag: `luma_mean < 0.25`, `clip_lo < 0.05`, B2 label ≤ 2. IDs from saved JSON:

`100.bmp`, `120.bmp`, `4.bmp`, `633.JPG`, `838.JPG`, `613.JPG`, `615.JPG`, `782.JPG`, `825.JPG`, `1001.JPG`, `614.JPG`, `1041.JPG`, `1092.JPG`, `387.bmp`.

B2 is `triangle(luma_mean) × (1 − 0.6·clip_pen) × (1 − 0.2·band_pen)`. Clip spikes are **not** the cause. The triangle at mean luma 0.5 is. Night photos with `band_lo` 0.37–0.48 (613/614/615/1041) take the extra band penalty.

Viewed JPEGs (no human 1–5 assigned): night hotels and streets with lit subjects and black sky (613–615, 782, 838, 1041, 1092); dim bar (825); indoor pumpkin with flashlight (1001); indoor playground with a readable child (633). Four `.bmp` files were not viewable in the image reader; metrics only.

ENET Brightness is 4 or 5 on all 14. OpenCV is 3 (one 4). Overall MOS still spans Q1–Q5 (e.g. 1041 MOS 75.9 and 1092 MOS 77.9 with B2 = 1–2). Mean-frame darkness is not overall quality, and is not the rubric’s “subject well exposed.”

On controlled originals the same B2 rule flagged **4** of 7 low-key KonIQ sources. Pattern is consistent: global luma heuristics vs subject-centric exposure.

---

## 9. Limitations of mean-luminance exposure scoring

ACCESS rubric Brightness: *Is the important subject well exposed?* A backlit portrait with a readable face can still score 4.

B1/B2 (and OpenCV mean luma / ENET luma-like heads after a global triangle) score the **whole frame**. Night sky, unlit ground, and dim rooms pull the mean down even when the subject holds tone. That is a construct mismatch, documented on the 14 LIVEC flags. It is not evidence to invert or replace production Brightness without human ratings on the subject.

---

## 10. Contrast candidate limitations

- **C1** tracks magnitude (saturates). On controlled data it never drops at excessive contrast (0/40). On LIVEC it piles at 4 (136/200) and never hits 5. It can still score ≥ 4 when `extremes > 0.20` (7 flags).
- **C2** penalizes a combined shadow+highlight fraction. It drops at excessive contrast on 31/40 controlled sources (mean label 1.125 on that variant). It can punish intentional high-contrast night or stage lighting. Flat-scene C2 ≤ 2 on LIVEC: `263.bmp`, `893.JPG` (heuristic only).
- **OpenCV contrast** follows gray_std and **rewards** the excessive-contrast knob.
- **ENET contrast** stays near badge 3 on both studies and has **negative** Spearman vs gray_std on controlled rows (−0.191). Phase 12 SPAQ Contrast (separate, locked set; not re-opened here) previously showed ENET Contrast sign problems vs SPAQ humans. This LIVEC run does not re-test SPAQ.

No contrast candidate is perceptually validated.

---

## 11. Overall MOS vs attribute-specific quality

| Quantity | What it is | Allowed use here |
|----------|------------|------------------|
| LIVEC MOS | Crowdsourced **overall** picture quality | Supplementary Spearman only |
| ACCESS Brightness 1–5 | Subject exposure (rubric) | **No** LIVEC MOS as GT |
| ACCESS Contrast 1–5 | Tonal separation without harsh clip as the main look | **No** LIVEC MOS as GT |
| Production overall badge | Mean of seven badges | Not this study’s target |

`HUMAN_VALIDATION_PROTOCOL.md`: published MOS must never be copied into Brightness or Contrast. Independent overall is a separate column. This phase collected **zero** human criterion ratings (`workspace/human_pilot/` has instructions only).

---

## 12. Human-validation requirements (still unmet)

From the rubric and protocol; not executed:

- At least three blinded raters, integers 1–5, subject-centric Brightness and Contrast.
- Do not show MOS or machine scores.
- Include night-with-lights, dim indoor, crushed-subject, flat, and harsh-clip examples. The locked 14 LIVEC IDs plus high-MOS night photos (1041, 1092, 387) are a natural slice **after** raters exist.
- Do not fit B2/C2 on those ratings using the same photos as the confirmation set without a predeclared split.
- Facilitator log and training pack; no invented scores in git.

---

## 13. Recommendations for future work

1. Keep production scoring frozen. Do not integrate B1/B2/C1/C2.
2. Do not retune candidates on KonIQ variants or this LIVEC 200.
3. When raters are available, rate Brightness/Contrast on a subset of `run_bc_livec_001` (include the 14 low-key IDs). Compare humans to B2 vs ENET vs OpenCV **after** lock.
4. Treat night scenes as a planned stratum, not as automatic underexposure.
5. Contrast: decide whether “harsh clip” is a penalty (C2-like) or magnitude (C1/OpenCV) using humans, not MOS.
6. Video aggregation remains unspecified research.
7. SPAQ-200 stays locked unless a later phase explicitly reopens it.

---

## 14. Final research-only conclusion

Automated diagnostic research is **complete** for the currently approved scope (controlled KonIQ 40×7, candidates on those 280 images, LIVEC 200, read-only low-key B2 review).

**No candidate has been validated as more perceptually accurate** than production Brightness or Contrast. Controlled and LIVEC numbers describe engine and heuristic *behavior* (luma tracking, saturation, night-sky mean luma, excessive-contrast penalties). They do not measure ACCESS rubric agreement.

**No candidate is approved for production integration.** Temporary 1–5 anchors remain unvalidated. Parameters were not fit on these data.

**Human attribute-specific validation remains necessary** before any scoring change.

**Existing production scoring remains unchanged by this research.** EfficientNet-B0, OpenCV production metrics, `_soft_score`, APIs, Flutter, weights, and thresholds were not modified for this report. Pre-existing uncommitted production diffs were preserved and not restored.

Artifacts (do not overwrite):

- `workspace/datasets/brightness_contrast_controlled/`
- `workspace/datasets/brightness_contrast_candidates/`
- `workspace/datasets/livec/output/run_bc_livec_001/`
