# ACCESS VisionCheck Human Validation Pilot: Results and Discussion

**Manuscript-ready report**  
**Analysis package:** `pilot_hvsm_20261108T114511Z`  
**Generated analysis timestamp (UTC):** 2026-11-08T11:45:11Z  
**Source statistics:** verified outputs in this directory (`analysis_report.json`, CSV tables, and `HUMAN_VS_MACHINE_PILOT_REPORT.md`)

---

## 1. Purpose of this report

This document presents the Results and Discussion for the ACCESS VisionCheck photo-quality human validation pilot. The pilot was designed to (a) collect criterion-specific human ratings under a blinded protocol, (b) quantify inter-rater reliability among three independent evaluators, and (c) compare human consensus with previously generated machine criterion scores from KonIQ Run 002.

Two outcomes must be distinguished throughout:

1. **Successful completion of the human validation study** (protocol executed, ratings locked, analysis completed under documented safety constraints).
2. **Successful validation of machine criterion accuracy** (empirical demonstration that machine badges track human criterion judgments). The results below support (1) but **do not** support (2).

No statistics in this report were invented or altered. Machine scores were not recomputed. Original human CSV files were not modified. KonIQ mean opinion score (MOS) was not used as ground truth for any of the seven technical criteria.

---

## 2. Methods (pilot design)

### 2.1 Materials and stratification

Thirty photographs were drawn from the KonIQ-10k Run 002 research subset using a documented stratified selection (seed `20261107`, selection salt `pilot30`):

| Stratum | Count | Role in the pilot |
|---------|------:|-------------------|
| Q1 (very low published MOS band) | 10 | Low-quality stress cases |
| Q3 (mid band) | 10 | Typical mid-range cases |
| Q5 (very high band) | 10 | High-quality cases |

Images were presented under anonymous identifiers `PILOT-001` through `PILOT-030`. The facilitator mapping from anonymous IDs to Run 002 `media_id` values is recorded in `facilitator_manifest.csv` and was withheld from raters.

### 2.2 Evaluators and blinding

Three independent evaluators (`R1`, `R2`, `R3`) rated every pilot image. Raters did not receive machine scores, stratum labels, published KonIQ MOS values, or Run 002 diagnostic reports. Ratings were collected independently and locked prior to unblinding.

### 2.3 Rating constructs and scale

Raters used the ACCESS 1–5 ordinal rubric (higher is always better), including for Blur and Noise:

| Construct | Description |
|-----------|-------------|
| Sharpness | Fine subject detail / micro-contrast |
| Blur | Freedom from motion smear or defocus |
| Noise | Freedom from grain / chroma noise |
| Brightness | Subject exposure suitability |
| Contrast | Usable tonal separation |
| Blocking artifacts | Freedom from compression blockiness |
| Ringing artifacts | Freedom from edge halos / ghosting |
| Overall visual quality | Independent gestalt of documentation usefulness (not forced to equal the mean of the seven) |

Photo-only fields `flickering` and `motion_stability` were recorded as not applicable.

Scale anchors: **1** = unusable for club documentation on that criterion; **2** = obvious defect, retake normally required; **3** = subject identifiable with clearly visible defect; **4** = minor issues, suitable for ACCESS documentation; **5** = no meaningful defect at fit-to-window and 100% crop inspection.

### 2.4 Machine reference scores

Machine criterion integers and system `overall_score` were taken from existing KonIQ Run 002 EfficientNet-B0 outputs (`machine_results.json` / `per_image_results.csv`). Inference was **not** rerun. System `overall_score` is defined as the arithmetic mean of the seven technical badge integers and is therefore a different construct from human `overall_visual_quality`.

### 2.5 Analysis procedures

- Data quality checks: completeness of `PILOT-001`–`PILOT-030` per rater, duplicate IDs, and invalid scores.
- Human consensus: per-image median of available R1/R2/R3 ratings (missing cells excluded for that rater only).
- Inter-rater reliability: mean pairwise exact agreement, mean pairwise within-one-point agreement, mean pairwise quadratic weighted kappa (QWK), and Fleiss’ κ, with missing values handled explicitly.
- Human–machine comparison: MAE, RMSE, bias (machine − human median), Spearman rank correlation, and within-one-point rate for each criterion.
- Overall construct comparison conducted separately from the seven criteria.
- Published KonIQ MOS was retained only as a non-criterion metadata field and was not used as criterion ground truth.

---

## 3. Results

### 3.1 Data completeness

| Metric | Value |
|--------|------:|
| Expected rating rows | 90 (30 images × 3 raters) |
| Rows loaded | 90 |
| Validation errors (duplicates, invalid IDs, invalid scores) | 0 |
| Explicit missing score cells (warnings) | 4 |
| Analysis eligibility | Passed |

**Table 1. Explicit missing human cells**

| Rater | Image | Criterion left blank |
|-------|-------|----------------------|
| R1 | PILOT-020 | Blocking artifacts |
| R2 | PILOT-012 | Contrast |
| R3 | PILOT-012 | Brightness |
| R3 | PILOT-013 | Ringing artifacts |

All other technical and overall cells for the 30 images were filled with valid integers on the 1–5 scale. Missing cells were excluded from pairwise reliability calculations involving that rater–item pair and from that rater’s contribution to the corresponding median.

### 3.2 Inter-rater reliability

**Table 2. Inter-rater agreement among R1, R2, and R3 (n = 30 images)**

| Criterion | Missing cells | Mean exact agreement | Mean within-1 agreement | Mean QWK | Fleiss’ κ |
|-----------|--------------:|---------------------:|------------------------:|---------:|----------:|
| Sharpness | 0 | 0.511 | 0.956 | 0.690 | 0.326 |
| Blur | 0 | 0.567 | 0.989 | 0.773 | 0.401 |
| Noise | 0 | 0.378 | 0.911 | 0.305 | 0.039 |
| Brightness | 1 | 0.261 | 0.761 | −0.029 | −0.038 |
| Contrast | 1 | 0.398 | 0.909 | 0.578 | 0.162 |
| Blocking artifacts | 1 | 0.477 | 0.908 | 0.163 | 0.086 |
| Ringing artifacts | 1 | 0.433 | 0.830 | 0.185 | 0.128 |
| Overall visual quality | 0 | 0.456 | 0.989 | 0.603 | 0.199 |

Interpretation of Table 2 is moderated by sample size. Exact agreement was modest for most criteria. Within-one-point agreement was high for Sharpness, Blur, Contrast, Blocking, Noise, and overall visual quality (≥ 0.90), indicating that many disagreements were adjacent ordinal steps rather than severe contradictions. Ordinal reliability was comparatively stronger for Sharpness and Blur (mean QWK 0.690 and 0.773; Fleiss’ κ 0.326 and 0.401) and weak to near-chance for Noise, Brightness, Blocking, and Ringing.

### 3.3 Human consensus versus machine criterion scores

Human reference values were per-image medians of available evaluator ratings. Machine values were Run 002 criterion integers. Bias is machine minus human.

**Table 3. Human median vs machine criterion scores (n = 30 paired images)**

| Criterion | n | MAE | RMSE | Bias (machine − human) | Spearman ρ | Spearman p | Within-1 rate |
|-----------|--:|----:|-----:|-----------------------:|-----------:|-----------:|--------------:|
| Sharpness | 30 | 0.933 | 1.125 | −0.400 | 0.104 | 0.584 | 0.833 |
| Blur | 30 | 0.933 | 1.183 | −0.733 | 0.160 | 0.397 | 0.767 |
| Noise | 30 | 0.733 | 1.033 | −0.467 | −0.275 | 0.142 | 0.833 |
| Brightness | 30 | 0.800 | 1.065 | +0.667 | 0.064 | 0.739 | 0.833 |
| Contrast | 30 | 1.017 | 1.242 | −0.783 | 0.092 | 0.628 | 0.800 |
| Blocking artifacts | 30 | 0.950 | 1.158 | −0.883 | 0.001 | 0.996 | 0.800 |
| Ringing artifacts | 30 | 0.883 | 1.158 | −0.750 | 0.013 | 0.947 | 0.767 |

Absolute error magnitudes are typically under one ordinal point on average (MAE range 0.733–1.017). However, rank agreement is weak across all seven criteria: Spearman correlations are near zero, and Noise is negatively associated with the human median (ρ = −0.275). No criterion exhibits a statistically significant positive Spearman association at conventional α = 0.05 in this pilot.

### 3.4 Overall visual quality (separate construct)

**Table 4. Human overall visual quality vs machine overall score**

| Comparison | n | MAE | RMSE | Bias (machine − human) | Spearman ρ | Spearman p | Within-1 rate |
|------------|--:|----:|-----:|-----------------------:|-----------:|-----------:|--------------:|
| Human overall median vs machine `overall_score` | 30 | 0.738 | 0.853 | −0.252 | 0.035 | 0.854 | 0.767 |

These quantities measure different constructs. Human overall visual quality is an independent gestalt judgment. Machine `overall_score` is the mean of seven technical badges. Agreement on absolute proximity (within one point on 76.7% of images) therefore cannot be interpreted as evidence that the system captures the same overall construct that humans rated.

### 3.5 Observed score ranges (context for correlation)

On this 30-image set, machine criterion badges were tightly concentrated:

| Criterion | Machine observed integers | Human median observed range |
|-----------|---------------------------|-----------------------------|
| Sharpness | {3, 4} only | 2.0–5.0 |
| Blur | {3, 4} only | 2.0–5.0 |
| Noise | {3, 4} only | 3.0–5.0 |
| Brightness | {4, 5} only | 3.0–5.0 |
| Contrast | mostly 3 (27/30) | 2.0–5.0 |
| Blocking artifacts | {3, 4, 5} | 4.0–5.0 |
| Ringing artifacts | {3, 4} only | 3.0–5.0 |
| Machine overall score | 3.29–3.86 | Human overall medians spanned a wider ordinal range |

Restricted machine variance is an important empirical finding of this pilot and directly limits attainable Spearman correlation even when absolute differences remain moderate.

---

## 4. Discussion

### 4.1 Completion of the human validation study

The pilot successfully implemented the planned ACCESS workflow: stratified selection, blinding, three-rater independent scoring, locked sheets, facilitator join to existing Run 002 machine outputs, and transparent reporting of missing cells and construct boundaries. In that procedural sense, the human validation study is complete and research-ready.

### 4.2 Why correlations are weak

Several verified factors jointly explain the weak human–machine rank correlations:

1. **Restricted machine score range.** For Sharpness, Blur, Noise, and Ringing, machine outputs occupied only two ordinal levels on the pilot set. Contrast was almost constant (3 on 27 of 30 images). Rank statistics require meaningful dispersion; compressed machine outputs cannot track human ordering reliably.
2. **Broader human discrimination.** Human medians spanned more of the 1–5 scale for several criteria, indicating that evaluators differentiated image quality more finely than the machine badges did on this sample.
3. **Construct and head-specific difficulty.** Noise showed a negative Spearman association, and Blocking/Ringing correlations were effectively null. These patterns are consistent with earlier research observations that compression and noise-related badges remain difficult for the current production mapping on real photographs.
4. **Evaluator disagreement on some criteria.** Brightness IRR was particularly weak (mean exact agreement 0.261; Fleiss’ κ −0.038). When humans themselves disagree, the median remains a useful aggregate but is a noisier target for machine comparison.

### 4.3 Interpreting within-one-point rates cautiously

Within-one-point rates of approximately 0.77–0.83 for criterion comparisons and 0.767 for overall should **not** be reported as model accuracy percentages. On a five-point scale with compressed machine outputs near the center of the scale, chance proximity can appear favorable. MAE/RMSE and near-zero Spearman values provide the more informative picture for rank-sensitive validation.

### 4.4 Evaluator disagreements

Sharpness and Blur showed the strongest ordinal concordance, supporting the practical separability of those rubric definitions after training. Brightness, Noise, and compression-related criteria showed weaker consensus. This suggests that future work should emphasize calibration examples and decision rules for exposure, grain versus compression, and edge artifacts before expanding the labeled set.

### 4.5 Implications for ACCESS VisionCheck

For the ACCESS club documentation use case, the pilot provides:

- A locked human reference for 30 stratified photographs across seven criteria plus overall.
- Evidence that the current machine badges are often numerically close to human medians in absolute terms, yet **do not** reproduce human rank ordering on this set.
- A clear warning against treating Run 002 criterion integers as validated perceptual labels for recalibration or manuscript claims of criterion accuracy.

Accordingly, the pilot does **not** authorize changes to production scoring formulas, thresholds, weights, or database records.

### 4.6 Limitations

1. Sample size is small (30 images; three raters), so estimates are unstable and confidence intervals were not claimed.
2. Four human cells were blank; medians used available ratings only.
3. Machine badges exhibited restricted range on this pilot, confounding correlation interpretation.
4. Human overall and machine overall are different constructs.
5. Published KonIQ MOS is overall-only and was not used as criterion ground truth; stratum labels based on MOS bands describe sampling design, not criterion labels.
6. Results are specific to this ACCESS rubric and KonIQ Run 002 machine snapshot; they are not a general image-quality-assessment leaderboard claim.
7. No adjudication pass was applied for large pairwise disagreements beyond reporting reliability statistics.

---

## 5. Conclusion

The ACCESS VisionCheck human validation pilot was successfully executed: three independent evaluators completed blinded 1–5 ratings of 30 stratified photographs on seven photo-quality criteria and overall visual quality; data quality checks passed with only four missing cells; and human consensus was compared with existing Run 002 machine scores without re-inference or alteration of source files.

However, **machine criterion accuracy was not validated**. Spearman correlations with human medians were weak or negative, machine score ranges were severely restricted on several criteria, and inter-rater reliability was uneven (stronger for Sharpness/Blur; weak for Brightness and several artifact criteria). Absolute proximity metrics and within-one-point rates must not be over-interpreted as evidence of successful automatic quality assessment.

In short: the human study is complete; the system’s criterion-level perceptual validity on this pilot remains unproven.

---

## 6. Recommendations for future work

1. Expand the labeled set beyond 30 images after targeted rater recalibration, especially for Brightness, Noise, Blocking, and Ringing.
2. Investigate why production badges collapse to narrow ordinal bands on stratified real photographs before any threshold or weight changes.
3. Keep human overall visual quality and machine overall score as separate constructs in all manuscript reporting.
4. Continue to prohibit KonIQ MOS as criterion ground truth.
5. Report MAE/RMSE, bias, and Spearman together; avoid accuracy-style claims based solely on within-one-point rates.
6. Do not modify production scoring until a larger, better-dispersed evaluation demonstrates stable positive rank agreement on ACCESS criteria.

---

## 7. Provenance of verified statistics

All numerical results above are taken from the analysis package:

`tools/quality_validation/workspace/human_pilot/output/pilot_hvsm_20261108T114511Z`

Primary sources within that directory:

- `analysis_report.json`
- `HUMAN_VS_MACHINE_PILOT_REPORT.md`
- `data_quality_issues.csv`
- `inter_rater_agreement.csv`
- `criterion_comparison_summary.csv`
- `overall_construct_comparison.csv`
- `human_consensus_by_image.csv`
- `machine_scores_joined.csv`
- `per_image_human_vs_machine.csv`

Analysis script (for reproducibility; not re-executed for this manuscript polish):  
`tools/quality_validation/analyze_human_pilot_validation.py`
