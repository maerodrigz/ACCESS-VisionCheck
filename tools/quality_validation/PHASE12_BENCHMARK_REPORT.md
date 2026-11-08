# Phase 12 SPAQ-200 predictor benchmark

**Generated:** 2026-11-07T09:46:53.794694+00:00
**Status:** research only. SPAQ-200 locked. No thresholds fitted. Production untouched. Phase 10/11 files not rewritten.

Directions were declared in `DECLARED_PAIRS` before scoring. `?` means the machine series is a physical characteristic, not a quality judgment.

## Runtime

- 12A OpenCV + classical: n=200, mean 19024.922 ms/img, wall 3806.588 s, fail flags=0
- 12B official MUSIQ: n_ok=200 / 200, wall 439.400 s, handle `https://tfhub.dev/google/musiq/paq2piq/1`

## 12A/12B correlations vs SPAQ (locked test)

| Family | Machine | Kind | Exp. sign | n | Spearman (95% CI) | Pearson | Sign OK |
|--------|---------|------|-----------|---|----|---------|---------|
| sharpness | `enet_raw_sharpness` | baseline_raw | + | 200 | 0.117 (-0.021, 0.244) | 0.117 | True |
| sharpness | `criterion_Sharpness` | baseline_badge | + | 200 | 0.086 (-0.033, 0.216) | 0.081 | True |
| sharpness | `opencv_sharpness` | candidate | + | 200 | 0.571 (0.476, 0.655) | 0.516 | True |
| sharpness | `classic_sharpness_laplacian_var` | candidate | + | 200 | 0.571 (0.476, 0.657) | 0.413 | True |
| sharpness | `classic_sharpness_tenengrad` | candidate | + | 200 | 0.734 (0.666, 0.790) | 0.509 | True |
| noise_amount | `enet_raw_noise` | baseline_raw | + | 200 | 0.290 (0.165, 0.412) | 0.293 | True |
| noise_amount | `criterion_Noise` | baseline_badge | - | 200 | -0.264 (-0.389, -0.144) | -0.279 | True |
| noise_amount | `opencv_noise` | candidate | + | 200 | 0.600 (0.505, 0.683) | 0.552 | True |
| noise_amount | `classic_noise_immerkaer` | candidate | + | 200 | 0.369 (0.241, 0.481) | 0.333 | True |
| noise_amount | `classic_noise_residual_std` | candidate | + | 200 | 0.600 (0.505, 0.683) | 0.552 | True |
| brightness | `enet_raw_brightness` | baseline_raw | ? | 200 | -0.075 (-0.226, 0.081) | -0.073 | None |
| brightness | `criterion_Brightness` | baseline_badge | + | 200 | 0.045 (-0.112, 0.174) | 0.063 | True |
| brightness | `opencv_brightness` | candidate | ? | 200 | 0.150 (-0.005, 0.294) | 0.171 | None |
| brightness | `classic_brightness_mean` | candidate | ? | 200 | 0.150 (-0.005, 0.294) | 0.171 | None |
| brightness | `classic_exposure_triangle_048` | candidate | + | 200 | 0.427 (0.296, 0.541) | 0.557 | True |
| brightness | `classic_exposure_clip_frac` | candidate | - | 200 | -0.168 (-0.307, -0.027) | -0.341 | True |
| contrast | `enet_raw_contrast` | baseline_raw | + | 200 | -0.147 (-0.263, -0.019) | -0.125 | False |
| contrast | `criterion_Contrast` | baseline_badge | + | 200 | -0.028 (-0.146, 0.086) | -0.025 | False |
| contrast | `opencv_contrast` | candidate | + | 200 | 0.319 (0.196, 0.441) | 0.371 | True |
| contrast | `classic_contrast_rms` | candidate | + | 200 | 0.316 (0.192, 0.436) | 0.354 | True |
| contrast | `classic_contrast_michelson` | candidate | + | 200 | 0.346 (0.212, 0.461) | 0.357 | True |
| overall | `overall_score` | baseline_badge | + | 200 | -0.067 (-0.204, 0.061) | -0.080 | False |
| overall | `enet_raw_mean_seven` | baseline_raw | ? | 200 | 0.171 (0.041, 0.301) | 0.189 | None |
| overall | `musiq_raw` | candidate | + | 200 | 0.828 (0.776, 0.859) | 0.797 | True |

## Who outperforms ENET (predeclared rule)

A candidate **outperforms** only if Spearman has the declared sign and **|r| is larger** than the ENET raw and/or badge baseline on the same human field. Ambiguous (`?`) constructs are not judged as wins.

| Family | Candidate | Spearman | Beats ENET raw? | Beats ENET badge? | Sign OK |
|--------|-----------|----------|-----------------|-------------------|---------|
| sharpness | `opencv_sharpness` | 0.571 | True | True | True |
| sharpness | `classic_sharpness_laplacian_var` | 0.571 | True | True | True |
| sharpness | `classic_sharpness_tenengrad` | 0.734 | True | True | True |
| noise_amount | `opencv_noise` | 0.600 | True | True | True |
| noise_amount | `classic_noise_immerkaer` | 0.369 | True | True | True |
| noise_amount | `classic_noise_residual_std` | 0.600 | True | True | True |
| brightness | `opencv_brightness` | 0.150 | not_judged_ambiguous_construct | None | None |
| brightness | `classic_brightness_mean` | 0.150 | not_judged_ambiguous_construct | None | None |
| brightness | `classic_exposure_triangle_048` | 0.427 | True | True | True |
| brightness | `classic_exposure_clip_frac` | -0.168 | True | True | True |
| contrast | `opencv_contrast` | 0.319 | True | True | True |
| contrast | `classic_contrast_rms` | 0.316 | True | True | True |
| contrast | `classic_contrast_michelson` | 0.346 | True | True | True |
| overall | `musiq_raw` | 0.828 | True | True | True |

## Unlabeled criteria (no human accuracy claim)

- `blur_opencv`: n=200 min=0.000 max=0.997 mean=0.709 unique=182
- `blur_classic_inv_lap`: n=200 min=0.181 max=0.997 mean=0.800 unique=200
- `blocking_opencv`: n=200 min=0.010 max=0.980 mean=0.512 unique=200
- `blocking_classic_ratio`: n=200 min=0.952 max=2.569 mean=1.162 unique=200
- `ringing_opencv`: n=200 min=0.000 max=0.500 mean=0.113 unique=185
- `ringing_classic`: n=200 min=0.000 max=117.812 mean=16.854 unique=198
- `enet_blur`: n=200 min=0.446 max=0.927 mean=0.701 unique=200
- `enet_blocking`: n=200 min=0.250 max=0.915 mean=0.612 unique=200
- `enet_ringing`: n=200 min=0.271 max=0.824 mean=0.549 unique=200

## Licensing (12B)

{
  "google_research_source": "google-research/google-research source files: Apache License 2.0 (repo LICENSE). musiq/*.py headers are Apache 2.0.",
  "google_research_datasets_in_repo": "Datasets *in that GitHub repo* are CC BY 4.0. MUSIQ training sets (PaQ-2-PiQ/FLIVE, KonIQ, SPAQ, AVA) are not those in-repo datasets.",
  "gcs_npz": "gs://gresearch/musiq/paq2piq_ckpt.npz (and siblings) have no LICENSE or NOTICE object in the bucket listing. Code Apache 2.0 does **not** automatically cover these weights. Production use of the npz is **not established**.",
  "tfhub_paq2piq": "TensorFlow Hub / Kaggle model google/musiq TensorFlow2/paq2piq/1 lists License: Apache 2.0. Output declared [0, 100]. This is the weights artifact used for this verification (SavedModel export of the paper checkpoint).",
  "paq2piq_training_data": "baidut/PaQ-2-PiQ dataset/code is CC BY-NC-SA 4.0. That is a separate training-data term; it does not rewrite the TF Hub Apache label, but counsel should still review commercial use of a model trained on NC-SA data.",
  "pyiqa": "pyiqa 0.1.16 is PolyForm-Noncommercial; converted .pth weights treated as noncommercial. Not used as the official engine.",
  "access": "Research download/inference of the TF Hub Apache SavedModel is in scope. Do not copy the model into access_backend or ship it from this phase."
}

## Recommendations (evidence only)

Candidates beating ENET **raw** under the predeclared rule: `opencv_sharpness`, `classic_sharpness_laplacian_var`, `classic_sharpness_tenengrad`, `opencv_noise`, `classic_noise_immerkaer`, `classic_noise_residual_std`, `classic_exposure_triangle_048`, `classic_exposure_clip_frac`, `opencv_contrast`, `classic_contrast_rms`, `classic_contrast_michelson`, `musiq_raw`. Candidates beating ENET **badge**: `opencv_sharpness`, `classic_sharpness_laplacian_var`, `classic_sharpness_tenengrad`, `opencv_noise`, `classic_noise_immerkaer`, `classic_noise_residual_std`, `classic_exposure_triangle_048`, `classic_exposure_clip_frac`, `opencv_contrast`, `classic_contrast_rms`, `classic_contrast_michelson`, `musiq_raw`. Overall: MUSIQ Spearman 0.828 vs ENET overall badge -0.067 (n=200, MUSIQ ok=200). MUSIQ remains a **separate MOS channel**, not a replacement for the seven badges. Do not fit 1-5 on this test set. pyiqa stays out of production; TF Hub Apache card vs GCS npz NOTICE still applies. Sharpness/Blur remain one Laplacian axis in OpenCV (`blur = 1 - sharpness`). Do not claim independent human validation of Blur, Blocking, or Ringing.

No production changes were made. No further phase was started.

## Verification (no rerun)

Checked 2026-11-07 against saved files only. This report matches `phase12_metrics.json` (generated `2026-11-07T09:46:53.794694+00:00`, 24 correlation rows). Toolkit and `phase12_run_001` copies of this file are identical. Split-run CSVs reproduce the same Tenengrad and MUSIQ series (MUSIQ max abs ~5e-9). See `PHASE12_PREDICTOR_BENCHMARK_PLAN.md` section 8 for combined vs split discrepancies, and `PHASE12_IMPLEMENTATION_DECISION_MATRIX.md` for the stop-here decision record.

