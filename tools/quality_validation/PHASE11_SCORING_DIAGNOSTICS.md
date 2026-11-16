# Phase 11: Scoring diagnostics and calibration feasibility

**Generated:** 2026-11-07T08:19:24.207554+00:00
**Status:** research only. Production scoring was not changed. No retraining. SPAQ-200 files were not rewritten.

Input: existing `spaq_200_machine_scores.csv` (n=200, all EfficientNet). Seed `20261107`. Five-fold split stratified by MOS quintile (8 test images per stratum per fold, 40 test / 160 train).

## 1. Where compression happens

Production map (copied, not modified):

`boosted = clip(q * 0.5 + 0.42, 0, 1)` then 5/4/3/2/1 at 0.80 / 0.64 / 0.46 / 0.28.

- At q=0, boosted=0.42, badge=2.
- Badge **1 is unreachable** for any q in [0, 1]: needs boosted < 0.28, i.e. q < -0.28.
- Badge 2 only for q < 0.08. Badge 3 for q in [0.08, 0.44). Badge 4 [0.44, 0.76). Badge 5 q ≥ 0.76.

Quality `q` is not always the raw head: defect heads invert (`1-raw`; Noise also `min(raw, 0.85)`). Brightness `q` is a triangle around luma 0.48.

| Head | raw mean [min, max] | q mean [min, max] | q in bins 2/3/4/5 | badge hist 1–5 |
|------|---------------------|-------------------|-------------------|----------------|
| sharpness | 0.334 [0.071, 0.626] | 0.334 [0.071, 0.626] | 1/154/45/0 | 0/1/154/45/0 |
| blur | 0.701 [0.446, 0.927] | 0.299 [0.073, 0.554] | 2/180/18/0 | 0/2/180/18/0 |
| noise | 0.503 [0.173, 0.825] | 0.497 [0.175, 0.827] | 0/67/129/4 | 0/0/67/129/4 |
| brightness | 0.528 [0.292, 0.744] | 0.824 [0.420, 1.000] | 0/2/52/146 | 0/0/2/52/146 |
| contrast | 0.184 [0.025, 0.506] | 0.184 [0.025, 0.506] | 20/174/6/0 | 0/20/174/6/0 |
| blocking_artifacts | 0.612 [0.250, 0.915] | 0.388 [0.085, 0.750] | 0/131/69/0 | 0/0/131/69/0 |
| ringing_artifacts | 0.549 [0.271, 0.824] | 0.451 [0.176, 0.729] | 0/94/106/0 | 0/0/94/106/0 |

Reconstructed `_soft_score(q)` matched stored badges on 1400 cells, mismatches=0.

### Why particular integers dominate

- **Brightness:** raw heads sit near mid/high luma, triangle `q` is high, so most photos land in the badge-5 bin (q ≥ 0.76).
- **Contrast / Sharpness:** q piles in the wide badge-3 interval [0.08, 0.44).
- **Noise:** after invert, many q values sit in badge 3–4.
- **Overall:** mean of seven integers in a narrow set, so MOS-stratified photos still get overall 3.0–4.0.

This is mapping geometry plus raw-head concentration. It is not a display bug in Flutter.

## 2. Useful signal in raw heads? (exploratory, n=200, not held-out)

Spearman on the same 200 used in Phase 10. This describes information loss, it is **not** a new independent validation.

| Pair | raw/amount | q (quality) | integer badge | linear continuous 1–5 | equal-bin int |
|------|------------|-------------|---------------|----------------------|---------------|
| overall_mos | 0.171 | -0.018 | -0.067 | -0.018 | -0.017 |
| noise | 0.290 | 0.290 | 0.264 | 0.290 | 0.294 |
| sharpness | 0.117 | 0.117 | 0.086 | 0.117 | 0.120 |
| brightness | -0.075 | 0.060 | 0.045 | 0.060 | 0.070 |
| contrast | -0.147 | -0.147 | -0.028 | -0.147 | -0.108 |

Math: a **strictly increasing** remap of one series cannot change Spearman against humans. Affine `a*x+b` with a>0 also leaves Pearson unchanged. Integer bins **can** change Spearman by adding ties. Averaging seven quantized heads **can** change overall ranking relative to averaging seven continuous `q` values.

Exploratory MOS: badge overall Spearman -0.067; mean of seven `q` -0.018; mean of seven raw heads 0.171.

## 3. Held-out results (5-fold, fit on train only)

Each fold: 160 train / 40 test, 8 images from each MOS quintile. Supervised models never see test labels while fitting. Numbers below are **mean ± std of Spearman across folds**.

| Method | Changes ranking? | Fit uses labels? | Spearman mean (std) |
|--------|------------------|------------------|---------------------|
| MOS vs production overall badge | yes vs raw (quantize+mean) | no | -0.066 (0.081) |
| MOS vs mean of 7 `q` (held-out) | vs badge: yes | no | -0.003 (0.070) |
| MOS ridge on 7 raw heads | yes | yes | 0.366 (0.142) |
| MOS ridge on 7 `q` | yes | yes | 0.368 (0.138) |
| MOS ridge on 7 badges | yes | yes | 0.282 (0.133) |
| Noise vs `q` (held-out) | no vs raw invert | no | 0.306 (0.068) |
| Noise vs badge (held-out) | ties | no | 0.264 (0.144) |
| Noise univariate linear on `q` | no if slope>0 | yes | 0.306 (0.068) |
| Noise isotonic on `q` | ties only | yes | 0.306 (0.068) |
| Noise train-quantile 5 bins | ties | yes (x only) | 0.269 (0.068) |
| Sharpness vs `q` / badge | | no | 0.102 (0.095) / 0.097 (0.052) |
| Sharpness linear / isotonic / train bins | | mixed | 0.102 (0.095) / 0.102 (0.095) / 0.132 (0.061) |
| Brightness vs `q` / badge | | no | 0.072 (0.069) / 0.051 (0.135) |
| Brightness linear / isotonic / train bins | | mixed | 0.072 (0.069) / 0.069 (0.068) / 0.062 (0.057) |
| Contrast vs `q` / badge | | no | -0.145 (0.093) / -0.039 (0.095) |
| Contrast linear / isotonic / train bins | | mixed | 0.145 (0.093) / -0.145 (0.093) / -0.138 (0.142) |

Blur, Blocking, and Ringing have **no SPAQ labels**. They are omitted from correlation tables.

## 4. What mapping can and cannot do

- **Cannot** create Sharpness / Brightness / Contrast / MOS agreement if the **q / raw ranking** itself is near zero vs SPAQ. Monotone calibration cannot invent rank signal.
- **Can** change member-visible histograms (emit 1, reduce Brightness-at-5 pile-up) with an a priori ladder such as equal-width bins on `q`. That is a **display** change. It does not by itself make SPAQ Spearman large.
- **Can** slightly change Spearman via fewer ties (continuous `q` vs 3-level badges). Phase 10 already showed MOS vs raw-mean ~0.17 vs badge ~0.
- **Can** re-rank overall by learning weights on seven heads (ridge). That is a different predictor, not a display remap of the current overall mean. Held-out ridge Spearman must beat held-out `q`-mean and badge to count as evidence.

## 5. Recommended next steps (evidence / feasibility / risk)

Ranked after the numbers in this file. Production stays frozen until you approve a later change.

1. **Treat member badges as compressed by design.** Evidence: unreachable 1, Brightness q in the 5-bin, Contrast/Sharpness in the 3-bin. Feasible display-only remap exists. Risk: XP and copy that assume 1–5 meaning.
2. **Do not expect calibration of Sharpness, Brightness, Contrast, or overall badges to match SPAQ.** Held-out univariate maps track `q`, which is weakly aligned. Needs a **better predictor** (new labels, new heads, or a validated IQA model), not a new `_soft_score`.
3. **Noise is the only SPAQ-aligned criterion with weak signal.** Mapping cannot turn 0.26 into a strong IQA score. Optional later work: keep invert, consider less quantization, or collect ACCESS-native noise ratings.
4. **If overall MOS tracking is the product goal, evaluate a MOS-trained model (research MUSIQ/official TF Hub already in the toolkit) as a separate overall channel.** Do not silently replace the seven-head mean. High risk if mixed into XP without a product decision.
5. **Do not retrain EfficientNet on these 200 SPAQ photos.** n is small and would leak this evaluation set.

No production changes were implemented.

