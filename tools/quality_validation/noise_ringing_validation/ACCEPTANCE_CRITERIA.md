# Pre-registered acceptance criteria — Noise and Ringing independent validation

**Lock these criteria before collecting validation ratings or running machine scores on the new set.**  
Changing gates after seeing results invalidates the study’s claim to a finite, defensible decision.

Detectors under comparison remain **frozen** (no threshold edits). This package does not introduce new detector versions.

---

## 0. Decision order (mandatory)

```
Calibration pass
    → Validation human ratings locked
        → Human IRR gates (§1)
            → if FAIL: STOP (revise rubric / recalibrate; do not headline machine metrics)
            → if PASS: Machine comparison (§2–3)
                → Single go / no-go / keep-unvalidated decision (§4)
```

---

## 1. Human reliability gates (Noise and Ringing separately)

Computed on the locked validation sheet with three raters, before unblinding machines.

| Gate ID | Metric | Pass threshold | Fail action |
|---------|--------|----------------|-------------|
| H1 | Mean pairwise **within-1** agreement | ≥ **0.85** | STOP; remediation |
| H2 | Mean pairwise **quadratic weighted kappa** | ≥ **0.40** | STOP; remediation |
| H3 | Fleiss’ κ | ≥ **0.20** | Soft gate: if H1 and H2 pass but H3 fails, proceed only with an explicit “limited consensus” flag in the report |
| H4 | Disagreement rate (`max−min ≥ 3`) | ≤ **15%** of images per criterion | Review adjudication; if still >15% after adjudication logging, STOP |
| H5 | Usable label coverage | ≥ **90%** non-`N/A` cells per criterion | Replace images / re-rate |

**Rationale vs frozen pilot:** pilot Noise Fleiss κ ≈ 0.04 and Ringing ≈ 0.13 with QWK ≈ 0.31 / 0.19. The new study must beat that ordinal reliability enough to support machine comparison. Within-1 alone is **not** sufficient (pilot Noise within-1 was already ~0.91 while κ was near chance).

---

## 2. Machine comparison gates (only if §1 passes)

Evaluate each **frozen** candidate separately against the human median (or adjudicated sensitivity table).

Primary frozen candidates (read-only; no new versions):

| ID | Noise candidate | Ringing candidate |
|----|-----------------|-------------------|
| C-prod | Production EfficientNet-B0 head + production badge map | same |
| C-v2 | Classical combined / experimental Noise v2 path | Classical Ringing v2 path (if available as cached estimator) |
| C-combined | Noise v2 inside `experimental_classical_combined_v1` | Ringing v3 inside combined v1 (documented; not promoted) |

Optional diagnostics only (not promotion candidates unless §1 and §2 pass and product later asks): Noise v3/v4, Ringing v4 — still **not** to be retuned here.

### 2.1 Validity gates per candidate × criterion

| Gate ID | Metric | Pass | Notes |
|---------|--------|------|-------|
| M1 | Spearman ρ vs human median | ≥ **0.30** and 95% CI excludes 0 **or** two-sided p < 0.05 | If badges are constant, M1 is an automatic **fail** (undefined/meaningless ρ) |
| M2 | MAE | ≤ **1.00** | Absolute proximity alone never overrides M1 fail |
| M3 | Within-1 rate | ≥ **0.75** | |
| M4 | Badge dispersion | At least **3 distinct** badge values on the validation set **or** variance clearly not floor/ceiling collapsed | Guards against pilot-style constant floors/ceilings |
| M5 | False-harsh rate | ≤ **10%** of images where human median ≥ 4 and machine ≤ 2 | Especially relevant to Ringing v3-style floors |
| M6 | No fitting | Confirmed: no threshold change using this set | Process gate |

A candidate is **eligible for “further review”** only if **M1–M6 all pass** for that criterion.

### 2.2 Explicit non-acceptance patterns

- High within-1 + negative Spearman → **not accepted**
- Low MAE with constant badges → **not accepted**
- Agreement with another machine but fail vs human → **not accepted**
- Pass on Noise but fail on Ringing (or reverse) → accept **only** the passing criterion’s candidate; do not bundle

---

## 3. Study-level outcomes (single decision)

| Outcome | When | Next action |
|---------|------|-------------|
| **Keep unvalidated** | §1 fail, or all candidates fail §2 | No production change; optional new disjoint study later |
| **Criterion-specific further review** | Exactly one criterion’s candidate passes §2 | Document; still no production promotion without product approval |
| **Both criteria further review** | Noise and Ringing each have ≥1 passing candidate | Product review only; still feature-flagged research path |
| **Abandon candidate** | Candidate fails M1 or M5 badly (e.g. constant floor) | Do not retune on this set; archive |

**Hard stop:** Never promote Noise v4 or Ringing v3/v4 from prior pilot regressions without passing **this** independent protocol.

---

## 4. What “pass” does **not** mean

- Not a claim of scientific perfection or perceptual gold standard.
- Not authorization to change production scoring, Flutter, or member skill rules.
- Not permission to fit new thresholds on the same images and re-declare success.
