# Noise and Ringing — evidence summary (frozen; do not re-run)

**Purpose:** Document why a new independent validation is required, using existing pilot evidence only.  
**Do not** re-score SPAQ-200 or the frozen 30-image ACCESS pilot.  
**Do not** retune detectors against that pilot.

Primary sources:

- `workspace/human_pilot/output/pilot_hvsm_20261108T114511Z/FINAL_HUMAN_VALIDATION_REPORT.md`
- `workspace/experimental_quality/TECH_DECISION_RECORD_QUALITY_ENGINE_RESEARCH_20261108.md`
- `workspace/experimental_quality/output/noise_ringing_v4_pilot_diag_20261108T152257Z/NOISE_RINGING_V4_PILOT_DIAG_REPORT.md`

---

## 1. Human inter-rater agreement (frozen pilot, n=30, three raters)

| Criterion | Mean exact agreement | Mean within-1 | Mean QWK | Fleiss’ κ | Reading |
|-----------|---------------------|---------------|----------|-----------|---------|
| Noise | 0.378 | 0.911 | 0.305 | 0.039 | Within-1 looks fine; ordinal reliability near chance |
| Ringing | 0.433 | 0.830 | 0.185 | 0.128 | Weak ordinal consensus |

Implication: detector “failure” and construct ambiguity are entangled. A new study must improve **rater calibration and rubric specificity** before treating machine Spearman as decisive.

Human score ranges on the pilot were also compressed (Noise and Ringing mostly mid/high), which limits rank statistics even for humans.

---

## 2. Machine vs human (frozen pilot medians; diagnostic only)

| Estimator | Spearman ρ (approx.) | MAE (approx.) | Pattern |
|-----------|----------------------|---------------|---------|
| Production Noise | −0.27 | ~1.0 | Near-ceiling badges; negative rank |
| Classical Noise v2 | −0.25 | 0.83 | Over-clean; not validated |
| Classical Noise v3 | −0.17 | 0.90 | MIXED; not promoted |
| Classical Noise v4 | −0.47 | 0.97 | **REGRESSED** vs v2/v3 |
| Production Ringing | ~0.01 | ~1.16 | Null rank |
| Classical Ringing v2 | −0.40 | 0.85 | Lower MAE ≠ validated |
| Classical Ringing v3 | −0.42 | 2.45 | Harsh floor; not recommended |
| Classical Ringing v4 | undefined / floor | 3.10 | **REGRESSED** (constant badge 1 on scored set) |

---

## 3. Scientific stance for the next study

1. Treat Noise and Ringing as **open measurement problems**, not ready for production promotion.
2. Do **not** fit thresholds on the frozen pilot or on the upcoming independent set.
3. Gate interpretation: **human reliability first**, then blind machine comparison on a disjoint set.
4. Keep detector versions frozen for the comparison pass; no new detector versions in this package.
