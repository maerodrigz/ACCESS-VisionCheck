# Phase 7E — Bottleneck report (preliminary)

**Status:** Code-path + Phase 7D evidence. Step-level timings require:

```bat
cd /d C:\Users\Dell\Desktop\access_mobile\access_backend
python scripts\profile_opencv_quality_phase7e.py
```

Agent Shell could not execute the profiler (exit 2). No scoring changes were made.

---

## Phase 7D facts (measured)

| Engine | Mean latency | Notes |
|--------|-------------:|-------|
| EfficientNet-B0 | **209.85 ms** | Fastest |
| MUSIQ + OpenCV (Docker) | **4776.27 ms** | Worker RSS sample **3.602 GiB** |
| Local OpenCV fallback | **4888.84 ms** | Similar to full MUSIQ path |

Images were multi-MB phone JPEGs (Phase 7D `image_bytes` ≈ **2.8–6.9 MB** each).

---

## Root causes (code + Phase 7D, pending step timers)

### 1. EfficientNet is fast because input is tiny

`efficientnet_b0_scorer._preprocess` always **resizes to 224×224** before the CNN. Cost is decode/orientation + small tensor ops + forward. Pixel-loop cost does **not** scale with 12 MP sensors.

### 2. Local OpenCV is slow because it runs native resolution + Python loops

File: `app/services/opencv_quality.py`

| Step | Implementation | Resolution policy |
|------|----------------|-------------------|
| Decode | PIL EXIF transpose → full BGR | Native |
| Sharpness | `Laplacian` variance | Native |
| Blur | `1 - sharpness` | Native |
| Noise | GaussianBlur + residual std | Native |
| Brightness / contrast | mean / std | Native |
| **Blocking** | Nested **Python** `for` over every **8×8** patch + `np.var` | **Native, no cap** |
| **Ringing** | Canny + **Python** per-row sign-change loops | **Native, no cap** |

There is **no** `RESIZE_CAP`. On a ~4000×3000 photo, blocking alone visits on the order of **~1.5e5–2e5** Python iterations. That alone can explain multi-second local OpenCV times and why local OpenCV (4889 ms) rivals the entire MUSIQ HTTP path (4776 ms).

Repeated work: `analyze_image_bytes` decodes once per call; Phase 7D timed that once per image (not double-decode inside the scorer). Broader pipelines (color heuristics + quality) may decode again separately — secondary vs blocking/ringing.

### 3. MUSIQ path is slow for different reasons

Worker classical (`musiq_worker` / `quality_shadow.classical`):

- **Does** apply `RESIZE_CAP = 1024` before classical metrics → classical on worker should be much cheaper than local `opencv_quality`.
- Still has Python `_flat_block_frac` / `_blocking_boundary_ratio`, but on ≤1024 px.

MUSIQ PaQ-2-PiQ (`musiq_engine.score_image_bytes`):

- Feeds **original JPEG bytes** into TensorFlow Hub — **no** client/worker resize before OPQ.
- OPQ is **context only**; it is not an OpenCV criterion score.
- Large JPEGs + TF + Docker RSS (**3.6 GiB**) dominate this path.

Client also uploads **full multi-MB** bodies over HTTP to the worker (transfer overhead on top of `duration_ms`).

### 4. Why local OpenCV ≈ MUSIQ total (interpretation)

| Path | Expensive part |
|------|----------------|
| Local OpenCV | Native-res **blocking + ringing** Python loops |
| MUSIQ + OpenCV | **Upload + TF MUSIQ** on full JPEG; classical after 1024 resize is comparatively small |

Same ballpark latency, **different** bottlenecks. Speeding up one does not automatically fix the other.

---

## Safe optimization candidates (not implemented)

1. **Vectorize** local `_blocking_artifacts` / `_ringing_artifacts` with identical math (threshold 8.0, block 8, Canny 80/160) — preserve formulas; verify bit/score parity.
2. **Optional longest-side cap** for local OpenCV (align with worker 1024) — **only after** frozen-set score parity vs current native baseline; do not change thresholds “for speed.”
3. **Reuse decoded BGR** across quality + color heuristics — no formula change.
4. **MUSIQ input policy** (downscale before TF) — would change OPQ numbers; needs explicit acceptance; does not affect OpenCV criteria if classical stays separate.
5. **Keep ENET** as fast local fallback / rollback — do not delete checkpoint.

---

## Next measurement (required to finalize)

Profiler: `scripts/profile_opencv_quality_phase7e.py`  
Writes: `phase7e_performance_investigation/profile_raw.json` + `BOTTLENECK_REPORT.md` with per-step ms, native vs diagnostic 1024, and MUSIQ split (client wall / worker `duration_ms` / classical proxy / MUSIQ residual estimate).

No production scoring changes until those numbers are reviewed.
