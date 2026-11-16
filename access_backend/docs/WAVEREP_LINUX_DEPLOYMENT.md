# WaveRep G4 — Linux / Kamatera deployment checklist

Practice **videos** use WaveRep G4 when `WAVEREP_ENABLED=true`. **Photos** always use `AI_DETECTOR_BACKEND=probe` (PROBE-DINOv2). Do not enable WaveRep on the Windows facilitator machine if Application Control blocks pandas.

## 1. Python imports (actual chain)

| Module | Imports |
|--------|---------|
| `app.services.waverep_g4_detector` | stdlib, `torch` (via detector) |
| `ml/waverep/waverep_detector.py` | `cv2`, `torch`, `numpy`, `PIL`, **`scipy.special.expit`**, `demo.utils` |
| `ml/waverep/demo/utils.py` | `torch` (≥2.0.1), **`timm`** (≥1.0.12), **`pandas`**, `numpy`, `PIL`, **`tqdm`**, `torchvision.transforms` |

Checkpoint (default): `access_backend/ml/waverep/demo/weights/weights_dinov2_G4.ckpt`

## 2. Dependencies (`requirements.txt`)

Install on the Linux server:

```bash
cd access_backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

WaveRep-specific pins (also in `requirements.txt`):

- `scipy>=1.11.0,<2.0`
- `timm>=1.0.12,<2.0`
- `pandas>=2.0.0,<3.0`
- `tqdm>=4.66.0`

Already required for the rest of the backend: `torch`, `torchvision`, `opencv-python-headless`, `numpy`, `Pillow`.

### Compatibility notes

| Package | Notes |
|---------|--------|
| **Python** | 3.11–3.12 tested in project; use same major as Kamatera image |
| **PyTorch** | `torch>=2.2.0` satisfies WaveRep `torch>=2.0.1` |
| **NumPy 2.x** | Backend pins `numpy>=2.0.0`; use scipy 1.11+ and pandas 2.x (included above) |
| **timm** | Pulls compatible `torchvision`; first init may download DINOv2-base pretrained weights (network) |
| **CPU vs GPU** | Default `WAVEREP_DEVICE=cpu`; set `cuda` only if NVIDIA driver + CUDA torch build are installed |

## 3. Environment variables (`.env`)

Copy from `.env.example`. **Default production-safe:**

```env
WAVEREP_ENABLED=false
AI_DETECTOR_BACKEND=probe
```

When ready on Linux:

```env
WAVEREP_ENABLED=true
WAVEREP_DEVICE=cpu
WAVEREP_SAMPLES=20
MAX_MEDIA_EVALUATION_WORKERS=1
```

Optional overrides: `WAVEREP_MODULE_DIR`, `WAVEREP_CHECKPOINT_PATH`, `WAVEREP_MIN_SUCCESSFUL_FRAMES`.

## 4. Pre-flight checklist (Linux)

- [ ] Repository includes `ml/waverep/` and checkpoint file (not git-LFS omitted on server).
- [ ] `pip install -r requirements.txt` succeeds (no import errors for `scipy`, `timm`, `pandas`).
- [ ] `ffmpeg` available on PATH (quality pipeline; WaveRep uses OpenCV for frames).
- [ ] `python scripts/waverep_linux_verify.py` → `detector_initialized: true`.
- [ ] Optional: `python scripts/waverep_linux_verify.py --benchmark path/to/sample.mp4` (isolated file, no DB).
- [ ] Set `WAVEREP_ENABLED=true`, restart API only after verify passes.
- [ ] `GET /api/health` still OK; photos unchanged (`integrity.detector_backend` remains `probe`).

## 5. CPU / RAM guidance (Kamatera sizing)

| Phase | CPU-only rough expectation |
|-------|----------------------------|
| **Process RSS after WaveRep load** | Often **+2–4 GB** (DINOv2-base + checkpoint; varies by torch/timm) |
| **First model init** | **1–5+ minutes** on modest vCPU; subsequent in-process loads are singleton |
| **Per video eval** | Up to **`WAVEREP_SAMPLES`** (default 20) forward passes; **tens of seconds to many minutes** on CPU |
| **Concurrency** | Keep **`MAX_MEDIA_EVALUATION_WORKERS=1`** on CPU-only hosts |

GPU: set `WAVEREP_DEVICE=cuda` and install CUDA-matched torch; reduce wall time substantially.

## 6. Safe CPU-only benchmark (no production DB)

Uses local bytes only; does **not** insert media or call Gemini.

```bash
cd access_backend
source .venv/bin/activate
# Init only
python scripts/waverep_linux_verify.py

# Init + one offline analyze (use repo test asset or your own short .mp4)
python scripts/waverep_linux_verify.py \
  --benchmark evaluation_results/step8b/assets/step8b_real_phone_smoke.mp4
```

Record `init_seconds` and `benchmark_seconds` for Kamatera sizing. Do not run against production PostgreSQL.

## 7. Video routing vs PROBE fallback

| `WAVEREP_ENABLED` | Video authenticity path |
|-------------------|-------------------------|
| **`false`** | FFmpeg frames → **PROBE** per frame (`detector_backend: probe`). Expected today on Windows. |
| **`true`** | Full video bytes → **`detect_ai_generated_video`** → WaveRep only (`detector_backend: waverep_g4`). **No silent PROBE fallback** in this branch. |

If WaveRep is enabled but the detector fails to load or analyze:

- API returns **`waverep_analysis_unavailable_payload`**: `detector_backend: waverep_g4`, **`waverep_analysis_unavailable: true`**, `waverep_processing_status: unavailable`, review required.
- Logs: `WaveRep G4 unavailable: ...` from `waverep_g4_detector._resolve_detector_instance`.

**How to avoid mistaking PROBE for WaveRep**

1. Inspect saved eval: `criteria_json.ai_detection.detector_backend` must be **`waverep_g4`** for new videos.
2. If enabled, **`probe` on a new video** means routing bug or `WAVEREP_ENABLED` not loaded (restart API after `.env` change).
3. Run `python scripts/waverep_linux_verify.py` before enabling; extend `/api/health` `integrity` with `waverep_runtime_status()` in a future change for ops visibility (optional).

## 8. Enable sequence (after checklist)

1. Verify script passes on Linux.
2. Set `WAVEREP_ENABLED=true` in server `.env` only.
3. Restart `python manage.py runserver` (or systemd unit).
4. Confirm with a **new** test video upload (facilitator-approved): JSON shows `waverep_g4` and WaveRep-specific `detail` string.
5. Do **not** reprocess historical evaluations.
