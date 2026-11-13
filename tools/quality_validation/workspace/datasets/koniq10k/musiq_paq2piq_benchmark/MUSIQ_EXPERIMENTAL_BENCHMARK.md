# MUSIQ PaQ-2-PiQ experimental benchmark

Research-only comparison of pretrained **MUSIQ PaQ-2-PiQ** (`pyiqa` id `musiq-paq2piq`) against existing EfficientNet-B0 overall scores on the same **140 KonIQ-10k JPEGs** from Run 001 (n=40) and Run 002 (n=100).

This is **not** a scientific validation of EfficientNet-B0, MUSIQ, or ACCESS VisionCheck. KonIQ MOS is an aggregate overall label. It is not the seven ACCESS technical criteria.

Official numeric artifacts: `tools/quality_validation/workspace/datasets/koniq10k/musiq_paq2piq_benchmark/` (generated 2026-11-06T18:35:43Z).

## Safeguards

- Production files were not modified (`media_evaluator.py`, `efficientnet_b0_scorer.py`, API, PostgreSQL, Flutter, React, PROBE, WaveRep, Gemini).
- Baseline CSVs and JPEGs were read-only. Run 001/002 output folders were not rewritten.
- `pyiqa` was installed only in `tools/quality_validation/.venv_musiq_research`. The production interpreter still has `pyiqa` **not installed**.
- No retraining, fine-tuning, or calibration fitted on these 140 images.
- Raw model outputs were saved first (`raw_predictions.csv`). `calibrated_1_5` is empty on every row.

## 1. Environment

| Item | Production interpreter | Research venv |
|------|------------------------|---------------|
| Python | 3.12.10 | 3.12.10 (same installer, isolated venv) |
| Path | `C:\Users\Dell\AppData\Local\Programs\Python\Python312\python.exe` | `tools/quality_validation/.venv_musiq_research/Scripts/python.exe` |
| torch | 2.13.0+cpu | 2.15.0+cpu |
| torchvision | 0.28.0+cpu | 0.29.2+cpu |
| timm | 1.0.30 | 1.0.31 |
| pyiqa | not installed | 0.1.16 |
| CUDA | false, 0 devices | false, 0 devices |
| GPU | none | none |

- Platform: Windows 11 (10.0.26200)
- Disk: C: about 254.95 GB total. Free **30.62 GB** before research installs, **27.65 GB** at benchmark start (venv + pyiqa + 104 MB checkpoint).
- Inference device: **CPU only**.

## 2. Licensing (noncommercial)

Installed `pyiqa-0.1.16` METADATA: `License-Expression: PolyForm-Noncommercial-1.0.0`.

| Piece | Restriction |
|-------|-------------|
| pyiqa package | PolyForm Noncommercial 1.0.0. Historical GitHub issue #294 also described CC BY-NC-SA 4.0. Treat as **research / noncommercial only**. |
| pyiqa weights | Hosted by chaofengc/IQA-PyTorch-Weights. Typical IQA-PyTorch weight terms are **CC BY-NC-SA 4.0**. Do not ship in ACCESS production. |
| PaQ-2-PiQ original code/dataset | CC BY-NC-SA 4.0 (`baidut/PaQ-2-PiQ`). |
| MUSIQ paper code | Google Research TensorFlow source; this run used the pyiqa PyTorch port of converted checkpoints. |

**ACCESS implication:** this experiment is allowed as isolated research. It is **not** a production license. Do not `pip install pyiqa` into `access_backend`.

## 3. Checkpoint, preprocessing, output scale

| Item | Value |
|------|-------|
| Metric id | `musiq-paq2piq` (not default `musiq`, which is KonIQ-trained) |
| Architecture | MUSIQ, `pretrained='paq2piq'` |
| File | `musiq_paq2piq_ckpt-364c0c84.pth` (108,610,983 bytes) |
| SHA-256 | `364c0c840a24dcdb48e963b1f2084e56e39785cf5f49f01c0a4d0e06ac9b52f7` |
| Source URL | `https://huggingface.co/chaofengc/IQA-PyTorch-Weights/resolve/main/musiq_paq2piq_ckpt-364c0c84.pth` |
| Declared `score_range` | `~0, ~100` |
| `lower_better` | false (higher is better) |
| `metric_mode` | NR |
| Load time (cached) | 0.765 s |

**Preprocessing (from loaded `data_preprocess_opts`):** RGB tensor in [0, 1] is mapped to [-1, 1]. Multi-scale patches use `patch_size=32`, `longer_side_lengths=[224, 384]`, and the original resolution (`max_seq_len_from_original_res=-1`). This is **not** the production EfficientNet 224×224 ImageNet crop.

**Output scale:** raw scores on this run ranged **50.23 to 79.03** (mean 71.93). That matches a ~0–100 PaQ-2-PiQ/FLIVE-style MOS, **not** KonIQ ACR 1–5. MAE/RMSE vs KonIQ MOS were therefore **not computed**. No affine map was fitted on the evaluation images.

**Known overlap with these 140 files:** the PaQ-2-PiQ checkpoint is trained on PaQ-2-PiQ/FLIVE, not KonIQ-10k. This is a **cross-dataset** test. Default pyiqa `musiq` (KonIQ) was not used, because Run 001/002 images come from the KonIQ pool and would leak. Flickr-source collision between FLIVE and KonIQ is not documented as a shared split; it cannot be proven zero without a full ID join.

## 4. Images

| Split | n | Image folder | Baseline CSV (read-only) |
|-------|---|--------------|--------------------------|
| Run 001 | 40 | `workspace/datasets/koniq10k/images/` | `.../metadata/output/run_001/per_image_results.csv` |
| Run 002 | 100 | `workspace/datasets/koniq10k/run_002/images/` | `.../run_002/output/per_image_results.csv` |
| Combined | **140 unique filenames** | | |

## 5. Inference

| Item | Value |
|------|-------|
| Successful predictions | **140 / 140** |
| Failures | **0** |
| Mean time / image | **1621.4 ms** (CPU) |
| Total scoring time | **227.0 s** |

## 6. Score distributions (n=140)

| Series | min | max | mean | stdev |
|--------|-----|-----|------|-------|
| KonIQ MOS (1–5) | 1.588 | 4.175 | 3.228 | 0.506 |
| EfficientNet-B0 overall (1–5) | 3.00 | 4.14 | 3.573 | 0.194 |
| MUSIQ PaQ-2-PiQ raw | 50.23 | 79.03 | 71.93 | 5.172 |

EfficientNet overall is compressed toward 3–4. MUSIQ raw uses a different numeric range and a much larger spread.

## 7. Correlations (raw MUSIQ vs MOS)

| Comparison | n | Pearson r | Pearson p | Spearman r | Spearman p | MAE | RMSE |
|------------|---|-----------|-----------|------------|------------|-----|------|
| MUSIQ raw vs KonIQ MOS | 140 | **0.8200** | 3.02e-35 | **0.8213** | 1.89e-35 | not comparable | not comparable |
| EfficientNet-B0 vs KonIQ MOS | 140 | 0.1417 | 0.095 | 0.1085 | 0.202 | 0.4842 | 0.6194 |
| MUSIQ raw vs EfficientNet-B0 | 140 | 0.1126 | 0.185 | 0.1073 | 0.207 | not comparable | not comparable |

MAE/RMSE vs MOS for MUSIQ: **not computed**. Raw PaQ-2-PiQ scores are ~0–100. No eval-set calibration was fitted.

### Run 001 (n=40)

| Comparison | Pearson r | Spearman r | MAE | RMSE |
|------------|-----------|------------|-----|------|
| MUSIQ vs MOS | 0.7995 | 0.7876 | not comparable | not comparable |
| EfficientNet vs MOS | 0.2088 | 0.1252 | 0.4394 | 0.5452 |

### Run 002 (n=100)

| Comparison | Pearson r | Spearman r | MAE | RMSE |
|------------|-----------|------------|-----|------|
| MUSIQ vs MOS | 0.8252 | 0.8294 | not comparable | not comparable |
| EfficientNet vs MOS | 0.1088 | 0.0953 | 0.5021 | 0.6467 |

Run 001/002 EfficientNet figures match the previously stored baseline analysis (small floating-point differences only).

## 8. Finding

On this 140-image KonIQ subset, **MUSIQ PaQ-2-PiQ raw scores track published MOS far more closely than EfficientNet-B0 overall** (Spearman **0.821 vs 0.109**; Pearson **0.820 vs 0.142**). The same pattern holds on both splits.

That does **not** authorize replacing production scoring:

- MUSIQ predicts one overall perceptual score. It does not output Sharpness, Blur, Noise, Brightness, Contrast, Blocking, or Ringing.
- pyiqa and these weights are **noncommercial**.
- EfficientNet overall is the mean of seven quantized 1–5 heads after `_soft_score`, not a MOS-trained head. Weak MOS correlation was expected from the validity diagnostic.
- n=140, CPU-only, KonIQ MOS ≠ ACCESS rater protocol.

## 9. Overlap and limitations

- Evaluation images are KonIQ-10k. The checkpoint was trained on PaQ-2-PiQ/FLIVE, not KonIQ (cross-dataset). Residual Flickr ID collision is unproven.
- Run 001/002 are MOS-quintile research samples (seeds 20261106 / 20261107), not the official KonIQ test split.
- Pearson/Spearman are the fair metrics here. Absolute error on 1–5 would require a mapping fitted on **held-out** data, which this phase did not do.
- pyiqa PolyForm-NC / CC BY-NC-SA blocks a drop-in production swap without a separate licensing path.

## 10. How to rerun (research venv only)

```powershell
cd C:\Users\Dell\Desktop\access_mobile
.\tools\quality_validation\.venv_musiq_research\Scripts\python.exe tools\quality_validation\musiq_paq2piq_benchmark.py
```

Do not install `requirements-musiq-research.txt` into `access_backend`.
