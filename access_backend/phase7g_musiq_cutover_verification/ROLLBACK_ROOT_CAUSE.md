# Phase 7G ENET rollback failure — root cause

## Observed

`rollback_enet_control` returned:

- `analysis.quality_engine = opencv`
- `analysis.opencv_fallback = false`
- `analysis.efficientnet_used = false`

## Meaning

`opencv_fallback=false` means `preferred_quality_engine()` selected **OpenCV as primary**, not “ENET failed then OpenCV”. So at request time:

`efficientnet_available() and ensure_weights()` was **false**.

Same signature as Phase 7B ENET control (OpenCV primary). Phase 7C direct `ensure_weights()` on the **main thread** succeeded.

## Root cause

1. `POST /api/media/evaluate` runs scoring in `asyncio.to_thread(...)`.
2. EfficientNet lazy init (`_get_model`) was first hit **inside that worker thread**.
3. Load failures were **swallowed** (`except Exception: return None`) with no `last_load_error`.
4. Resolver then preferred local OpenCV with `opencv_fallback=false`.

Phase 7C worked because it called `ensure_weights()` / inference on the main thread, not via TestClient `to_thread`.

## Fix (no formula / weight changes)

1. Surface load errors via `last_load_error()` / `runtime_status()` / logging.
2. Warm `ensure_weights()` on the **event-loop thread** in `/media/evaluate` when `QUALITY_ENGINE=enet` **before** `to_thread`.
3. Deferred lifespan warm on the event-loop thread when `QUALITY_ENGINE=enet`.
4. Phase 7G verifier prints `warm_main_thread()` diagnostics before rollback POST.

## Rollback path preserved

- `QUALITY_ENGINE=enet` → EfficientNet-B0
- `QUALITY_ENGINE=musiq_worker` → MUSIQ → optimized OpenCV (ENET not used)
