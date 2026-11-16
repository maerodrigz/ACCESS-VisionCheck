# ACCESS VisionCheck — Tenengrad Sharpness + OpenCV residual Noise prototype: implementation-readiness report

**Status:** research-only prototype and readiness report. NOT an implementation approval.
**Generated:** 2026-11-07.
**Sources:** `sharpness_noise_prototype.py` run over the locked SPAQ-200 at 1024 px (n=200, 0 failures, 111.6 s), the Phase 12 implementation decision matrix, and the Phase 13 runtime report.

Strict constraints honored: no production code changed, no engine switched, no thresholds fit on SPAQ-200, no data downloaded, no models retrained, Phase 10-13 outputs untouched, all uncommitted git changes preserved.

## 0. Scope and direction contract

Two candidate metrics, both at a 1024 px longest-side resize cap (INTER_AREA, no upscale), chosen from Phase 12/13 evidence:

- **Tenengrad sharpness** — raw energy `mean(gx*gx + gy*gy)`, Sobel ksize=3. Higher = sharper = BETTER. UNBOUNDED.
- **OpenCV residual noise** — `std(|gray - GaussianBlur(gray,5,5)|)`. Higher = more noise = WORSE. The member-facing "Noise" badge is a CLEANLINESS score (higher = less noise = better), so a quality badge must INVERT this axis.

Production reference (unchanged, read-only): EfficientNet-B0 seven-head raw sigmoid outputs (`raw_sharpness`, `raw_noise`, ...) routed through `media_evaluator._photo_criteria` -> `_soft_score` -> 1-5 badges.

## 1. Prototype execution status and actual results

Executed `tools/quality_validation/sharpness_noise_prototype.py` over all 200 SPAQ-200 images, 1024 px cap, repeat 1, warmup 1. **200/200 scored, 0 failures, 111.6 s** (~0.56 s/img). Outputs (new, separate from Phase 10-13): `workspace/datasets/spaq/output/sharpness_noise_prototype/sharpness_noise_prototype.json` + `.csv`.

Exploratory Spearman vs SPAQ human ratings (n=200, 95% bootstrap CI; NOT used to fit anything):

| Candidate metric (1024 px) | vs human field | Spearman r | 95% CI | Pearson |
|---|---|---|---|---|
| Tenengrad | attr_sharpness_raw | 0.753 | 0.679-0.799 | 0.541 |
| OpenCV residual noise (std) | attr_noisiness_raw | 0.682 | 0.601-0.745 | 0.637 |
| opencv_sharpness_1024 (prod Laplacian/420) | attr_sharpness_raw | 0.744 | 0.685-0.796 | 0.748 |
| opencv_noise_1024 (prod residual/36) | attr_noisiness_raw | 0.682 | 0.601-0.745 | 0.637 |

For reference, production ENET raw on the same set: `raw_sharpness` vs attr_sharpness = 0.117 (CI -0.02-0.24); `raw_noise` vs attr_noisiness = 0.290. The candidate metrics agree with human sharpness/noisiness far more strongly than the current ENET heads, consistent with Phase 12.

Cross-construct comparison (candidate vs production, exploratory):

| Candidate | vs production | Spearman |
|---|---|---|
| Tenengrad vs ENET raw_sharpness | 0.070 (CI -0.06-0.19) | near zero |
| Tenengrad vs prod criterion_Sharpness badge | 0.113 | near zero |
| residual noise vs ENET raw_noise | 0.307 | weak-moderate |
| residual noise vs prod criterion_Noise badge | -0.267 | negative (correct: more noise -> lower cleanliness badge) |

Reading: Tenengrad and the ENET sharpness head measure different things (r approx 0.07). Replacing the sharpness axis would change which photos score high, not just rescale them.

## 2. Existing vs candidate score distributions (n=200)

| Metric | min | p5 | median | mean | p95 | max | n_unique | direction |
|---|---|---|---|---|---|---|---|---|
| Tenengrad (raw) | 79 | 465 | 3730 | 6288 | 18372 | 68748 | 200 | higher=better |
| OpenCV residual noise (std) | 0.37 | 0.82 | 3.82 | 4.47 | 10.54 | 20.16 | 200 | higher=worse |
| opencv_sharpness_1024 (prod /420) | 0.004 | 0.038 | 0.564 | 0.564 | 1.000 | 1.000 | 124 | higher=better |
| opencv_noise_1024 (prod /36) | 0.010 | 0.023 | 0.106 | 0.124 | 0.293 | 0.560 | 200 | higher=worse |
| ENET raw_sharpness (prod) | 0.071 | 0.144 | 0.338 | 0.334 | 0.524 | 0.626 | 200 | higher=better |
| ENET raw_noise (prod) | 0.173 | 0.286 | 0.495 | 0.503 | 0.748 | 0.825 | 200 | higher=worse(amount) |

Notable:
- Tenengrad is unbounded (79-68748), 200 unique values: high discrimination, but it cannot be fed to `_soft_score` (expects [0,1]) without an a-priori normalization.
- opencv_sharpness_1024 saturates at 1.0 (p95=max=1.0; only 124/200 unique values). The majority of SPAQ-200 images clip at the /420 ceiling, i.e. the production OpenCV sharpness constant (420) is mis-scaled at 1024 px. (Out of scope here: we propose Tenengrad, not OpenCV sharpness.)
- ENET raw sharpness/noise are well-spread in [0,1] (200 unique each).

## 3. Expected impact on the seven displayed badges

All seven member-facing badges (Sharpness, Blur, Noise, Brightness, Contrast, Blocking Artifacts, Ringing Artifacts) currently use `_soft_score`. Current production badge distributions on SPAQ-200 (ENET-driven, from the locked CSV):

| Badge | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| Sharpness (ENET) | 0 | 1 | 154 | 45 | 0 |
| Noise (ENET cleanliness) | 0 | 0 | 67 | 129 | 4 |

Sharpness piles at 3 (154/200) and never reaches 5; Noise is confined to 3-5 (1 and 2 unreachable). This is the documented Phase 11/12 compression problem.

Illustrative candidate badges using the EXISTING `_soft_score` on the [0,1] candidate metrics at 1024 (NOT a fitted calibration, only to show compression behavior):

| Illustrative badge | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| opencv_sharpness_1024 as Sharpness | 0 | 30 | 60 | 22 | 88 |
| cleanliness (1 - opencv_noise_1024) as Noise | 0 | 0 | 0 | 25 | 175 |

Feeding the candidate metrics through the existing `_soft_score` does NOT fix the compression: Noise collapses to 175/200 at badge 5, and badge 1 is still unreachable for any [0,1] input. **A new a-priori ladder is required; reusing `_soft_score` is not viable.**

Expected impact if only Sharpness and Noise axes are swapped (others untouched): the Sharpness pile-up at 3 would move toward a real 1-5 spread (good), but only if the new ladder can reach badge 1; Noise needs the cleanliness inversion plus a new ladder that can reach 1-2 for genuinely noisy photos. Blur, Blocking, Ringing stay on the ENET heads. `overall_score` (mean of seven badges) would rebalance as the Sharpness mid-pile is relieved; XP (which uses overall_score) must be reviewed under the flag.

## 4. Runtime and integration risks

Phase 13 measured at 1024 px (median): decode 266 ms, resize 15 ms, OpenCV analyze 292 ms, Tenengrad 19 ms; ~0.59 s/img on CPU (8 cores). The prototype confirmed 111.6 s / 200 (~0.56 s/img).

- CPU cost: Tenengrad + residual add ~37 ms analysis on top of resize; if the candidate path skips full `analyze_bgr` (blocking/ringing), it is far cheaper than the ENET path (~2 s/img, Phase 10).
- Engine coupling: `media_evaluator._photo_criteria` consumes the engine metrics dict (ENET 7 keys or OpenCV 7 keys). A candidate path adds two keys computed after a 1024-px resize. Introducing a resize cap is a behavioral change for ALL engines, not just the candidate. Phase 13 measured OpenCV/Tenengrad at 1024; ENET at 1024 was NOT measured and must be checked before any resize-cap deploy that touches the ENET path.
- Saturation: opencv_sharpness_1024 clips at 1.0 for most images (/420 too small at 1024). If OpenCV sharpness were ever used, retune 420; out of scope here.
- Determinism: Tenengrad and residual are deterministic given bytes + resize (same bytes -> same scores), matching the production determinism contract.
- Reversibility: all changes behind new config flags (see section 6); no DB schema change; badges remain 1-5 ints.

## 5. Proposed independent-data 1-5 calibration method (NOT fit on SPAQ-200)

SPAQ-200 is a related proxy and LOCKED; it must NOT be used to fit thresholds (training-on-test). Proposed method:

1. A-priori ladder, declared BEFORE measuring on any labeled set. Fixed anchors from the metric's physical meaning, not data percentiles:
   - Tenengrad: `min(1, tg / T_ref)` with `T_ref` chosen a priori (not a SPAQ percentile), then 1-5 bins that CAN reach badge 1.
   - Residual noise: invert to cleanliness `C = 1 - min(1, std / N_ref)` with `N_ref` fixed a priori, then 1-5 bins that reach badge 1 for genuinely noisy photos.
   Ladders committed/pre-registered before any held-out correlation is computed.
2. Independent labeled development set: ACCESS-native 1-5, NO download. Use the existing `HUMAN_RATING_RUBRIC.md` 1-5 protocol: officers rate a held-out set of real ACCESS member photos on Sharpness and Cleanliness, split declared before scoring (`HUMAN_VALIDATION_PROTOCOL.md`). Independent of SPAQ-200. (Phase 10 30-photo pack is currently empty, so this set must be collected: a prerequisite, not a blocker for the prototype.)
3. Validate, don't fit: on the independent set, check monotonicity of candidate badge vs human 1-5 and report held-out Spearman. Do NOT refit cut points on this set and report the same set as validation (Phase 11 anti-pattern). If a map must be tuned, declare the split first or reuse declared folds.
4. Optional future cross-check (gated, not now): an independent public IQA MOS set (e.g. KonIQ-10k) as an overall-only anchor, only if/when its media is obtained under a separate download approval. Not required for the Sharpness/Noise axes and not used in this task.

Until step 2's independent set exists, the prototype stays research-only and is NOT deployed.

## 6. Exact production changes recommended (NOT implemented)

All behind new config flags, default-off, reversible:

1. `app/services/opencv_quality.py` (or a new `technical_quality.py`): add `tenengrad(bgr)` and `residual_noise_std(bgr)` helpers (matched in the prototype). Do NOT change existing `analyze_bgr`.
2. `app/config.py`: add `TECHNICAL_QUALITY_RESIZE_CAP` (default 0 = off; 1024 when enabled) and `TECHNICAL_QUALITY_AXES` (default empty; candidate set = `sharpness=tenengrad,noise=residual`).
3. `app/services/media_evaluator.py`: when the flag is on, after the engine produces metrics, compute Tenengrad + residual on the 1024-px resize and (for selected axes only) override the Sharpness/Noise badge via a NEW a-priori ladder function (not `_soft_score`). Keep ENET/Blur/Blocking/Ringing/Brightness/Contrast unchanged.
4. A new `technical_quality_ladder.py` with the declared a-priori 1-5 maps (section 5), unit-tested, no SPAQ dependency.
5. DB: no schema change; badges stay 1-5 ints. Add a `quality_engine`/`scoring_engine` audit tag (e.g. `technical-prototype`).
6. Flutter / API / XP / authenticity / Gemini: NO changes. The badge shape is unchanged (still 1-5 per criterion), so the API contract and Flutter display are untouched. XP uses `overall_score`; rebalancing is expected and must be reviewed under the flag.
7. Member copy: "higher = better" still holds for all seven badges; Noise badge remains cleanliness (higher = less noise = better). Document the inversion in code only.

Reversibility: disable the config flag -> exact current behavior. No migration needed.

## 7. Unresolved issues

- `_soft_score` signature mismatch (latent, NOT live). `image_quality.py` defines `_soft_score(metric: float)` (1-arg) but `build_evaluation_payload` calls it as `_soft_score(metric, lo, hi)` (3-arg), a `TypeError` if executed. Investigation: production imports only `parse_client_payload` and `legacy_scores_from_payload` from `image_quality` (in `media_pipeline.py` and `media_evaluator.py`); nothing imports `analyze_bytes` or `build_evaluation_payload`. The live photo path is `media_evaluator._photo_criteria` + `media_evaluator`'s own 1-arg `_soft_score` (line 416). So the mismatched function is DORMANT, not called in the active pipeline. Not fixed per instruction; flagged for a separate cleanup. Do not delete `image_quality.analyze_bytes` without confirming no route/test uses it (none found).
- `_soft_score` unreachable-1 / pile-up is structural and affects the current ENET badges too (Sharpness piles at 3; Noise confined to 3-5). Any candidate deploy must replace the ladder, not reuse `_soft_score`.
- OpenCV sharpness saturation at 1024 px (most images clip at 1.0): the production `/420` constant is mis-scaled at 1024. Out of scope (we propose Tenengrad); flagged if OpenCV sharpness is ever considered.
- Independent labeled dev set missing (Phase 10 pack empty). Blocks any deploy; collection is the gating prerequisite.
- Tenengrad vs ENET sharpness r approx 0.07: the candidate measures a different construct. Stakeholders must accept that "sharp" photos will rerank, not just rescale. Member-facing impact must be reviewed on real ACCESS photos, not SPAQ.
- ENET at 1024 not measured (Phase 13 measured OpenCV/Tenengrad only). Before any resize-cap deploy affecting the ENET path, measure ENET at 1024 to confirm no regression.

## Classification: human-rated proxies vs technical heuristics

| Item | Class | Allowed claim |
|---|---|---|
| Tenengrad vs SPAQ attr_sharpness (r 0.753) | Human-rated proxy (SPAQ) | Related-proxy agreement on these 200; not ACCESS-native 1-5; not a license to fit on SPAQ |
| Residual noise vs SPAQ attr_noisiness (r 0.682) | Human-rated proxy (SPAQ) | Same |
| opencv_sharpness_1024 / opencv_noise_1024 distributions | Technical only | Construct/sensitivity; no human-accuracy claim beyond the proxy above |
| Badge pile-up / unreachable-1 analysis | Technical (compression) | Structural defect of `_soft_score`; not a human-accuracy claim |
| Blur / Blocking / Ringing (unchanged ENET) | Technical + Phase 8 | No SPAQ label; keep as-is until a labeled set exists |

## `_soft_score` compression (reference)

```
boosted = clip(metric*0.5 + 0.42, 0, 1)
5: boosted >= 0.80  -> metric >= 0.76
4: 0.64 <= boosted < 0.80 -> 0.44 <= metric < 0.76
3: 0.46 <= boosted < 0.64 -> 0.08 <= metric < 0.44
2: 0.28 <= boosted < 0.46 -> 0.00 <= metric < 0.08
1: boosted < 0.28 -> metric < -0.28  (UNREACHABLE for any [0,1] input)
Noise cleanliness = 1 - min(noise,0.85) in [0.15,1.0] -> boosted in [0.495,0.92] -> badges in {3,4,5} only
```

No production code was changed. No Phase 10-13 output was modified. Stopped for approval.
