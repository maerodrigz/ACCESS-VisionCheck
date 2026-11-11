# Five Classical Criteria — Independent Validation Preparation Pack

Finite **preparation only** for comparing frozen Classical detectors to production EfficientNet-B0 on:

1. Sharpness (Classical v2)  
2. Blur (Classical v2)  
3. Brightness / Exposure (Classical v2)  
4. Contrast (Classical v2)  
5. Blocking Artifacts (Classical v3)

**Does not** modify production, Flutter, EfficientNet weights, Classical formulas, or the completed Noise/Ringing study.  
**Does not** download images, run machines, or collect ratings yet.

---

## Why this pack exists

From `../FIVE_CRITERIA_EVIDENCE_AUDIT.md` and the research TDR:

- Production ENET failed rank agreement on the frozen pilot for all five criteria.
- Classical v2 (four heads) and Blocking v3 are **PROMISING BUT UNVALIDATED**.
- Pilot Brightness IRR was near chance; Blocking human scores were almost only 4–5.
- Pilot-30 and NR001–NR015 are **locked out** of this study (no reuse for train/tune/select/eval).

Next step: a **new disjoint** labeled set with a clearer five-criterion rubric and **pre-registered** gates.

---

## Deliverables

| File | Contents |
|------|----------|
| `00_EVIDENCE_SUMMARY.md` | Frozen evidence and known weaknesses |
| `INDEPENDENT_VALIDATION_PROTOCOL.md` | Leakage-safe study design |
| `FIVE_CRITERIA_RUBRIC.md` | 1–5 visual definitions + confusion matrix |
| `ACCEPTANCE_CRITERIA.md` | Pre-registered H/M gates and GO/NO-GO rules |
| `IMAGE_COLLECTION_PLAN.md` | Balanced strata; no download yet |
| `HUMAN_EVALUATION_INSTRUCTIONS.md` | Rater-facing instructions |
| `EXECUTION_CHECKLIST.md` | Launch runbook |
| `COLLECTION_CHECKLIST.md` | Facilitator collection gates |
| `EVALUATOR_WORKLOAD.md` | Time estimates |
| `templates/` | Manifest + rating + calibration CSVs |
| `eval_web/` | Offline rating UI adapted from Noise/Ringing eval_web (**separate copy**; NR study untouched) |

---

## Frozen machine candidates (read-only later)

| ID | Role |
|----|------|
| **C-prod** | Production EfficientNet-B0 + production `_soft_score` mapping |
| **C-classical** | Sharpness/Blur/Brightness/Contrast from `experimental_classical_v2`; Blocking from `experimental_blocking_v3` (same composition as combined_v1 for these five heads) |

No new detector versions. No threshold edits on this set.

---

## What evidence would justify further review

Only after calibration, locked human ratings, IRR pass (or documented LIMITED CONSENSUS where allowed), and **M1–M6 pass per criterion** for a frozen candidate: that candidate becomes **eligible for product further review**.  

Pass ≠ production deployment, Flutter change, skill-rule change, or permission to retune on the same images.

---

## Status

**Awaiting approval** before image download, calibration ratings, or machine comparison.
