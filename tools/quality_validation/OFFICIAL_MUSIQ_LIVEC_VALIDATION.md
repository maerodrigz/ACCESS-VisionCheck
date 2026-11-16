# Official MUSIQ LIVE Challenge validation (Phase 6)

**Status: complete.** Official TensorFlow Hub MUSIQ PaQ-2-PiQ scored the same **1,162 LIVEC test images** used in Phase 3. No retraining, no LIVEC calibration, no production changes, no deployment.

LIVEC MOS is overall perceptual quality only. This is **not** scientific validation of EfficientNet-B0 or of the seven ACCESS technical criteria.

Generated: 2026-11-07T00:06:46Z  
Artifacts: `tools/quality_validation/workspace/datasets/livec/output/run_official_livec_001/`  
Script: `tools/quality_validation/official_musiq_livec_validation.py`  
Venv: `tools/quality_validation/.venv_musiq_official/` (same Phase 5 TF CPU env)

---

## Phase 5 equivalence failure (preserved)

Phase 5 compared official TF Hub vs pyiqa on **24 KonIQ** JPEGs with gates frozen **before** judging:

| Gate | Threshold | Phase 5 (n=24 KonIQ) |
|------|-----------|----------------------|
| Pearson | ≥ 0.999 | 0.99975 |
| Spearman | ≥ 0.999 | **0.99217 (fail)** |
| mean \|diff\| | ≤ 0.50 | 0.073 |
| max \|diff\| | ≤ 2.0 | 0.263 |

**Phase 5 primary equivalent remains false.** Those thresholds were not edited. A later LIVEC engine comparison (section 6) does not reopen or reverse that 24-image verdict.

---

## 1. Engine

| Item | Value |
|------|-------|
| Handle | `https://tfhub.dev/google/musiq/paq2piq/1` (same as Phase 5) |
| tensorflow | 2.21.0 CPU |
| tensorflow-hub | 0.16.1 |
| Hub cache | Phase 5 `.../official_musiq_engine_verification/cache/tfhub` |
| Parameters | unchanged SavedModel; `num_classes` not touched |

Caller input: raw file bytes. The Hub graph uses **`DecodeJpeg`**. LIVEC BMPs therefore cannot be passed through natively.

---

## 2. Dataset

Same Phase 3 set: `ChallengeDB_release` test split, MOS from `AllMOS_release.mat` in file order, **t1–t7 excluded**. Joined 1:1 to saved pyiqa `run_livec_001/raw_predictions.csv` on `source_media_key`.

- Test images: **1,162**
- JPEG/JPG: **627** (native Hub path)
- BMP: **535** (lossless RGB **PNG** bytes, then Hub; tagged `png_fallback`)

PNG fallback changes container, not a JPEG recompress. Residual BMP vs pyiqa (PIL/torch BMP decode vs PNG) is a documented engine difference, not a MOS leak.

---

## 3. Inference

| Item | Value |
|------|-------|
| Official ok | **1162 / 1162** |
| Failures | **0** |
| png_fallback | **535** (all BMPs) |
| Model load | 13.2 s |
| Mean CPU | **1875 ms/image** |
| First image (XLA) | 12.3 s |
| Mean after first | **~1.87 s/image** |

No 1–5 map was fitted.

---

## 4. Official vs published LIVEC MOS

| Metric | Official TF Hub | Phase 3 pyiqa (same MOS, saved) |
|--------|-----------------|----------------------------------|
| n | 1162 | 1162 |
| Pearson r | **0.8047** | 0.8014 |
| Spearman r | **0.7703** | 0.7672 |

p-values are vanishingly small (Pearson p ≈ 6e-265). No LIVEC fit.

MAE/RMSE vs MOS are **not** treated as product error: official raw spans **40.94–79.34** (mean 67.71) while MOS spans **3.42–92.43** (mean 55.40). Same compression seen in Phase 3.

---

## 5. Distributions (n=1162)

| Series | min | max | mean | stdev |
|--------|-----|-----|------|-------|
| LIVEC MOS | 3.42 | 92.43 | 55.40 | 20.30 |
| official raw | 40.94 | 79.34 | 67.71 | 6.94 |
| pyiqa raw | 41.04 | 79.38 | 68.04 | 6.88 |

---

## 6. Official vs pyiqa on the same 1,162 files

| Metric | Value |
|--------|-------|
| Pearson r | **0.99938** |
| Spearman r | **0.99933** |
| mean \|diff\| | **0.344** |
| max \|diff\| | **1.689** |
| RMSE | **0.415** |
| Rank position changed | **1074 / 1162** |
| Mean \|rank delta\| | **8.75** |
| Max \|rank delta\| | **70** |

Applying the **unchanged Phase 5 numeric gates** to this **different** n=1162 set would pass Pearson/Spearman/MAE/max (primary_equivalent true here, strict false because max diff 1.69 ≫ 0.05). That does **not** rewrite Phase 5’s n=24 KonIQ fail.

Many rank “changes” are local swaps among near-tied scores (mean rank shift ~9 of 1162). Spearman 0.9993 is the ranking summary; the 1074 count is not 1074 large inversions.

Likely extra residual vs Phase 5: **535 BMP→PNG** conversions plus TF vs PyTorch preprocess. Max engine gap (1.69) is still small on a ~0–100 scale.

---

## 7. Independent overall-quality reading

Official TF Hub MUSIQ vs LIVEC MOS: Pearson **0.805**, Spearman **0.770**, 0 failures, no calibration.

That is independent evidence that this Apache-labeled SavedModel tracks published overall MOS on authentic in-the-wild photos at about the same level as research pyiqa (0.801 / 0.767). The descriptive bar used in this report was both coefficients ≥ 0.70.

It does **not**:

- validate Sharpness / Blur / Noise / Brightness / Contrast / Blocking / Ringing
- replace `overall_score` (mean of seven/nine integers)
- authorize production deploy, XP changes, or averaging OPQ into badges

---

## 8. Licensing and deployment limits

- TF Hub / Kaggle `google/musiq` TensorFlow2 **paq2piq/1**: labeled **Apache 2.0**.
- GitHub MUSIQ **source**: Apache 2.0.
- GCS `paq2piq_ckpt.npz`: **no LICENSE/NOTICE object**; not used; production rights **not** established.
- PaQ-2-PiQ / FLIVE **training data**: CC BY-NC-SA 4.0. Counsel still needed for commercial use of a model trained on that set.
- pyiqa remains PolyForm-NC; not a production engine.
- Hub **`DecodeJpeg`**: BMP (and likely some other still formats) need a lossless re-encode. ACCESS uploads include JPEG, PNG, HEIC, video frames. That is an engineering gap, not solved here.
- CPU ~1.9 s/image is too slow for a fully synchronous mobile upload without a queue or GPU.
- Do not copy the SavedModel into `access_backend/`.

---

## 9. Production

Unchanged: FastAPI scoring, EfficientNet-B0, seven criteria, `overall_score`, XP, recommendations, Flutter, React Admin, PostgreSQL, PROBE, WaveRep, Gemini.

Stopped for review.
