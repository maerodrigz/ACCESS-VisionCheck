# ACCESS VisionCheck — Media quality integration readiness plan

**Date:** 2026-11-08  
**Status:** Plan only (no production code changes in this step)  
**Evidence freeze:** combined v1 + Noise/Ringing v4 pilot diagnostic; TDR `TECH_DECISION_RECORD_QUALITY_ENGINE_RESEARCH_20261108.md`

---

## 0. Hard non-promotions

| Candidate | Decision |
|-----------|----------|
| Noise v4 PCA | **Do not promote** (pilot REGRESSED vs v2/v3) |
| Ringing v3 | **Do not promote** (pilot harsh floor; ρ negative) |
| Ringing v4 | **Do not promote** (pilot REGRESSED; constant badge-1 on scored set) |
| Noise v3 | **Do not promote** (prior MIXED; not selected over v2) |
| EfficientNet-B0 weights / head | **Keep** unless a separate approved retrain |

Skill rule (unchanged product intent): photo-quality badges and mean overall must **not** be the sole automatic determinant of member skill tier; skill already aggregates eligible practice evals under integrity gates (`skill_evaluation_eligibility` / `skill_scoring`). Any hybrid scorer must not invent a new “quality badge → skill tier” shortcut.

---

## 1. Current production path (as-is)

| Layer | File(s) | Behavior |
|-------|---------|----------|
| Primary scorer | `access_backend/app/services/efficientnet_b0_scorer.py` | ENET-B0 + Linear(1280→7) → continuous metrics in `[0,1]` for 7 criteria |
| Fallback | `access_backend/app/services/opencv_quality.py` via `media_evaluator.resolve_quality_engine_for_bytes` | OpenCV Laplacian/residual/flat-block/ring proxies when ENET unavailable/fails; sets `opencv_fallback=true` |
| Mapping to 1–5 | `access_backend/app/services/media_evaluator.py` → `_soft_score` | `boosted = clip01(metric*0.5 + 0.42)` then bins; **badge 1 unreachable** for metric∈[0,1]; badge 2 only for metric ≲ 0.08 |
| API payload | `media_evaluator` build path + `quality_score_display.py` | Criteria list + DB columns; Noise stored inverted (`1 - Noise/5`) |
| Flutter UI | `lib/mobile_app/widgets/quality_breakdown_card.dart`, `evaluation_criterion_meta.dart`, `criterion_score_bar.dart` | Renders criterion name/score/label; meta copy treats all seven as peer technical measures |
| Skill | `skill_evaluation_eligibility.py`, `skill_scoring.py` | Eligible practice **overall_score** averages feed skill %; not per-criterion. Integrity statuses can exclude evals |

Research classical v2 (Sharpness/Blur/Brightness/Contrast/Noise) and Blocking v3 live only under `tools/quality_validation/` today and are **not** wired into `media_evaluator`.

---

## 2. Stabilization strategy (feature-flagged hybrid)

**Intent:** Keep ENET-B0 as the default production engine. Optionally, behind flags, replace **OpenCV fallback** (and/or a narrow “classical overlay” mode) with research-backed classical metrics for the promising heads—without retraining ENET and without promoting failed Noise/Ringing detectors.

### 2.1 What to incorporate

| Criterion | Source | Integration stance |
|-----------|--------|--------------------|
| Sharpness | experimental v2 Tenengrad → equal_bin (or continuous q) | **Candidate for classical fallback / hybrid overlay** |
| Blur | experimental v2 `log1p(LapVar)` freedom-from-blur | **Candidate** |
| Brightness | experimental v2 exposure triangle (same family as production brightness q) | **Candidate** |
| Contrast | experimental v2 RMS×clip gate | **Candidate** |
| Blocking | Blocking v3 lattice excess | **Cautious optional** (flag separate from the four-head pack) |
| Noise | Keep ENET (or current OpenCV residual) | **Keep represented**; mark **unvalidated / provisional** in UI metadata when classical path used; **not** Noise v3/v4 |
| Ringing | Keep ENET (or current OpenCV) | **Keep represented**; mark **unvalidated / provisional**; **not** Ringing v3/v4 |

### 2.2 Blocking v3 suitability

- **Pros:** Pilot ρ improved −0.33 → +0.21; synthetic JPEG ladder OK; false texture penalty reduced vs v2.
- **Cons:** Human labels almost only 4–5 (low discrimination); center-crop `ANALYSIS_CAP`; still a proxy.
- **Stance:** Optional second flag `QUALITY_CLASSICAL_BLOCKING_V3=1`, default **off**. Enable only after lightweight regression + staged canary. Do not block the Sharpness/Blur/Brightness/Contrast pack on Blocking.

### 2.3 Noise / Ringing presentation (must stay visible)

Do **not** drop criteria (API/Flutter contract). Add structured reliability metadata, e.g. per criterion:

```json
"reliability": "primary" | "provisional" | "unvalidated",
"measurement_note": "..."
```

- ENET path: `primary` (model estimate; not human-validated on ACCESS rubric).
- Classical hybrid for Sharpness/Blur/Brightness/Contrast: `primary` or `classical_v2` once flagged.
- Noise & Ringing under any path in this phase: `unvalidated` (or `provisional`) with copy that scores are informational and not skill gates by themselves.
- Flutter: subtle subtitle/chip from `evaluation_criterion_meta.dart` / breakdown card—**no** removal of bars.

### 2.4 `_soft_score` compression (investigate → optional fix behind flag)

Current: `boosted = metric * 0.5 + 0.42`  
Effects:

- Compresses dynamic range toward mid/high badges.
- **Score 1 unreachable** for metrics in `[0,1]`; score 2 nearly unreachable.
- Inflates “Good/Excellent” rates and weakens separation for poor media.

**Plan:** Introduce `QUALITY_SCORE_MAPPING=soft|equal_bin` (default `soft` for rollback parity).  
`equal_bin` = research `equal_bin_1_5` (can emit 1–5). Apply only when flag set; golden tests compare both. Do **not** change default until approved.

### 2.5 Overall score vs skill

- Keep overall as mean of displayed 1–5 criteria (API compatible).
- Document in API/UI: overall is a **technical summary**, not a competency grade.
- **No new code path** that maps a single media overall badge → `skill_level`.
- Skill continues to use eligible evaluation averages + integrity gates; optional later work (out of scope here): exclude `unvalidated` heads from skill-eligible overall—only if product approves a schema change.

---

## 3. Exact files to change (when implementation is approved)

### Backend (primary)

| File | Change |
|------|--------|
| `access_backend/app/config.py` (or settings/.env) | Flags: `QUALITY_CLASSICAL_V2_FALLBACK`, `QUALITY_CLASSICAL_BLOCKING_V3`, `QUALITY_SCORE_MAPPING`, maybe `QUALITY_HYBRID_MODE=off\|fallback_only\|overlay` |
| `access_backend/app/services/classical_quality_v2.py` **(new)** | Port **read-only copy** of Sharpness/Blur/Brightness/Contrast (+ optional Blocking v3 call) from `tools/quality_validation/`—**do not import tools at runtime in prod** |
| `access_backend/app/services/opencv_quality.py` | Optionally delegate to classical_v2 when flag on; keep legacy functions for rollback |
| `access_backend/app/services/media_evaluator.py` | Wire hybrid resolve; reliability fields on criteria; mapping switch; preserve response keys |
| `access_backend/app/services/quality_score_display.py` | Pass through reliability / notes if stored |
| `access_backend/.env.example` | Document flags (default off / soft) |

### API / persistence

| File | Change |
|------|--------|
| Criteria JSON in evaluation payload (built in `media_evaluator`) | Add optional `reliability`, `engine_detail` **without removing** `name`/`score`/`label` |
| DB columns | **No migration required** for phase 1 if extras live in `criteria_json` only |

### Flutter

| File | Change |
|------|--------|
| `lib/shared/models/photo_evaluation_result.dart` (or equivalent criterion model) | Parse optional `reliability` |
| `lib/mobile_app/widgets/quality_breakdown_card.dart` | Show provisional/unvalidated affordance |
| `lib/mobile_app/widgets/evaluation_criterion_meta.dart` | Copy for Noise/Ringing unvalidated; Blocking if classical |
| `test/media_quality_eval_display_test.dart` | UI regression for new chips |

### Tests (minimal)

| File | Change |
|------|--------|
| `access_backend/tests/test_media_quality_eval_correctness.py` | Flag off ≡ current soft_score/ENET path |
| `access_backend/tests/test_classical_quality_v2_fallback.py` **(new)** | Synthetic sharp/blur/bright/contrast (+ optional JPEG blocking) |
| `access_backend/tests/test_quality_score_mapping.py` **(new)** | soft vs equal_bin reachability (1 reachable only under equal_bin) |

### Explicitly do **not** change in this integration

- `efficientnet_b0_scorer.py` model architecture/weights  
- `experimental_*` tools modules (remain research)  
- Human CSVs / prior eval outputs  
- Noise v4 / Ringing v3/v4 modules (research only)  
- Skill tier formulas (unless a later approved eligibility tweak)

---

## 4. Expected behavior by flag

| Mode | Behavior |
|------|----------|
| All flags default | Identical to today’s ENET → soft_score → OpenCV legacy fallback |
| `QUALITY_CLASSICAL_V2_FALLBACK=1` | When ENET fails/unavailable, OpenCV path uses classical v2 for Sharpness/Blur/Brightness/Contrast; Noise/Ringing stay legacy OpenCV; mark reliability |
| `QUALITY_HYBRID_MODE=overlay` (optional phase 2) | ENET still runs; replace only the four continuous metrics with classical q before mapping—**higher risk**; requires canary |
| `QUALITY_CLASSICAL_BLOCKING_V3=1` | Blocking metric from v3 on fallback/overlay path only |
| `QUALITY_SCORE_MAPPING=equal_bin` | equal_bin_1_5 on quality-oriented q; enables true 1–5 span |

API: same seven criterion names + overall; clients ignoring unknown fields keep working.

---

## 5. Risks

| Risk | Mitigation |
|------|------------|
| Score distribution shift vs historical evals | Flags default off; compare soft vs equal_bin on fixtures before default flip |
| Overlay mode fights ENET on real photos | Ship fallback_only first; overlay only after canary |
| Blocking v3 false calm (ceiling) | Separate flag; UI note; monitor admin complaints |
| Flutter ignores reliability | Backend still safe; add UI tests |
| Skill averages move if mapping changes | Keep soft default; any equal_bin default needs product sign-off + skill impact note |
| Runtime on OpenCV/classical path | Classical four-heads + optional Blocking crop already bounded; add ms logging |

---

## 6. Rollback strategy

1. Set all new flags to **off** / `soft` (config/env only)—immediate revert to ENET+legacy OpenCV+`_soft_score`.  
2. If code must be reverted: revert the PR; no DB migration in phase 1.  
3. Keep research engines untouched so rollback does not delete experimental evidence.  
4. Feature flag name and defaults recorded in `.env.example` and release notes.

---

## 7. Minimal test plan (no SPAQ, no frozen pilot re-run)

1. **Parity:** flags off → byte-identical criterion scores vs current golden fixtures (`test_media_quality_eval_correctness`).  
2. **Mapping unit:** metric 0 → soft≠1; equal_bin can emit 1; metric 1 → 5 both.  
3. **Classical fallback:** synthetic sharp vs blurred; dark vs mid exposure; low vs high contrast; assert monotone directions.  
4. **Blocking optional:** JPEG Q95 vs Q10 gradient → Blocking v3 amount rises when flag on.  
5. **Payload schema:** response still has seven names; `reliability` present when hybrid on.  
6. **Flutter widget test:** Noise/Ringing show unvalidated affordance when reliability set.  
7. **Smoke:** `GET`/`POST` existing media eval preview path with flag off on staging.

Explicitly **out of scope** for this readiness gate: SPAQ-200, frozen 30-pilot re-inference, ENET retrain, Noise/Ringing detector work.

---

## 8. Recommended implementation order (after approval)

1. Config flags + `_soft_score` mapping switch (default soft) + tests.  
2. Port classical four-heads into `classical_quality_v2.py`; wire **fallback_only**.  
3. Reliability metadata + Flutter chips for Noise/Ringing.  
4. Optional Blocking v3 flag.  
5. Staging canary → decide whether equal_bin or overlay ever defaults on.  
6. **Stop** for product approval before any default-on change.

---

## 9. Summary verdict for readiness

| Item | Ready? |
|------|--------|
| Plan / flags / tests design | Yes |
| Promote Sharpness/Blur/Brightness/Contrast v2 as **flagged classical fallback** | Yes (after implementation approval) |
| Cautious Blocking v3 flag | Yes, default off |
| Promote Noise v3/v4 or Ringing v3/v4 | **No** |
| Change ENET weights | **No** (unless separately approved) |
| Production code edits in this step | **No** (plan only) |
