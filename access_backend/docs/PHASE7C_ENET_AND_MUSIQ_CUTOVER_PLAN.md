# Phase 7C — ENET runtime findings gate + controlled MUSIQ cutover plan

**Status:** Investigation / plan only. Do **not** set production `QUALITY_ENGINE=musiq_worker` until ENET fallback is proven on this host (or an explicit product decision accepts OpenCV-only local fallback).

**Constraints:** Preserve PROBE / WaveRep, XP, DB evaluation records, Phase 1–6B research artifacts, and `ml/efficientnet_b0_heads.pt`. No Flutter code changes required for cutover if API labels stay truthful.

---

## 1. Phase 7B observations that triggered this gate

| Case | `quality_engine` setting | Observed `analysis.quality_engine` | `opencv_fallback` | `efficientnet_used` |
|------|--------------------------|------------------------------------|-------------------|---------------------|
| MUSIQ success | `musiq_worker` | `musiq_worker` | false | false |
| Worker unavailable | `musiq_worker` (dead URL) | `opencv` | **true** | false |
| Default ENET control | `enet` | `opencv` | **false** | false |

Interpretation:

- ENET control with `opencv_fallback=false` means `preferred_quality_engine()` selected **OpenCV as primary**, not “ENET failed then OpenCV.”
- Worker-unavailable with `opencv_fallback=true` only proves the MUSIQ→…→OpenCV chain labeled OpenCV as fallback; it does **not** prove ENET ran.
- **Blocker:** local EfficientNet-B0 was not the active engine on this machine during 7B.

---

## 2. ENET resolution contract (code)

Files:

- `app/services/efficientnet_b0_scorer.py` — `efficientnet_available()`, `ensure_weights()`, `_get_model()`
- `app/services/torch_runtime.py` — lazy torch import; records `torch_import_error()`
- `app/services/media_evaluator.py` — `preferred_quality_engine()`, `_enet_then_opencv()`, `resolve_quality_engine_for_bytes()`

Default (`QUALITY_ENGINE=enet`):

1. If `efficientnet_available() and ensure_weights()` → prefer `efficientnet-b0`
2. Else if OpenCV → prefer `opencv` with `opencv_fallback=false`
3. Inference failure after ENET preferred → OpenCV with `opencv_fallback=true`

Selectable (`QUALITY_ENGINE=musiq_worker`):

1. Worker classical map (if configured + mappable)
2. Else ENET
3. Else OpenCV (`opencv_fallback=true` when landing on OpenCV after MUSIQ path)

Checkpoint path (must remain): `access_backend/ml/efficientnet_b0_heads.pt`

---

## 3. Diagnostic to run before cutover

```bat
cd /d C:\Users\Dell\Desktop\access_mobile\access_backend
python scripts\diagnose_enet_runtime_phase7c.py
type scripts\_verify_out\phase7c_enet_runtime_diagnose.json
```

Must record: `torch.available`, `torch.import_error`, `pil`, weights exists/size, `efficientnet_available`, `ensure_weights`, `preferred_quality_engine`, and `resolve_default.engine` on the real 7B test photo.

**Pass criterion for “ENET fallback works”:**  
`resolve_default.engine == "efficientnet-b0"` with `efficientnet_used=true` on a live `/media/evaluate` control (process-local `QUALITY_ENGINE=enet`).

**Known host risk (from project incident log):** Windows Smart App Control / Code Integrity can block native ML DLLs (`WinError 4551`). `find_spec`/`pip show` can look fine while `import torch` fails — always trust `torch_import_error()`.

---

## 4. Controlled local cutover plan (`QUALITY_ENGINE=musiq_worker`)

Do this only after Section 3 pass (or written acceptance of OpenCV-only local fallback).

### 4.1 Startup configuration (local process / temporary .env edit when approved)

| Variable | Cutover value | Notes |
|----------|---------------|-------|
| `QUALITY_ENGINE` | `musiq_worker` | Default today remains `enet` until approved |
| `MUSIQ_WORKER_URL` | `http://127.0.0.1:8080` (or TLS URL) | Required |
| `MUSIQ_WORKER_TOKEN` | matching worker secret | Required |
| `MUSIQ_WORKER_TIMEOUT_SEC` | `60`–`90` | Fail closed to ENET/OpenCV |
| `MUSIQ_WORKER_TLS_VERIFY` | `true` in prod-like; `false` only for local HTTP | |
| `QUALITY_SHADOW_ENABLED` | `false` for cutover smoke; optional `true` pre-cutover | Shadow must stay off in `APP_ENV=production` |

Restart FastAPI after env change (`python manage.py runserver`). Do not rely on hot reload for settings.

### 4.2 Worker health checks (before traffic)

1. `GET {MUSIQ_WORKER_URL}/health`
2. `GET {MUSIQ_WORKER_URL}/ready` → `musiq_ready: true`
3. Backend: `musiq_worker_client.readiness_check()` / `production_uses_enet() == false` when flag set

### 4.3 Evaluation matrix (no production data mutation if using `/media/evaluate` preview)

| Case | Action | Required observations |
|------|--------|------------------------|
| Photo happy path | `POST /api/media/evaluate` real JPEG | `analysis.quality_engine=musiq_worker`, seven criteria 1–5, `musiq_opq.context_only=true`, authenticity **deferred** on preview |
| Video happy path | preview short practice MP4 | Same quality engine; Flickering + Motion Stability present; temporal still FastAPI-local |
| Worker down | stop worker or bad URL | Engine is `efficientnet-b0` **or** documented OpenCV with truthful `opencv_fallback`; never invent MUSIQ OPQ |
| Rollback | set `QUALITY_ENGINE=enet`, restart | Engine returns to ENET (or OpenCV-only if ENET still broken on host) |
| Authenticity isolation | saved upload path (staging only) or `evaluate_bytes(..., include_authenticity=True)` in a throwaway process | PROBE/WaveRep unchanged; `ai_detection.detector_backend` ≠ quality engine |

### 4.4 Truthful engine labels

API must keep:

- `analysis.quality_engine` = actual scorer (`musiq_worker` | `efficientnet-b0` | `opencv`)
- `analysis.opencv_fallback` = whether OpenCV was a fallback
- `analysis.efficientnet_used`
- `scoring_engine` / `scoring_model` matching engine
- `analysis.musiq_opq` only when MUSIQ path produced context

### 4.5 Flutter display compatibility (no code change for cutover)

Observed Flutter behavior:

- Prefers API `scoring_model` / `analysis.quality_engine` / `opencv_fallback` from criteria JSON
- Hardcoded default `efficientnet_b0` only when fields are **missing** (legacy rows)

Cutover-safe as long as backend continues to emit explicit `scoring_model` and `analysis.quality_engine`. Optional later UI copy polish is out of scope for cutover enablement.

### 4.6 Rollback

1. Set `QUALITY_ENGINE=enet` (revert temporary local env)
2. Restart FastAPI
3. Confirm `/media/evaluate` → `efficientnet-b0` (or honest OpenCV if ENET host-broken)
4. Leave worker running or stop; shadow optional

### 4.7 Explicit non-goals

- Do not delete or retrain `efficientnet_b0_heads.pt`
- Do not change PROBE / WaveRep / provenance / XP formulas
- Do not rewrite historical `criteria_json` / evaluation rows
- Do not modify Phase 1–6B research CSVs
- Do not deploy or change Flutter in the enablement PR unless labels break

---

## 5. Go / no-go

| Gate | Required |
|------|----------|
| G1 ENET runtime | `diagnose_enet_runtime_phase7c.py` exit 0 **or** product accepts OpenCV-only local fallback in writing |
| G2 Worker | `/ready` green; token configured |
| G3 Photo+video preview | Truthful MUSIQ labels + deferred authenticity on `/media/evaluate` |
| G4 Fallback | Worker kill → ENET (preferred) or OpenCV with `opencv_fallback=true`; no fake OPQ |
| G5 Rollback | `QUALITY_ENGINE=enet` restores prior behavior on this host |

**Current gate status:** G1 is **open / blocking** until Phase 7C diagnostic output is captured on this machine.
