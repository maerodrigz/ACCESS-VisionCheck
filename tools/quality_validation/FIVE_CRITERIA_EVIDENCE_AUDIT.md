# Final Evidence Audit — Five Image Quality Criteria

**Date:** 2026-11-09  
**Scope:** Sharpness, Blur, Brightness/Exposure, Contrast, Blocking Artifacts  
**Method:** Read-only inspection of existing implementations and locked reports under `tools/quality_validation/`. No re-runs, no training, no production changes.  
**Out of scope for reclassification:** Noise and Ringing remain **KEEP UNVALIDATED / NO-GO** per the frozen NR001–NR015 decision; those outcomes are not reopened here.

---

## 1. Executive summary

None of the five criteria is **VALIDATED** under ACCESS’s own evidence standard (independent human criterion labels plus pre-registered acceptance).  

**Production EfficientNet-B0** shows compressed badges and near-zero Spearman vs human medians on the frozen 30-image pilot for all five criteria, and near-zero / nonsignificant SPAQ-attribute correlations for Sharpness, Brightness, and Contrast. Treat production rank accuracy for these five as **FAILED VALIDATION** (pilot accuracy claim not supported), not as proven perceptual quality.

**Experimental classical** engines (`experimental_classical_v2` for Sharpness/Blur/Brightness/Contrast; `experimental_blocking_v3` for Blocking) show **encouraging** SPAQ-proxy and/or pilot descriptive gains and synthetic ladder passes, but **no independent holdout** with pre-registered M-gates. Status: **PROMISING BUT UNVALIDATED**.

Current member-facing presentation (1–5 badges and mean-of-seven overall) **overstates** demonstrated accuracy. Overall must not drive skill/competency claims. Existing frozen reports already support a **further independent validation** of the classical promising heads **without inventing new detectors**; that would require a new labeled set (not NR15, not pilot-30) and is a product decision, not authorization to change production.

---

## 2. Production vs experimental comparison table

| Criterion | Production engine | Experimental engine | Prod SPAQ ρ (proxy) | Exp SPAQ ρ | Prod pilot ρ vs human median | Exp pilot ρ | Prod status | Exp status |
|-----------|-------------------|---------------------|--------------------:|-----------:|-----------------------------:|------------:|-------------|------------|
| Sharpness | ENET-B0 `sharpness` → `_soft_score` | classical v2 | 0.086 | **0.749** | 0.104 | **0.623** | FAILED VALIDATION | PROMISING BUT UNVALIDATED |
| Blur | ENET-B0 `blur` → `_soft_score(1−blur)` | classical v2 `log1p(LapVar)` | *no SPAQ attr* | *n/a* | 0.160 | **0.824** | FAILED VALIDATION | PROMISING BUT UNVALIDATED |
| Brightness | ENET then **triangle remap** `_brightness_metric` | classical v2 exposure-style | 0.045 | **0.410** | 0.064 | **0.403** | FAILED VALIDATION | PROMISING BUT UNVALIDATED† |
| Contrast | ENET-B0 `contrast` → `_soft_score` | classical v2 RMS−clip | −0.028 | **0.325** | 0.092 | **0.344** | FAILED VALIDATION | PROMISING BUT UNVALIDATED |
| Blocking | ENET-B0 `blocking_artifacts` → `_soft_score(1−…)` | Blocking **v3** (combined_v1); v2 was worse | *no SPAQ attr* | *n/a* | 0.001 | **0.212** (v3) / −0.331 (v2) | FAILED VALIDATION | PROMISING BUT UNVALIDATED‡ |

Sources: SPAQ-200 production report; `exp_eval_v2_20261108T123035Z`; `combined_v1_eval_20261108T143610Z`; `pilot_hvsm_20261108T114511Z`; TDR 2026-11-08.  
† Human IRR for Brightness on the pilot was very weak (Fleiss κ ≈ −0.038).  
‡ Blocking humans on the pilot were almost only 4–5; discrimination limited. Blocking v3 passed **synthetic** lightweight JPEG/texture gates only.

---

## 3. Implementations (production vs experimental)

### Shared production pipeline

| Piece | Location |
|-------|----------|
| Model | `access_backend/app/services/efficientnet_b0_scorer.py` + `ml/efficientnet_b0_heads.pt` |
| Mapping | `media_evaluator._photo_criteria` + `_soft_score` |
| Fallback | `opencv_quality.py` (Laplacian sharpness/blur, residual noise, flat-block “blocking”, edge oscillation “ringing”) |

OpenCV is a **fallback**, not the production primary path when EfficientNet loads. Experimental classical engines live only under `tools/quality_validation/` and are **not** production.

### Per-criterion notes

| Criterion | Production behavior | Experimental classical | Tests / reports |
|-----------|---------------------|------------------------|-----------------|
| Sharpness | ENET head index 0; high = sharper | v2 classical sharpness quality | SPAQ + pilot + combined reports; unit tests in `test_experimental_criteria_v2.py` |
| Blur | ENET head; invert before soft-score; train labels historically collinear with sharpness (`1 − blur_amount`) | v2 `log1p(Laplacian variance)` after resize; not forced `1 − sharpness` | Synthetic Gaussian ladder + pilot; **no** SPAQ Blur attribute |
| Brightness | Soft-score applied to **triangular** exposure curve around ~0.48, not raw head alone | v2 production-style brightness quality + under/over CTRL sequences | SPAQ Brightness proxy; pilot IRR weak |
| Contrast | ENET head; SPAQ-200 badges mostly 3 (174/200) | v2 RMS contrast with clip penalty; broader badge spread on SPAQ | SPAQ Contrast proxy; pilot secondary |
| Blocking | ENET head; OpenCV fallback = flat 8×8 variance (wrong construct for JPEG seams) | v2 native 8×8 seams; **v3** reduces false texture blocking (lightweight PASS) | Blocking v3 lightweight report; pilot secondary; **no** SPAQ Blocking attribute |

---

## 4. Evidence for each criterion

### 4.1 Sharpness

**Human IRR (pilot, n=30):** exact 0.511; within-1 0.956; QWK 0.690; Fleiss κ 0.326.  

**Production vs human median (pilot):** MAE 0.933; Spearman **0.104** (p=0.584); within-1 0.833; machine badges only {3,4}.  

**Production vs SPAQ Sharpness (n=200):** Spearman **0.086** (CI includes 0).  

**Classical v2:** SPAQ ρ **0.749**; pilot ρ **0.623**; SPAQ badge support used all 1–5.  

**Status:** Production **FAILED VALIDATION**. Experimental **PROMISING BUT UNVALIDATED**.

### 4.2 Blur

**Human IRR (pilot):** exact 0.567; within-1 0.989; QWK 0.773; Fleiss κ 0.401 (strongest of the five).  

**Production vs human median:** MAE 0.933; Spearman **0.160** (p=0.397); machine {3,4} only.  

**SPAQ:** no Blur attribute (cannot invent a correlation).  

**Classical v2:** pilot ρ **0.824**; synthetic Gaussian ladder monotone; CTRL badges `[2,1,1,1,1]`.  

**Status:** Production **FAILED VALIDATION**. Experimental **PROMISING BUT UNVALIDATED**.

### 4.3 Brightness / Exposure

**Human IRR (pilot):** exact 0.261; within-1 0.761; QWK **−0.029**; Fleiss κ **−0.038** (humans disagree).  

**Production vs human median:** MAE 0.800; Spearman **0.064**; bias +0.667; machine {4,5} only.  

**Production vs SPAQ Brightness:** Spearman **0.045** (CI includes 0); SPAQ badges ceiling-heavy (146/200 at 5).  

**Classical v2:** SPAQ ρ **0.410**; pilot ρ **0.403**; under/over CTRL sequences present.  

**Status:** Production **FAILED VALIDATION**. Experimental **PROMISING BUT UNVALIDATED**, with a **human-label reliability caveat** (fixibrate rubric before treating pilot ρ as strong).

### 4.4 Contrast

**Human IRR (pilot):** exact 0.398; within-1 0.909; QWK 0.578; Fleiss κ 0.162.  

**Production vs human median:** MAE 1.017; Spearman **0.092**; machine mostly 3 (27/30).  

**Production vs SPAQ Contrast:** Spearman **−0.028** (CI includes 0); 174/200 badges at 3. Raw ENET contrast vs SPAQ was weakly negative (−0.147) in the SPAQ-200 report.  

**Classical v2:** SPAQ ρ **0.325**; pilot ρ **0.344**; broader badge histogram on SPAQ.  

**Status:** Production **FAILED VALIDATION**. Experimental **PROMISING BUT UNVALIDATED**.

### 4.5 Blocking Artifacts

**Human IRR (pilot):** exact 0.477; within-1 0.908; QWK 0.163; Fleiss κ 0.086 (weak ordinal consensus).  

**Production vs human median:** MAE 0.950; Spearman **0.001**; humans mostly 4–5.  

**SPAQ:** no Blocking attribute.  

**Classical v2:** pilot ρ **−0.331** (wrong sign / inconclusive).  

**Blocking v3:** lightweight JPEG/texture gates **5/5 PASS**; combined pilot ρ **0.212**; less false-blocking on clean texture than v2.  

**Status:** Production **FAILED VALIDATION**. Blocking v2 **FAILED** as an ACCESS-pilot rank candidate. Blocking v3 **PROMISING BUT UNVALIDATED** (synthetic PASS + weak pilot sign recovery only).

---

## 5. Existing validation limitations (apply to all five)

1. **No NR-style independent protocol** was completed for these five (unlike Noise/Ringing NR001–NR015). Pilot n=30 is frozen **secondary** evidence; TDR forbids fitting on it.
2. **SPAQ attributes ≠ ACCESS rubric**; Blur and Blocking have **no** SPAQ labels.
3. **Production badge compression** kills rank statistics (often 2–3 integers; Brightness ceiling; Contrast pile-up at 3).
4. **Within-1 rates ~0.77–0.83** are not accuracy; pilot report forbids quoting them as such.
5. **Unit tests / synthetic ladders** prove engineering gates, not perceptual validation.
6. **Mean-of-seven overall** is a different construct from human overall; SPAQ MOS vs production overall ρ ≈ −0.07.
7. Brightness and Blocking suffer **weak human IRR** on the pilot, so even “promising” machine ρ must be interpreted cautiously.

---

## 6. Criterion-specific evidence status (final)

| Criterion | Production EfficientNet-B0 | Experimental classical |
|-----------|----------------------------|-------------------------|
| Sharpness | **FAILED VALIDATION** | **PROMISING BUT UNVALIDATED** (v2) |
| Blur | **FAILED VALIDATION** | **PROMISING BUT UNVALIDATED** (v2) |
| Brightness / Exposure | **FAILED VALIDATION** | **PROMISING BUT UNVALIDATED** (v2; IRR caveat) |
| Contrast | **FAILED VALIDATION** | **PROMISING BUT UNVALIDATED** (v2) |
| Blocking Artifacts | **FAILED VALIDATION** | **PROMISING BUT UNVALIDATED** (v3); v2 not recommended |

No criterion reaches **VALIDATED**. None of the five is **INSUFFICIENT EVIDENCE** for production: enough negative pilot/SPAQ evidence exists to reject an accuracy claim. Experimental Blur/Blocking lack SPAQ proxies but have pilot and/or synthetic evidence → still classified PROMISING (Blur) or PROMISING (Blocking v3), not INSUFFICIENT.

---

## 7. Recommended final presentation (no UI/scoring changes in this audit)

| Topic | Recommendation |
|-------|----------------|
| What can remain displayed | Current production badges may remain in the product UI as **system outputs**, but evidence does **not** support presenting them as independently validated perceptual truth |
| Experimental / unvalidated label | If messaging is reviewed later: treat all five production criteria as **unvalidated**; classical v2/v3 as **research-only / promising** |
| Overall quality & skill | **Do not** let mean-of-seven overall influence member skill / competency claims (TDR + combined report). Prefer per-criterion research language |
| Does presentation overstate accuracy? | **Yes.** Integer badges and overall imply calibrated quality; existing correlations do not support that for these five under production ENET |
| Further validation without new detector experiments? | **Yes, in principle:** freeze classical v2 (Sharpness/Blur/Brightness/Contrast) + Blocking v3; collect a **new** disjoint ACCESS-rubric labeled set; pre-register gates; score once. Do **not** use NR15 or pilot-30 for fitting. This audit does **not** start that study |

Noise/Ringing presentation/status: leave as already decided (**KEEP UNVALIDATED**).

---

## 8. Clear GO / NO-GO conclusions

| Decision | Verdict |
|----------|---------|
| Claim any of the five production criteria **VALIDATED** | **NO-GO** |
| Promote classical v2 / Blocking v3 to production from existing evidence alone | **NO-GO** |
| Use mean-of-seven overall for skill / competency | **NO-GO** |
| Treat production ENET as having failed the pilot accuracy claim for these five | **GO** (evidence supports that reading) |
| Keep classical Sharpness/Blur/Brightness/Contrast (v2) and Blocking v3 as **research candidates** for a future independent labeled study | **GO** (documentation / planning only; no new detector cycle in this audit) |
| Start new detector experiments or re-run SPAQ/KonIQ/pilot | **NO-GO** |

### Bottom line

Production EfficientNet-B0 does **not** have demonstrated rank accuracy for Sharpness, Blur, Brightness, Contrast, or Blocking. Classical experimental heads are **promising but unvalidated**. Existing frozen reports already justify a future independent validation study of those classical candidates **without** inventing new detectors; they do **not** justify production promotion or accuracy claims today.

---

*Read-only audit complete. Stop. No production, Flutter, weight, threshold, or detector changes.*
