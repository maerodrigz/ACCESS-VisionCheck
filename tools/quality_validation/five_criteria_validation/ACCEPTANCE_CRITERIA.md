# Pre-registered acceptance criteria — Five Classical criteria validation

**Lock these criteria before collecting validation ratings or running machine scores on the new set.**  
Changing gates after seeing results invalidates the study’s claim to a finite, defensible decision.

Detectors under comparison remain **frozen** (no threshold edits, no new Classical versions).

These gates are adapted from the Noise/Ringing study but **not copied blindly**: Brightness and Blocking historically had weak human consensus or compressed labels, so calibration, strata balance, and LIMITED CONSENSUS rules are explicit here.

---

## 0. Decision order (mandatory)

```
Calibration pass (incl. Brightness + Blocking emphasis)
    → Validation human ratings locked
        → Human IRR gates per criterion (§1)
            → if hard FAIL: STOP for that criterion (no machine headline)
            → if PASS or allowed LIMITED CONSENSUS: Machine comparison (§2)
                → Criterion-specific further-review eligibility (§3)
```

Decisions are **per criterion**. Do not require all five to pass together.

---

## 1. Human reliability gates (each criterion separately)

Computed on the locked validation sheet with three raters, **before** unblinding machines.

| Gate ID | Metric | Pass threshold | Fail action |
|---------|--------|----------------|-------------|
| H1 | Mean pairwise **within-1** agreement | ≥ **0.85** | STOP for that criterion; remediation |
| H2 | Mean pairwise **quadratic weighted kappa** | ≥ **0.40** | STOP for that criterion; remediation |
| H3 | Fleiss’ κ | ≥ **0.20** | Soft gate: if H1 and H2 pass but H3 fails, proceed only with an explicit **LIMITED CONSENSUS** flag |
| H4 | Disagreement rate (`max−min ≥ 3`) | ≤ **15%** of images | Adjudication log; if still >15%, STOP |
| H5 | Usable label coverage | ≥ **90%** non-`N/A` cells | Replace images / re-rate |
| H6 | Label dispersion (Brightness & Blocking only) | Human medians use **≥ 3 distinct** values on the validation set | STOP / rebalance pack (guards pilot-style all-4–5 Blocking and collapsed Brightness) |

**Rationale vs frozen pilot**

| Criterion | Pilot Fleiss κ | Pilot QWK | Design implication |
|-----------|---------------:|----------:|--------------------|
| Sharpness | 0.326 | 0.690 | Standard H1–H5 |
| Blur | 0.401 | 0.773 | Standard H1–H5 |
| Brightness | −0.038 | −0.029 | Extra calibration; H6 required; LIMITED CONSENSUS expected risk |
| Contrast | 0.162 | 0.578 | Standard H1–H5; watch H3 |
| Blocking | 0.086 | 0.163 | Extra calibration + forced severity strata; H6 required |

Within-1 alone is **not** sufficient (pilot Blocking within-1 was already ~0.91 with κ near chance).

---

## 2. Machine comparison gates (only if §1 passes for that criterion)

Evaluate each frozen candidate **separately** against the human median (or adjudicated sensitivity table).

| ID | Sharpness | Blur | Brightness | Contrast | Blocking |
|----|-----------|------|------------|----------|----------|
| **C-prod** | ENET-B0 + production soft-score | same | same | same | same |
| **C-classical** | Classical v2 | Classical v2 | Classical v2 | Classical v2 | Classical **v3** |

### 2.1 Validity gates per candidate × criterion

| Gate ID | Metric | Pass | Notes |
|---------|--------|------|-------|
| M1 | Spearman ρ vs human median | ≥ **0.30** and (95% CI excludes 0 **or** two-sided p < 0.05) | Constant badges → automatic **fail** |
| M2 | MAE | ≤ **1.00** | Proximity never overrides M1 fail |
| M3 | Within-1 rate | ≥ **0.75** | Not an accuracy percentage by itself |
| M4 | Badge dispersion | ≥ **3 distinct** machine badge values **or** clear non-collapsed variance | Guards production-style 2-bin piles |
| M5a | False-harsh rate | ≤ **10%** of images where human median ≥ 4 and machine ≤ 2 | Important for Blocking |
| M5b | False-lenient rate | ≤ **15%** of images where human median ≤ 2 and machine ≥ 4 | Important for production ceilings / Brightness |
| M6 | No fitting | Confirmed: no threshold change using this set | Process gate |

Eligible for **further review** on a criterion only if **M1–M6 all pass** for that candidate × criterion (M5a and M5b both required).

### 2.2 Why M1 is 0.30 (not copied as “success = SPAQ 0.75”)

The Noise/Ringing study used ρ ≥ 0.30 as a **minimum eligibility** floor for further review, not as a claim of strong perceptual gold-standard performance. That floor remains appropriate here: Classical already showed higher descriptive ρ on the frozen pilot, but this study must still beat chance with dispersion and significance on a **new** set. Raising M1 to 0.50+ after peeking would invalidate pre-registration. Optional **stretch reporting** (ρ ≥ 0.50) may be shown but is **not** the pass gate.

### 2.3 Explicit non-acceptance patterns

- High within-1 + negative Spearman → **not accepted**
- Low MAE with constant badges → **not accepted**
- Classical beats production on SPAQ proxies but fails this human set → **not accepted**
- Pass on Sharpness but fail on Blur (etc.) → accept **only** the passing criterion’s candidate
- LIMITED CONSENSUS human labels → any machine pass must carry the same flag in the decision report

---

## 3. Study-level outcomes

| Outcome | When | Next action |
|---------|------|-------------|
| **Keep unvalidated** (criterion) | §1 hard fail, or both candidates fail §2 | No production change for that criterion |
| **Criterion-specific further review** | ≥1 candidate passes §2 for that criterion | Document; product approval still required for any promotion |
| **Multi-criterion further review** | Several criteria each have a passing candidate | Still research/feature-flag path only |
| **Abandon candidate for criterion** | Severe M1/M4/M5 failure (e.g. constant floor/ceiling) | Do not retune on this set; archive |

**Hard stop:** Do not promote Classical v2 / Blocking v3 or change production from this package alone.

---

## 4. Sample size and uncertainty (pre-registered)

| Item | Requirement |
|------|-------------|
| Validation n | **36–48** images (target **40**); fixed before unblinding |
| Calibration n | 12–16 discussion + 6 independent practice (not in metrics) |
| Reserve | 8–10 replacements for corrupt files only |
| Raters | 3 independent |
| Bootstrap | Report Spearman 95% percentile CI (e.g. 1000 resamples, fixed seed) for each M1 test |
| Minimum usable pairs per criterion | ≥ **32** non-`N/A` median pairs after H5 |

Do not grow n after seeing machine correlations.

---

## 5. What “pass” does **not** mean

- Not scientific perfection or a perceptual gold standard.
- Not authorization to change production scoring, Flutter, or member skill rules.
- Not permission to fit new thresholds on the same images and re-declare success.
- Not a reopen of Noise/Ringing KEEP UNVALIDATED decisions.
