# Technical decision record: ACCESS VisionCheck photo-quality research (freeze)

**Date:** 2026-11-08  
**Status:** Research phase closed for further detector tuning  
**Primary package:** `output/combined_v1_eval_20261108T143610Z`  
**Supporting packages:** `exp_eval_v2_20261108T123035Z`, Noise/Blocking/Ringing v3 lightweight or full evals, `pilot_hvsm_20261108T114511Z`  

**Safety:** Production scoring, Flutter, API contracts, databases, experimental engine sources, evaluation outputs, and original human rating CSVs are preserved and were not modified for this freeze.

---

## Decision

Freeze further Noise/Ringing/Blocking detector tuning against the frozen ACCESS 30-image pilot. Keep `experimental_classical_combined_v1` as the documented research integration checkpoint only. Do not promote any experimental quality engine to production without a new, independent validation set and explicit product approval.

---

## Seven-criterion summary

| Criterion | Research status | Evidence snapshot (ACCESS pilot Spearman vs human median, n=30, diagnostic) | Notes |
|-----------|-----------------|-----------------------------------------------------------------------------|--------|
| Sharpness | Promising (further validation) | combined/v2 **0.62** vs production **0.10** | Retained from `experimental_classical_v2` |
| Blur | Promising (further validation) | combined/v2 **0.82** vs production **0.16** | Retained from v2 |
| Brightness | Promising (further validation) | combined/v2 **0.40** vs production **0.06** | Retained from v2 |
| Contrast | Promising (further validation) | combined/v2 **0.34** vs production **0.09** | Retained from v2 |
| Blocking Artifacts | Research candidate (Blocking v3) | combined **+0.21** vs v2 **−0.33** vs production ~**0.00** | `experimental_blocking_v3` in combined v1 |
| Noise | Unresolved | combined/v2 **−0.25** vs production **−0.27** | v2 kept; Noise v3 not promoted |
| Ringing Artifacts | Ringing v3 **not recommended** | combined (v3) **−0.42** vs v2 **−0.40** vs production ~**0.01** | v3 floors many clean photos to badge 1 |

**Overall (pilot, mean of seven badges vs human overall):** production **0.04**, v2 **0.38**, combined **0.43** (diagnostic only).  
**SPAQ-200 overall vs MOS (diagnostic):** v2 **0.59**, combined **0.56**, production **−0.07**. SPAQ has no Blur/Blocking/Ringing attribute labels.

Composition of `experimental_classical_combined_v1`: Sharpness/Blur/Noise/Brightness/Contrast from v2; Blocking from Blocking v3; Ringing from Ringing v3; Noise v3 remains an alternate estimator only.

---

## Unresolved limitations (must carry forward)

1. **Pilot size and role.** n=30 is a frozen secondary check. It must not be used to fit thresholds or claim final validation of the combined composition.
2. **Low inter-rater agreement (Noise, Ringing).** From `pilot_hvsm_20261108T114511Z`: Noise Fleiss κ ≈ **0.039**, mean QWK ≈ **0.305**; Ringing Fleiss κ ≈ **0.128**, mean QWK ≈ **0.185**. Within-one agreement is higher, but ordinal reliability is weak to near-chance. Disagreement mixes detector limits and construct ambiguity.
3. **Noise failure mode.** Machine scores are near-ceiling (mostly badge 5) while humans use 3–5; systematic over-cleanliness and negative Spearman. Not fixed by Noise v3 under prior gates.
4. **Ringing v3 failure mode.** Strong floor (many badge 1) on photos humans rate clean (4–5); worsens absolute error and can drag mean-of-seven overall. **Not recommended** for further promotion.
5. **Ringing v2 (cached comparison, no retune).** Lower MAE than Ringing v3 (≈ **0.85** vs ≈ **2.45**) but Spearman remains negative (≈ **−0.40**). Lower error does **not** equal validated rank agreement; do not treat v2 Ringing as human-validated.
6. **Blocking v3.** Improves pilot rank sign vs v2 but human labels are almost only 4–5; discrimination remains limited.
7. **SPAQ scope.** Useful for Sharpness/Noise/Brightness/Contrast proxies and exploratory MOS correlation; cannot adjudicate Blocking/Ringing ACCESS-rubric claims.

---

## Skill classification / member feedback

Photo-quality criterion badges and the mean-of-seven overall score must **not** automatically determine member skill classification or competency tier. Overall is an unweighted mean of proxies and can be dominated by a single harsh head (especially Ringing). Prefer per-criterion research feedback only; any product-facing overall requires a separate aggregation and messaging policy.

---

## Future validation (recommended before more detector work)

1. Build an **independent** ACCESS-rubric labeled set (disjoint from the frozen 30).
2. Clarify **Noise** and **Ringing** rating definitions; recalibrate raters; target stronger inter-rater reliability before claiming detector success or failure.
3. Pre-register scales / composition; do not fit on that holdout.
4. Re-evaluate promising heads (Sharpness, Blur, Brightness, Contrast) and Blocking v3 as a research candidate; treat Noise and Ringing as open measurement problems until reliability improves.

---

## Ready for further validation vs unresolved

**Ready for further validation (research only; not production):**
- Sharpness (v2)
- Blur (v2)
- Brightness (v2)
- Contrast (v2)
- Blocking Artifacts v3 (research candidate)
- Combined v1 as an integration checkpoint for the above composition decisions

**Unresolved / not recommended to advance as-is:**
- Noise (v2 and v3): unresolved; do not promote
- Ringing Artifacts v3: not recommended
- Ringing Artifacts v2: lower MAE only; Spearman still negative; not validated
- Mean-of-seven overall as a skill or member-grade signal: not approved

**Explicit non-actions for this freeze:** no production/Flutter/backend scoring changes; no experimental engine edits; no SPAQ, inference, or human-pilot re-runs; no manuscript revisions.
