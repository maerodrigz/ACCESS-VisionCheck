# WaveRep G4 integration (Phase 2)

## Target architecture

| Component | Role |
|-----------|------|
| PROBE-DINOv2 | Image authenticity only (retained) |
| WaveRep G4 | Sole automated **video** AI detector when `WAVEREP_ENABLED=true` |
| EfficientNet-B0 + FFmpeg | Video **quality** only (unchanged frame count via `EVALUATION_VIDEO_SAMPLE_FRAMES`) |
| Camera metadata | Supporting evidence via `apply_probe_provenance_policy` |
| Admin | Final verification (unchanged UI in this phase) |

## File placement (not copied yet)

```
access_backend/
  ml/waverep/
    waverep_detector.py
    demo/
      utils.py
      weights/
        weights_dinov2_G4.ckpt
```

Environment (`.env`):

```env
WAVEREP_ENABLED=false
WAVEREP_MODULE_DIR=ml/waverep
WAVEREP_CHECKPOINT_PATH=ml/waverep/demo/weights/weights_dinov2_G4.ckpt
WAVEREP_DEVICE=cpu
WAVEREP_SAMPLES=20
WAVEREP_MIN_SUCCESSFUL_FRAMES=1
```

Verified checkpoint (2026-10): **346,163,178 bytes**, SHA-256  
`50D639049D928986BA7D69861A4FE4F3E7AFBBA1843E3E089CDF6B4748F53D5B`

## Integration hook

Practice videos are evaluated in the **deferred** pipeline:

1. `POST /api/media/upload` stores bytes and calls `schedule_deferred_media_evaluation`.
2. Worker runs `run_pipeline` → `evaluate_bytes` → `evaluate_video`.
3. Quality: `extract_frames` (default 4) + EfficientNet-B0.
4. Authenticity: `detect_ai_generated_from_frames` → when `WAVEREP_ENABLED=true`, `detect_ai_generated_video` in `app/services/waverep_g4_detector.py` (original video bytes, no PROBE on frames).

Photos and `POST /api/media/evaluate` preview paths are unchanged.

## `waverep_detector.py` API (implemented in adapter)

```python
WaveRepDetector(weights=str(checkpoint_path), device="cpu", samples=20)
result = detector.analyze(str(video_path))  # temp file from upload bytes
```

Maps `ai_score` (0–1), `processed_frames`, `requested_frames`, `status` (`complete` / `partial`), `failed_frames` (index list), and `frame_results` into `ai_detection` + `exif_metadata.waverep_supplementary`.

## Failure behavior (when enabled)

- Import failure, missing checkpoint, inference error, insufficient frames, or missing score → `requires_review=True`, **no PROBE fallback**, not classified as verified human.

## Dependency compatibility (current backend venv)

| Package | Installed | PROBE usage | WaveRep notes |
|---------|-----------|-------------|---------------|
| torch | 2.13.0+cpu | Yes (PROBE) | Confirm WaveRep project uses same major; second large model increases RAM |
| torchvision | 0.28.0+cpu | Yes | Align preprocessing with WaveRep training |
| numpy | 2.5.1 | Yes | Usually compatible |
| opencv-python-headless | 5.0.0 | FFmpeg fallback + CV | WaveRep should prefer direct decode in its module |
| scipy | Not installed globally | Pulled via PROBE `vendor_lib` / matplotlib path | Install only if WaveRep requires it; verify no conflict |
| timm | Not installed | PROBE uses Hugging Face `transformers` + DINOv2 | If WaveRep uses `timm`, pin version and test alongside PROBE import |
| transformers | Via PROBE vendor | DINOv2 large | Separate from WaveRep unless shared |

**Do not** upgrade torch/transformers for WaveRep until both PROBE and WaveRep smoke tests pass in the same venv.

## Remaining steps before activation

1. Copy `waverep_detector.py` and checkpoint into `ml/waverep/`.
2. Align the analyze API with the adapter (or add a thin shim in `ml/waverep/`).
3. Run WaveRep smoke test on a short practice clip with `WAVEREP_ENABLED=true` on a dev machine.
4. Confirm `GET /api/health` and login stay responsive during inference (worker pool default 1).
5. Update admin Media Integrity UI to show WaveRep fields (`waverep_raw`, frame counts) — deferred.
6. Optional: expose `waverep_runtime_status()` on `/api/health` integrity block after activation.
