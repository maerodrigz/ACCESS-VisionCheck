# Production integration recommendation (experimental_classical_v1)

**Status:** Research-only. **Do not merge into production yet.**

## What was built

| Artifact | Path |
|----------|------|
| Experimental engine | `tools/quality_validation/experimental_quality_engine.py` |
| Evaluation runner | `tools/quality_validation/run_experimental_quality_eval.py` |
| Unit tests | `tools/quality_validation/tests/test_experimental_quality_engine.py` |
| This evaluation package | `tools/quality_validation/workspace/experimental_quality/output/exp_eval_20261108T121451Z/` |

Production EfficientNet-B0, OpenCV fallback, `_soft_score`, FastAPI, Flutter, Run 001/002, and human CSVs were **not** modified.

## When integration would be justified

Only after **all** of the following:

1. Stable positive Spearman vs ACCESS-rubric human medians on a **disjoint** labeled set (not the 30-pilot tuning/check set).
2. Controlled-distortion monotonicity for Noise, Blocking, and exposure without catastrophic false positives on clean texture.
3. Explicit product decision on Sharpness vs Blur duplication (keep two badges vs merge to focus/detail).
4. Ringing proxy either replaced or labeled as non-diagnostic in member UI.
5. Regression tests for each criterion and API response shape.

## Smallest safe integration plan (if later approved)

1. Add a feature flag, e.g. `QUALITY_ENGINE=experimental_classical_v1`, default off.
2. Keep response schema identical: seven named criteria + `overall_score` mean.
3. Shadow-score in research/admin only before member-facing rollout.
4. Do **not** retrain EfficientNet on synthetic rectangles as a substitute for this path.

## Current recommendation

**Keep production unchanged.** Use `experimental_classical_v1` for continued research and for guiding which classical signals deserve ACCESS-rubric labeling next (especially Brightness/Contrast/Sharpness).
