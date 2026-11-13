# Chapter 4 Result Templates (Phase 4A)

**Fill only after real human submissions.** Replace `TBD` with numbers from `workspace/phase4a_indval/analysis/phase4a_analysis.json`. Do not invent values.

## 4.x Independent validation setup

| Item | Value |
|------|-------|
| Freeze id | phase4a_freeze_20261113 |
| Holdout n | 100 (KonIQ Run002 remainder + Run001; pilot/SPAQ excluded) |
| Raters | 3 (R1–R3) |
| Image-quality protocol | ACCESS 1–5 rubric |
| Feedback protocol | Issue Y/N + feedback-quality Likert |
| Production systems changed | None |

## 4.x.1 Inter-rater agreement (image quality)

| Criterion | QWK R1–R2 | QWK R1–R3 | QWK R2–R3 | Fleiss κ |
|-----------|----------:|----------:|----------:|---------:|
| Sharpness | TBD | TBD | TBD | TBD |
| Blur | TBD | TBD | TBD | TBD |
| Brightness | TBD | TBD | TBD | TBD |
| Contrast | TBD | TBD | TBD | TBD |
| Blocking | TBD | TBD | TBD | TBD |
| Color balance | TBD | TBD | TBD | TBD |
| Color saturation | TBD | TBD | TBD | TBD |
| Overall | TBD | TBD | TBD | TBD |

## 4.x.2 Image-quality: machine vs human median

| Criterion | Hybrid Spearman | Hybrid Pearson | Hybrid MAE | ENET Spearman | ENET Pearson | ENET MAE |
|-----------|----------------:|---------------:|-----------:|--------------:|-------------:|---------:|
| Sharpness | TBD | TBD | TBD | TBD | TBD | TBD |
| Blur | TBD | TBD | TBD | TBD | TBD | TBD |
| Brightness | TBD | TBD | TBD | TBD | TBD | TBD |
| Contrast | TBD | TBD | TBD | TBD | TBD | TBD |
| Blocking | TBD | TBD | TBD | TBD | TBD | TBD |

### Overall perceptual quality

| Pair | Spearman | Pearson | MAE |
|------|---------:|--------:|----:|
| ENET overall vs human overall | TBD | TBD | TBD |
| MUSIQ raw vs human overall | TBD | TBD | n/a (scale) |

State MUSIQ availability: `ok n=TBD / unavailable n=TBD`.

## 4.x.3 Feedback-generation validation (separate section)

| Setting | Precision | Recall | F1 | TP | FP | FN |
|---------|----------:|-------:|---:|---:|---:|---:|
| Issues include mild | TBD | TBD | TBD | TBD | TBD | TBD |
| Issues exclude mild | TBD | TBD | TBD | TBD | TBD | TBD |

### Feedback-quality Likert (1–5; not image MOS)

| Dimension | n | Mean |
|-----------|--:|-----:|
| Observation correctness | TBD | TBD |
| Recommendation relevance | TBD | TBD |
| Clarity | TBD | TBD |
| Usefulness | TBD | TBD |

## 4.x.4 Limitations paragraph (keep)

This holdout is KonIQ-domain and disjoint from the 30-image pilot and SPAQ-200 exploratory set, but it is not ACCESS-native documentation photography. Hybrid feedback rules remain research heuristics until these tables are populated from real raters. Production EfficientNet-B0 was not replaced.

## 4.x.5 Claims checklist

- [ ] No fabricated human scores
- [ ] Image-quality and feedback sections separated
- [ ] MAE omitted for incompatible scales
- [ ] Shadow scoring still disabled in production
- [ ] No production accuracy claim without completed sheets
