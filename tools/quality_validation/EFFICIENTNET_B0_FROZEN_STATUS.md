# EfficientNet-B0 Quality Assessment — Frozen Status

**Status:** FROZEN  
**Freeze date:** 2026-11-09  
**Owner decision:** Preserve current weights and inference; no further ENET quality development without explicit approval.

---

## What is frozen

| Item | Path / detail |
|------|----------------|
| Weights | `access_backend/ml/efficientnet_b0_heads.pt` |
| Inference | `access_backend/app/services/efficientnet_b0_scorer.py` |
| Rubric wiring | `access_backend/app/services/media_evaluator.py` (`_photo_criteria` ENET/OpenCV heads) |
| Model id / version | `efficientnet-b0` / `1.0` |
| Gate flag | `ENET_DEVELOPMENT_FROZEN = True` in `efficientnet_b0_scorer.py` |

**Do not:** retrain, fine-tune, recalibrate thresholds, replace the backbone/head, or swap in another IQA network for these five criteria.

**Do not:** promote experimental Classical v2 / Blocking v3 into production.

**Do not:** change AI authenticity (PROBE / WaveRep / integrity policy) or video-only Flickering / Motion Stability as part of ENET work.

---

## Active quality presentation (seven criteria)

| # | Criterion | Source | Label |
|---|-----------|--------|-------|
| 1 | Sharpness | EfficientNet-B0 (or OpenCV fallback) | `estimate_kind: experimental_estimate` |
| 2 | Blur | EfficientNet-B0 (or OpenCV fallback) | experimental estimate |
| 3 | Brightness | EfficientNet-B0 (or OpenCV fallback) | experimental estimate |
| 4 | Contrast | EfficientNet-B0 (or OpenCV fallback) | experimental estimate |
| 5 | Blocking Artifacts | EfficientNet-B0 (or OpenCV fallback) | experimental estimate |
| 6 | Color Balance | OpenCV LAB/HSV heuristics | `heuristic_experimental` |
| 7 | Color Saturation | OpenCV HSV heuristics | `heuristic_experimental` |

Noise and Ringing Artifacts are **not** in the active presentation. Checkpoint heads for noise/ringing remain on disk for continuity; `legacy.noise_score` may still be written from the noise metric. Historical `criteria_json` with Noise/Ringing stays readable.

User-facing disclaimer (API + Flutter):

> Quality ratings are automated estimates and may not reflect artistic intent or human judgment.

Payload markers: `analysis.efficientnet_development_frozen: true`, `analysis.quality_estimates: "experimental"`.

---

## Known accuracy limitations (do not overclaim)

Sources: `FIVE_CRITERIA_EVIDENCE_AUDIT.md`, frozen Noise/Ringing NO-GO reports, SPAQ/pilot evidence under `tools/quality_validation/`.

1. **Production EfficientNet-B0** for Sharpness, Blur, Brightness, Contrast, and Blocking showed **FAILED VALIDATION** against ACCESS’s own evidence standard on the frozen pilot / SPAQ-proxy work (near-zero or nonsignificant rank agreement with human medians / weak SPAQ correlations where measured).
2. **Noise and Ringing** remain **KEEP UNVALIDATED / NO-GO**; they were removed from active presentation for that reason, not because a validated replacement model was trained.
3. **Color Balance / Color Saturation** are deterministic heuristics with **documented but unvalidated** thresholds. They are functional estimates only.
4. **Classical v2 / Blocking v3** are **PROMISING BUT UNVALIDATED** research artifacts and must not be treated as production replacements while this freeze holds.
5. Overall 1–5 means and badges are **not** validated photographer skill or competency scores.
6. OpenCV fallback may be used when EfficientNet is unavailable; that path is also unlabeled as scientifically validated.

---

## Allowed maintenance under freeze

- Bugfixes that do not change scores (crashes, NaN guards, auth, serialization).
- Display / disclaimer / historical payload readability.
- Color heuristic bugfixes that do not retune on locked NR15 / pilot-30 sets.
- Authenticity and video temporal criteria work that does not touch ENET weights or the five frozen heads.

## Not allowed without new written approval

- Any change to `efficientnet_b0_heads.pt` or ENET head architecture.
- Recalibrating `_soft_score` / brightness remap to chase accuracy claims.
- Promoting Classical v2/v3 or any new trained IQA head into `_photo_criteria`.
- Claiming validated accuracy or skill ratings from these scores.

---

## Resume criteria (future)

Freeze may be lifted only with explicit product approval plus a pre-registered validation plan on a **new** labeled set (not locked NR15 / pilot-30 for tuning), and a clear decision whether ENET or classical (or neither) is production-bound.

---

## Related docs

- `MEDIA_QUALITY_FINAL_IMPLEMENTATION_REPORT.md` (repo root)
- `tools/quality_validation/FIVE_CRITERIA_EVIDENCE_AUDIT.md`
- `tools/quality_validation/noise_ringing_validation/` (NO-GO evidence)
- `tools/quality_validation/EFFICIENTNET_HEAD_RETRAINING_FEASIBILITY.md` (retrain NO-GO: no labels)
