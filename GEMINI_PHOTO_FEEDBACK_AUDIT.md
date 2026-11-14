# ACCESS VisionCheck — Gemini AI Photo Feedback Generation Audit

**Date:** 2026-11-14  
**Scope:** READ-ONLY audit of Gemini coaching / mentor feedback for practice photo (and video) quality evaluation.  
**Constraints honored:** No code, scoring, schema, MUSIQ/OpenCV/EfficientNet/PROBE/WaveRep, Flutter API contract, or research-data changes were made. Secrets are not reproduced.

**Verdict (executive):** Gemini can generate metric-grounded mentor text from the seven (plus video) criterion scores, but several gaps reduce reliability before actual-user testing: N/A criteria can be misread as weak scores, the prompt still assumes EfficientNet-only and omits MUSIQ OPQ / raw metric context / criterion explanations, sharpness↔blur correlation is unguided, and a failed admin-release Gemini call can permanently skip retry. Deterministic local/rule-based feedback exists and is what members see until live Gemini succeeds.

Classification key: **IMPLEMENTED** | **PARTIAL** | **MISSING** | **NOT VERIFIED**

---

## 1. Current feedback generation architecture

| Piece | Classification | Evidence |
|-------|----------------|----------|
| Server-side Gemini HTTP client | **IMPLEMENTED** | `access_backend/app/services/gemini_service.py` → `_gemini_generate` posts text-only `generateContent` to Google Generative Language API |
| Authenticated proxy API | **IMPLEMENTED** | `POST /api/ai/media-evaluation-feedback` in `app/api/routes/ai_assist.py`; router included in `app/api/routes/__init__.py` |
| API key server-only | **IMPLEMENTED** | `settings.gemini_api_key` / `GEMINI_API_KEY` in `app/config.py`; Flutter `GeminiService` calls backend only (`lib/shared/api/gemini_service.dart`) |
| Model config | **IMPLEMENTED** | `GEMINI_MODEL` default `gemini-3.8-flash` (`.env.example`, `config.py`). Whether that model ID is valid in production is **NOT VERIFIED** |
| Auto after `/media/evaluate` | **PARTIAL** | Quality scoring runs without Gemini. Live Gemini is requested asynchronously from the Flutter results screen (`fetchLiveGemini`) or once at admin human-verify release (`member_score_release.release_member_evaluation_scores`) |
| Stored / cached | **PARTIAL** | Admin-release path writes `gemini_feedback` (+ `gemini_generated_at`) into `media_evaluations.criteria_json`. Preview/live path uses client fetch; pipeline can merge client narrative via `merge_client_gemini` |
| On-demand generation | **IMPLEMENTED** | Flutter `EvaluationResultScreen._maybeFetchLiveGemini` → `MemberApiService.fetchGeminiMediaFeedback` |
| Deterministic fallback | **IMPLEMENTED** | `MediaEvaluationFeedback.fromLocal` + backend `ai_feedback` string from `_build_payload` in `media_evaluator.py` |
| Blocks essential scores | **IMPLEMENTED** (does not block) | Scores shown first; Gemini fetched after navigation with 30s client timeout; failures leave local feedback |
| Image sent to Gemini | **MISSING** (by design) | Prompt is scores-only text; no multimodal image parts |

### Trigger paths

1. **Member practice flow (primary UX)**  
   Upload/analyze → scores held or released → if quality feedback allowed and no stored Gemini → show `fromLocal` immediately → results screen sets `fetchLiveGemini: true` → `POST /ai/media-evaluation-feedback` with `toGeminiRequestJson()`.

2. **Admin verifies human**  
   `release_member_evaluation_scores` generates Gemini once into `criteria_json` so later opens can reuse stored `gemini_feedback`.

3. **Other Gemini uses (out of photo-metrics scope but same service)**  
   Rubric feedback (`/ai/rubric-feedback`), admin daily summary (`/ai/admin-daily-summary`).

4. **Not triggered inside** `evaluate_photo` / MUSIQ worker / OpenCV path. Comment on `media.py`: quality preview has no Gemini; Gemini via `POST /ai/media-evaluation-feedback`.

---

## 2. Exact implementation files and functions

| Layer | Path | Functions / types |
|-------|------|-------------------|
| Config | `access_backend/app/config.py` | `gemini_api_key`, `gemini_model` |
| Env template | `access_backend/.env.example` | `GEMINI_API_KEY`, `GEMINI_MODEL` |
| Core Gemini | `access_backend/app/services/gemini_service.py` | `_gemini_generate`, `_criterion_lines`, `_strengths`, `_weaknesses`, `generate_media_evaluation_feedback`, `generate_rubric_feedback`, `generate_admin_daily_summary` |
| HTTP routes | `access_backend/app/api/routes/ai_assist.py` | `media_evaluation_feedback`, `rubric_feedback`, `admin_daily_summary` |
| Schemas | `access_backend/app/schemas/ai_assist.py` | `MediaEvaluationFeedbackIn/Out`, etc. |
| Score release | `access_backend/app/services/member_score_release.py` | `release_member_evaluation_scores` |
| Merge client narrative | `access_backend/app/services/media_evaluator.py` | `merge_client_gemini` |
| Pipeline hook | `access_backend/app/services/media_pipeline.py` | calls `merge_client_gemini` |
| System catalog copy | `access_backend/app/api/routes/system_settings.py` | `feedback_generation` status (configured/model; no key) |
| Flutter API | `lib/shared/api/member_api_service.dart` | `fetchGeminiMediaFeedback` |
| Flutter facade | `lib/shared/api/gemini_service.dart` | `generateMediaEvaluationFeedback` |
| Models | `lib/shared/models/photo_evaluation_result.dart` | `MediaEvaluationFeedback`, `fromLocal`, `toGeminiRequestJson`, `CriterionScore.toJson` |
| Eval UX | `lib/mobile_app/screens/ai_media_evaluation_screen.dart` | sets local feedback + `fetchLiveGemini` |
| Results UX | `lib/mobile_app/screens/evaluation_result_screen.dart` | `_maybeFetchLiveGemini` |
| Display | `lib/mobile_app/widgets/media_evaluation_ui.dart` | `MediaEvaluationResultsPanel`, `AiFeedbackCard`, `LocalFeedbackNotice` |
| Detailed analysis | `lib/mobile_app/screens/evaluation_detailed_analysis_screen.dart` | shows feedback + local flag |
| Quality scoring (inputs source) | `media_evaluator.py`, MUSIQ adapter, OpenCV | Produces `criteria[]`, `overall_score`, `ai_feedback` — **not** Gemini |

---

## 3. Data flow: MUSIQ / OpenCV → Gemini → Flutter

```
Photo bytes
  → media_evaluator (MUSIQ worker + classical OpenCV criteria, or OpenCV fallback, or EfficientNet path)
  → criteria[] (name, score 1–5 or available:false), overall_score, quality_level,
    recommendation, strengths/weaknesses names, ai_feedback (rule text),
    analysis.quality_engine / musiq_opq_context (backend payload; OPQ not in Flutter UI)
  → Flutter PhotoEvaluationResult
  → [optional] MediaEvaluationFeedback.fromLocal (instant)
  → POST /api/ai/media-evaluation-feedback { evaluation: toGeminiRequestJson() }
       gate: AI media eval enabled; member_scores_released; !ai_detection.requires_review
  → gemini_service.generate_media_evaluation_feedback(prompt from overall + criteria lines)
  → Google generateContent (text only)
  → JSON { explanation, strengths[], improvements[], tips[], closing_message }
  → Flutter MediaEvaluationFeedback → AiFeedbackCard below QualityBreakdownCard
```

**Important:** Gemini never sees image pixels. It never recalculates scores. Authenticity (PROBE/WaveRep) is used for **gating** the endpoint when `requires_review`, not as prompt content for quality coaching.

---

## 4. Seven-metric input coverage

Photo criteria intended for VisionCheck quality UI: Sharpness, Blur, Brightness, Contrast, Blocking Artifacts, Color Balance, Color Saturation.

| Input | Sent to Gemini? | How | Classification |
|-------|-----------------|-----|----------------|
| Overall quality score | Yes | `overall_score` / percent / `quality_level` / `recommendation` in prompt | **IMPLEMENTED** |
| Per-criterion 1–5 scores | Yes | `_criterion_lines` from `criteria[]` | **IMPLEMENTED** |
| Criterion display labels (Excellent…Poor / N/A) | Yes | `label` in same lines | **IMPLEMENTED** |
| Strength / weak criterion **names** | Yes | `_strengths` / `_weaknesses` or lists from payload | **IMPLEMENTED** |
| MUSIQ OPQ perceptual prediction | No dedicated field in prompt | `musiq_opq_context` may exist on evaluate payload but is not extracted for Gemini; Flutter `toGeminiRequestJson` does not add OPQ | **MISSING** |
| Sharpness | Via criterion row | Name + score only | **PARTIAL** (no raw Laplacian / explanation text in prompt) |
| Blur | Via criterion row | Same | **PARTIAL** |
| Brightness | Via criterion row | Same | **PARTIAL** |
| Contrast | Via criterion row | Same | **PARTIAL** |
| Blocking artifacts | Via criterion row | Same | **PARTIAL** |
| Color balance | Via criterion row | Same | **PARTIAL** |
| Color saturation | Via criterion row | Same | **PARTIAL** |
| Structured raw continuous metrics | No | Only discrete 1–5 (+ optional unused explanation/suggestion fields on criteria JSON) | **MISSING** |
| Criterion `explanation` / `suggestion` from evaluator | Present on wire in `criteria[]` | **Not** included in Gemini prompt builder | **MISSING** (underused) |
| Original image | No | Text-only API body | **MISSING** (intentional; privacy-positive) |
| Engine identity (MUSIQ vs OpenCV vs ENET) | Partially on wire | `scoring_model` / `scoring_engine` in Flutter map; prompt still hardcodes “EfficientNet-B0” | **PARTIAL** |
| N/A / `available: false` | On wire (`score: null`, `label: N/A`) | Prompt builder mishandles (see §5 / §8) | **PARTIAL** → effectively buggy |

**Structured numerical results:** yes (1–5 + overall).  
**Textual descriptions:** high-level overall/recommendation + strength/weakness **names**; not the detailed metric explanations.  
**Image:** no.

---

## 5. Feedback quality and accuracy assessment

| Expectation | Classification | Notes |
|-------------|----------------|-------|
| Explains measured quality issues | **PARTIAL** | Mentored by weak criterion **names** and scores; may paraphrase well when scores are clear; lacks raw metric / OPQ grounding |
| Practical improvement tips | **IMPLEMENTED** (prompt asks) | Tips array required in JSON schema; local fallback uses criterion `suggestion` |
| Avoid inventing unsupported defects | **PARTIAL** | Prompt forbids inventing/changing scores; model still free to invent photographic causes not evidenced by metrics |
| Correct score directions | **PARTIAL** | All seven photo criteria are high-is-good in UI; prompt does not restate that Blur score high = less blur |
| N/A handling | **PARTIAL** / bug-prone | Flutter sends `score: null` + `available: false`. `_weaknesses` uses `int(item.get("score") or 0) <= 2` → N/A can be listed as “areas to develop”. `_criterion_lines` can emit `None/5` when score is null |
| Avoid contradictory feedback | **PARTIAL** | No explicit Sharpness↔Blur consistency rule; high Sharpness + low Blur (or vice versa) can yield conflicting coach language |
| Does not modify calculated scores | **IMPLEMENTED** | Prompt + architecture; Gemini output is narrative JSON only; UI score ring uses `PhotoEvaluationResult.overallScore` |
| Does not confuse quality with AI-media detection | **IMPLEMENTED** (routing) | Feedback endpoint blocked when `requires_review`; integrity-only UI when scores held; quality card separate from integrity message |
| Prompt currency vs MUSIQ cutover | **PARTIAL** | Prompt text still says scores come from EfficientNet-B0 even when Phase 7I MUSIQ+OpenCV is active |

**Sharpness vs blur (special attention):** Both are independent high-is-good criteria derived from classical/OpenCV-style signals (and related ENET paths historically). The Gemini prompt does **not** instruct the model that (a) Blur score is inverted from “amount of blur,” or (b) the two metrics are correlated and must not contradict each other. Risk of “your image is sharp but also blurry” style copy is real when scores diverge or when N/A mishandling pollutes weaknesses.

---

## 6. Failure handling and fallback assessment

| Failure mode | Behavior | Classification |
|--------------|----------|----------------|
| Missing `GEMINI_API_KEY` | `_gemini_generate` logs warning, returns `None` → route 503; Flutter catch → keep local feedback + `LocalFeedbackNotice` while `feedbackIsLocalFallback` | **IMPLEMENTED** |
| Timeout | Server `urlopen` timeout 45s; Flutter client `.timeout(30s)` → null → local remains | **IMPLEMENTED** |
| Quota / HTTP errors | Logged (status + truncated body); returns `None` → 503 / client null | **IMPLEMENTED** |
| Invalid / empty Gemini text | No candidates or empty parts → `None`; JSON parse fail → `None` | **IMPLEMENTED** |
| Disabled AI media evaluation setting | 503 with admin-disabled message | **IMPLEMENTED** |
| Scores held / requires review | 403; Flutter skips fetch; integrity-only or held messaging | **IMPLEMENTED** |
| MUSIQ offline → OpenCV fallback | Quality criteria still produced; Gemini still receives those scores the same way; no special Gemini branch | **IMPLEMENTED** (path works) / **PARTIAL** (prompt still says EfficientNet) |
| Admin release Gemini fails | Sets `gemini_generated_at` even when `feedback` is null → subsequent releases skip retry | **PARTIAL** (bug) |
| Rule-based feedback without Gemini | Backend `ai_feedback` + Flutter `fromLocal` | **IMPLEMENTED** |

Deterministic feedback **does** work without Gemini and is the default first paint on the results screen.

---

## 7. Privacy and security findings

| Control | Classification | Evidence |
|---------|----------------|----------|
| Credentials server-side | **IMPLEMENTED** | Key only in backend settings; Flutter has no Gemini key |
| Key not logged | **IMPLEMENTED** (with caveat) | Logs omit key; request URL embeds `?key=` (standard Gemini pattern) but URL is not logged in `_gemini_generate`. HTTP error **response** body truncated to 300 chars is logged — typically Google error JSON, not the key |
| Photos not sent externally for feedback | **IMPLEMENTED** | Text prompt only |
| Treat output as untrusted text | **PARTIAL** | Parsed as JSON fields and rendered as UI strings; no HTML injection surface noted in Flutter Text widgets; no extra sanitization layer beyond JSON shape |
| Feedback does not block scores | **IMPLEMENTED** | Async post-navigation fetch |
| Authenticated access | **IMPLEMENTED** | `require_approved` on media feedback route |
| System settings expose key? | **IMPLEMENTED** (safe) | Exposes `configured: bool` and model name only |

Disclosure: members are not shown a specific “your scores were sent to Google Gemini” privacy notice in the audited UI copy (LocalFeedbackNotice only mentions Gemini unavailable). Product disclosure completeness: **PARTIAL** / product decision.

---

## 8. Missing functionality and potential bugs

1. **N/A criteria → false weaknesses** — `_weaknesses` / possibly `_strengths` ignore `available`; null scores coerce to 0 → “areas to develop.”  
2. **`_criterion_lines` null score** — can render `None/5` instead of `N/A` / skip.  
3. **`gemini_generated_at` set on failed generation** — one-shot admin release never retries Gemini.  
4. **Prompt outdated** — still “EfficientNet-B0” after MUSIQ cutover; may confuse operators reading prompts/logs, and under-specifies current engines.  
5. **MUSIQ OPQ unused for coaching** — OPQ is context-only for scoring architecture; Gemini never receives it (consistent with “don’t show competing overall scores,” but also a missed optional context signal if desired later).  
6. **Criterion explanations/suggestions unused in prompt** — Flutter/backend already compute practical suggestions; Gemini re-invents tips from names alone.  
7. **No sharpness/blur consistency instruction** — contradictory mentor copy possible.  
8. **Default model id `gemini-3.8-flash`** — **NOT VERIFIED** against current Google model catalog; misconfiguration would present as chronic 503 / local fallback.  
9. **Wire payload still includes `ai_detection`** in `toGeminiRequestJson` — not placed in the prompt, but is larger than needed; gating uses it server-side (acceptable).  
10. **UI title “AI Feedback”** — fine for mentor copy; ensure members do not read it as authenticity verdict (generally separated by layout when integrity-held).  
11. **System settings description** still says EfficientNet produces scores then Gemini — **PARTIAL** docs drift vs MUSIQ.

---

## 9. Prioritized recommendations

*(No implementation until explicit approval. Preserve seven metrics, overall formula, MUSIQ Docker, OpenCV fallback, ENET rollback, PROBE/WaveRep, Flutter compatibility.)*

### P0 — Fix before actual-user testing

1. **Honor `available: false` in Gemini prompt builders** — skip N/A in `_criterion_lines`, `_strengths`, `_weaknesses`; never coerce null → 0/3 as a scored defect.  
2. **Only stamp `gemini_generated_at` when feedback JSON is successfully stored** (or clear stamp on failure so release can retry).  
3. **Verify live `GEMINI_MODEL` + key** on the deployment host (smoke `POST /ai/media-evaluation-feedback` with a fixture evaluation). Chronic local-fallback with amber notice is a UX regression for testers.

### P1 — Accuracy / coherence

4. Update prompt: scores may come from MUSIQ+OpenCV or OpenCV fallback (or ENET); still forbid mentioning engine names to members.  
5. Add explicit rules: Blur score high = little blur; do not contradict Sharpness; do not invent defects for criteria scored ≥ 4; never discuss AI-generation / authenticity.  
6. Pass (or summarize) existing criterion `explanation`/`suggestion` into the prompt so tips stay metric-tied.  
7. Optionally strip `ai_detection` from the client Gemini request body after server gates on released scores only (defense in depth / payload hygiene).

### P2 — UX polish (preserve single overall score)

8. Keep one overall quality ring (current); do **not** surface MUSIQ OPQ as a second overall in the main results UI.  
9. Soften or clarify “AI Feedback” vs integrity language if testers confuse them.  
10. Consider a short privacy line that mentor text is generated from scores (not by re-uploading the photo to Google) if legal/product requires disclosure.

### P3 — Optional enrichments (only if approved)

11. Optional OPQ as **backend-only** context for Gemini (“perceptual quality estimate band”) without displaying a second score in Flutter.  
12. Persist successful live Gemini back to the evaluation row from the member path (today admin-release persists; live fetch may be ephemeral unless merged via pipeline metadata).

---

## 10. Proposed improvements that preserve existing scoring

These are design proposals only — **not applied**.

| Improvement | Scoring impact |
|-------------|----------------|
| Fix N/A handling in `gemini_service` helpers | None |
| Retry-safe `gemini_generated_at` | None |
| Prompt refresh (engine-agnostic + sharpness/blur rules + use existing suggestions) | None |
| Smoke/config check for model id | None |
| Optional OPQ sentence in prompt only | None (if not shown as competing UI score) |
| Persist live Gemini to `criteria_json` after success | None |

Do **not** change: seven criterion definitions, overall mean-of-available formula, MUSIQ worker integration, OpenCV fallback, EfficientNet rollback flag, PROBE/WaveRep authenticity, Flutter `/media/evaluate` response shape.

---

## Feature checklist (summary)

| Feature | Status |
|---------|--------|
| Server Gemini integration | **IMPLEMENTED** |
| Client API key isolation | **IMPLEMENTED** |
| Trigger after photo evaluation (async, non-blocking) | **IMPLEMENTED** |
| Auto-inline during evaluate (server) | **MISSING** (by design) |
| Store feedback in DB | **PARTIAL** (admin release yes; live path optional/merge) |
| On-demand Flutter fetch | **IMPLEMENTED** |
| Results UI display | **IMPLEMENTED** |
| Local/rule-based fallback | **IMPLEMENTED** |
| Seven-metric score inputs | **IMPLEMENTED** (scores); raw/OPQ **MISSING** |
| Metric-grounded accuracy | **PARTIAL** |
| Failure handling | **IMPLEMENTED** with release-retry **PARTIAL** |
| Privacy (no image upload to Gemini) | **IMPLEMENTED** |
| Separation from authenticity | **IMPLEMENTED** |

---

## Final summary for user testing

**Is Gemini currently generating accurate, metric-grounded photo feedback?**  
**Partially.** When the API key/model work and all criteria are available with clear high/low scores, the architecture correctly feeds overall + criterion scores into a constrained JSON mentor response and does **not** alter calculated scores or authenticity results. Deterministic local feedback already covers Gemini outages.

**What must be fixed before actual-user testing?**  
1. Correct N/A / unavailable criterion handling in the Gemini prompt builders (avoid inventing “improve Blur” when Blur is N/A).  
2. Fix admin-release one-shot stamp so a failed Gemini call can retry.  
3. Confirm production `GEMINI_API_KEY` / `GEMINI_MODEL` actually succeed (otherwise every user only sees the offline summary).  
4. Strongly recommended: update the prompt for MUSIQ/OpenCV reality and add sharpness↔blur / no-invention rules so mentor copy stays coherent with the seven displayed metrics.

No code or scoring changes were made in this audit. Implement only after explicit approval.
