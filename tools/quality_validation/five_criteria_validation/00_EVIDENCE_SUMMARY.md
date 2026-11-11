# Five criteria — evidence summary (frozen; do not re-run)

**Purpose:** Document why an independent validation is needed, using existing locked reports only.  
**Do not** re-score SPAQ-200, KonIQ Run 002, the frozen 30-image pilot, or NR001–NR015.  
**Do not** retune Classical v2 / Blocking v3 / EfficientNet on those sets.

Primary sources:

- `../FIVE_CRITERIA_EVIDENCE_AUDIT.md`
- `../workspace/human_pilot/output/pilot_hvsm_20261108T114511Z/FINAL_HUMAN_VALIDATION_REPORT.md`
- `../workspace/experimental_quality/TECH_DECISION_RECORD_QUALITY_ENGINE_RESEARCH_20261108.md`
- `../workspace/experimental_quality/output/combined_v1_eval_20261108T143610Z/COMBINED_V1_EVAL_REPORT.md`
- `../workspace/experimental_quality/output/exp_eval_v2_20261108T123035Z/`
- `../workspace/datasets/spaq/SPAQ_200_EVALUATION_REPORT.md`

---

## 1. Human IRR on frozen pilot (n=30) — five criteria only

| Criterion | Within-1 | QWK | Fleiss κ | Reading |
|-----------|---------:|----:|---------:|---------|
| Sharpness | 0.956 | 0.690 | 0.326 | Usable ordinal agreement |
| Blur | 0.989 | 0.773 | 0.401 | Strongest of the five |
| Brightness | 0.761 | **−0.029** | **−0.038** | **Near-chance; calibration critical** |
| Contrast | 0.909 | 0.578 | 0.162 | Soft; needs clearer anchors |
| Blocking | 0.908 | 0.163 | 0.086 | Weak κ; humans mostly 4–5 |

Implication: Brightness and Blocking need extra calibration examples and forced severity balance before machine claims.

---

## 2. Machine vs human (pilot medians; diagnostic only)

| Criterion | Production ρ | Classical (v2 / Blocking v3) ρ |
|-----------|-------------:|-------------------------------:|
| Sharpness | 0.10 | **0.62** (v2) |
| Blur | 0.16 | **0.82** (v2) |
| Brightness | 0.06 | **0.40** (v2) |
| Contrast | 0.09 | **0.34** (v2) |
| Blocking | 0.00 | **0.21** (v3); v2 was −0.33 |

Production badges were compressed (often {3,4} or Brightness {4,5}; Contrast mostly 3). Pilot correlations are **not** final validation.

---

## 3. SPAQ-200 proxies (production vs classical v2)

| Pair | Production ρ | Classical v2 ρ |
|------|-------------:|---------------:|
| Sharpness | 0.086 | 0.749 |
| Brightness | 0.045 | 0.410 |
| Contrast | −0.028 | 0.325 |

Blur and Blocking have **no** SPAQ attributes. SPAQ ≠ ACCESS rubric.

---

## 4. Known weaknesses to design around

1. **Brightness:** Weak human consensus historically; under- vs over-exposure must be calibrated as the same “bad exposure” direction (high score = good subject exposure).
2. **Blocking:** Need deliberate clean→severe JPEG/blockiness strata; avoid another pilot where everyone rates 4–5.
3. **Sharpness vs Blur:** Related but not identical; rubric must prevent rating Blur as `6 − Sharpness` by habit.
4. **Contrast:** Distinguish usable tonal separation from harsh crushed blacks that still look “punchy.”
5. **Leakage:** Exclude pilot-30, NR001–NR015, and any image used to choose Classical thresholds.

---

## 5. Scientific stance for this study

1. Treat Classical v2 / Blocking v3 as **frozen research candidates**, not production.
2. Human reliability first; machines only after IRR gates.
3. Criterion-specific decisions; do not bundle a single “all five pass/fail.”
4. Pass = eligibility for further review only.
