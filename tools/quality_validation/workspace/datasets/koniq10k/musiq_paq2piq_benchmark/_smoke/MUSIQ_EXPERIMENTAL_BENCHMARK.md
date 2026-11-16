# MUSIQ PaQ-2-PiQ experimental benchmark

Research-only comparison of pretrained **MUSIQ PaQ-2-PiQ** (`pyiqa` id `musiq-paq2piq`) against existing EfficientNet-B0 overall scores on the same 140 KonIQ-10k images from Run 001 (n=40) and Run 002 (n=100).

This is **not** a scientific validation of EfficientNet-B0, MUSIQ, or ACCESS VisionCheck. KonIQ MOS is an aggregate overall label. It is not the seven ACCESS technical criteria.

## Safeguards

- Production files were not modified (`media_evaluator.py`, `efficientnet_b0_scorer.py`, API, PostgreSQL, Flutter, React, PROBE, WaveRep, Gemini).
- Baseline CSVs and JPEGs were read-only.
- `pyiqa` was installed only in `tools/quality_validation/.venv_musiq_research`.
- No retraining, fine-tuning, or calibration fitted on these 140 images.
- Raw model outputs were saved before any error metric decision.

## Environment

| Item | Value |
|------|-------|
| Python | 3.12.10 (tags/v3.12.10:0cc8128, Apr  8 2025, 12:21:36) [MSC v.1943 64 bit (AMD64)] |
| Interpreter | `C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\.venv_musiq_research\Scripts\python.exe` |
| Platform | Windows-11-10.0.26200-SP0 |
| torch | 2.15.0+cpu |
| torchvision | 0.29.2+cpu |
| timm | 1.0.31 |
| pyiqa | 0.1.16 |
| CUDA | False (CPU-only) |
| Disk free at start | 27.87 GB |

## Licensing (noncommercial)

- **pyiqa package:** PolyForm Noncommercial License 1.0.0 (current PyPI/pyproject.toml). Historical README/issue #294 also described CC BY-NC-SA 4.0. Treat as noncommercial research-only.
- **pyiqa weights:** pyiqa pretrained weights are typically CC BY-NC-SA 4.0 or otherwise noncommercial. Do not ship in ACCESS production.
- **PaQ-2-PiQ original:** PaQ-2-PiQ (baidut/PaQ-2-PiQ) is CC BY-NC-SA 4.0.
- **ACCESS implication:** Allowed for this isolated research benchmark. Not a production license. Do not install pyiqa into access_backend.

Installed license snippets are copied under the output folder (`license_files.json`).

## Model

| Item | Value |
|------|-------|
| Metric id | `musiq-paq2piq` |
| Device | cpu |
| Load time | 84.691 s |
| Declared score_range | ~0, ~100 |
| lower_better | False |
| metric_mode | NR |
| Checkpoint files | [
  {
    "path": "C:\\Users\\Dell\\Desktop\\access_mobile\\tools\\quality_validation\\workspace\\datasets\\koniq10k\\musiq_paq2piq_benchmark\\_smoke\\cache\\torch\\hub\\pyiqa\\musiq_paq2piq_ckpt-364c0c84.pth",
    "size_bytes": 108610983,
    "sha256": "364c0c840a24dcdb48e963b1f2084e56e39785cf5f49f01c0a4d0e06ac9b52f7"
  },
  {
    "path": "C:\\Users\\Dell\\Desktop\\access_mobile\\tools\\quality_validation\\.venv_musiq_research\\Lib\\site-packages\\pyiqa\\archs\\paq2piq_arch.py",
    "size_bytes": 3453,
    "sha256": "f2a6edaa7fc8db5789ef5ff6b709f87ed788a620b754cb44380835dc8eed634c"
  },
  {
    "path": "C:\\Users\\Dell\\Desktop\\access_mobile\\tools\\quality_validation\\.venv_musiq_research\\Lib\\site-packages\\pyiqa\\archs\\__pycache__\\paq2piq_arch.cpython-312.pyc",
    "size_bytes": 5438,
    "sha256": "3b65d83dbfa7d976478b70c318fbc9c5d5eeb8910f6cb4f2299b1a6d1de0262a"
  }
] |

**Preprocessing:** pyiqa MUSIQ converts RGB tensors in [0,1] to [-1,1], then extracts multi-scale patches with longer_side_lengths=[224, 384] (native resolution retained as a scale). Do not resize to 224x224 the way EfficientNet-B0 production scoring does.

**Output scale:** pyiqa default_model_configs lists musiq-paq2piq score_range as '~0, ~100' (PaQ-2-PiQ / FLIVE MOS-like). This is not KonIQ ACR 1-5.

**Training overlap:** Checkpoint key pretrained='paq2piq' loads musiq_paq2piq_ckpt-364c0c84.pth. Trained on PaQ-2-PiQ/FLIVE, not KonIQ-10k. Default pyiqa id 'musiq' is KonIQ and was not used.

## Images

- Run 001: 40 files from `C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\datasets\koniq10k\images` joined to `C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\datasets\koniq10k\metadata\output\run_001\per_image_results.csv`
- Run 002: 100 files from `C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\datasets\koniq10k\run_002\images` joined to `C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\datasets\koniq10k\run_002\output\per_image_results.csv`
- Unique filenames: 1
- Successful MUSIQ scores: 1
- Failures: 0 []
- Mean inference time: 2903.4 ms
- Total inference time: 2.9 s

## Score distributions

| Series | n | min | max | mean | stdev |
|--------|---|-----|-----|------|-------|
| KonIQ MOS (1-5) | 1 | 3.4035 | 3.4035 | 3.4035 | 0.0000 |
| EfficientNet-B0 overall (1-5) | 1 | 3.5700 | 3.5700 | 3.5700 | 0.0000 |
| MUSIQ PaQ-2-PiQ raw | 1 | 75.4046 | 75.4046 | 75.4046 | 0.0000 |

## Correlations (raw MUSIQ vs MOS)

Rank and linear association use **raw** MUSIQ outputs. No affine map was fitted on these images.

| Comparison | n | Pearson r | Pearson p | Spearman r | Spearman p | MAE | RMSE |
|------------|---|-----------|-----------|------------|------------|-----|------|
| MUSIQ raw vs KonIQ MOS | 1 | N/A | N/A | N/A | N/A | not comparable (scale) | not comparable (scale) |
| EfficientNet-B0 vs KonIQ MOS | 1 | N/A | N/A | N/A | N/A | 0.1665 | 0.1665 |
| MUSIQ raw vs EfficientNet-B0 | 1 | N/A | N/A | N/A | N/A | not comparable (scale) | not comparable (scale) |

MAE/RMSE vs MOS for MUSIQ: **not computed: MUSIQ PaQ-2-PiQ raw scores are on a ~0-100 scale, not KonIQ MOS 1-5. No eval-set calibration was fitted.**

## By split

### Run 001 (n=40)

| Comparison | Pearson r | Spearman r | MAE | RMSE |
|------------|-----------|------------|-----|------|
| MUSIQ vs MOS | N/A | N/A | not comparable (scale) | not comparable (scale) |
| EfficientNet vs MOS | N/A | N/A | 0.1665 | 0.1665 |

### Run 002 (n=100)

| Comparison | Pearson r | Spearman r | MAE | RMSE |
|------------|-----------|------------|-----|------|
| MUSIQ vs MOS | N/A | N/A | not comparable (scale) | not comparable (scale) |
| EfficientNet vs MOS | N/A | N/A | N/A | N/A |

## Finding

Insufficient paired scores to compare rank correlation.

## Overlap and limitations

The evaluated JPEGs are KonIQ-10k files. MUSIQ PaQ-2-PiQ was trained on PaQ-2-PiQ/FLIVE, not KonIQ, so this is a cross-dataset test (unlike default pyiqa `musiq`, which is KonIQ-trained and would leak). Flickr-source collision between FLIVE and KonIQ cannot be proven zero without a full ID join; it is not documented as a shared split. Run 001/002 were MOS-quintile samples, not the official KonIQ test split. EfficientNet overall is the mean of seven quantized 1-5 heads after `_soft_score`, not a MOS-trained head. n=140 is small. CPU-only inference. pyiqa is noncommercial.

## Outputs

All new artifacts are under `C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\datasets\koniq10k\musiq_paq2piq_benchmark` and `tools/quality_validation/MUSIQ_EXPERIMENTAL_BENCHMARK.md`. Run 001/002 folders were not rewritten.

Generated at 2026-11-06T18:31:34.956104+00:00.
