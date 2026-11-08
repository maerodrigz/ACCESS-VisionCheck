# LIVE Challenge independent validation report

**Status: complete.** Raw MUSIQ PaQ-2-PiQ was scored on the official **1,162 LIVEC test images**. No calibration was fitted on LIVEC. Production scoring was not changed.

Artifacts: `tools/quality_validation/workspace/datasets/livec/output/run_livec_001/`  
Generated: 2026-11-06T19:26:32Z

This is **not** a scientific validation of EfficientNet-B0 or of the seven ACCESS technical criteria. LIVEC MOS is overall perceptual quality only.

---

## 1. Dataset integrity

The Globus extract was first found at `workspace/datasets/live_vqc/ChallengeDB_release` (LIVE Challenge, not LIVE-VQC). It was moved to:

`tools/quality_validation/workspace/datasets/livec/ChallengeDB_release`

Official `README.txt` copyright notice is present and was **copied** (not edited) to `livec/metadata/README.txt` and `run_livec_001/LIVE_CHALLENGE_README.copied.txt`.

| Check | Result |
|-------|--------|
| MAT files | `AllImages_release.mat`, `AllMOS_release.mat`, `AllStdDev_release.mat` (key names inspected, not assumed) |
| Mapping | README: MOS in the **same order** as image names. 1,169 rows. First 7 names are `t1.bmp`–`t7.bmp`. |
| Test images | **1,162** on disk (`Images/`: 535 `.bmp`, 627 `.jpg`) |
| Subject-training images | **7** in `Images/trainingImages/` (excluded from scoring) |
| Missing / extra / unreadable | none |
| MOS finite | yes |
| Observed MOS (test) | min **3.42**, max **92.43**, mean **55.40**, stdev **20.31** (continuous, ~0–100, higher better) |
| KonIQ 140 filename overlap | **0** |
| KonIQ 140 SHA-256 overlap | **0** |
| FLIVE/PaQ-2-PiQ ID join | **not possible** (FLIVE not on disk) |

Scoring set: the **1,162 test images only**.

---

## 2. Model

| Item | Value |
|------|-------|
| Environment | `tools/quality_validation/.venv_musiq_research` |
| pyiqa | 0.1.16 |
| torch | 2.15.0+cpu (no CUDA) |
| Metric | `musiq-paq2piq` |
| Checkpoint | `musiq_paq2piq_ckpt-364c0c84.pth` (108,610,983 bytes) |
| SHA-256 | `364c0c840a24dcdb48e963b1f2084e56e39785cf5f49f01c0a4d0e06ac9b52f7` (same file as Phase 2) |
| Preprocess | RGB [0,1] → [-1,1]; multi-scale patches `longer_side_lengths=[224, 384]` plus native resolution |
| Training | PaQ-2-PiQ / FLIVE. Not KonIQ. Not LIVEC (per MUSIQ/PaQ-2-PiQ papers) |
| Calibration | none on LIVEC (`calibrated_1_5` empty on every row) |

---

## 3. Inference

| Item | Value |
|------|-------|
| Evaluated | **1162 / 1162** |
| Failures | **0** |
| Device | CPU |
| Mean time | **658.4 ms/image** |
| Total scoring | **765.1 s** (~12.8 min), plus ~80 s checkpoint load |

Faster than Phase 2’s 1.62 s/image (first-run / different resolution mix). Still too slow for a synchronous production upload without a queue or GPU.

---

## 4. Score distributions (n=1162)

| Series | min | max | mean | stdev |
|--------|-----|-----|------|-------|
| LIVEC MOS | 3.42 | 92.43 | 55.40 | 20.31 |
| MUSIQ raw | 41.04 | 79.38 | 68.04 | 6.89 |

MUSIQ is compressed toward the high 60s. Human MOS spans almost the full 0–100 range.

---

## 5. Correlations (raw MUSIQ vs raw MOS)

| Metric | Value |
|--------|-------|
| n | 1162 |
| Pearson r | **0.8014** (p ≈ 3.3e-261) |
| Spearman r | **0.7672** (p ≈ 6.1e-226) |

MAE **15.19** and RMSE **19.88** were computed because both series are 0–100-like and higher-is-better, with **no LIVEC fit**. Treat them as weak: MUSIQ span (41–79) is much narrower than MOS (3–92), and mean MUSIQ (68) sits above mean MOS (55). Ranking quality is the Pearson/Spearman result, not MAE.

No ACCESS 1–5 map was fitted.

---

## 6. Comparison with KonIQ Phase 2

| Set | n | MUSIQ Pearson | MUSIQ Spearman | EfficientNet Pearson | EfficientNet Spearman |
|-----|---|---------------|----------------|----------------------|------------------------|
| KonIQ Run 001+002 | 140 | 0.820 | 0.821 | 0.142 | 0.109 |
| LIVEC test | 1162 | **0.801** | **0.767** | not run | not run |

Independent LIVEC agreement is a bit lower than the KonIQ exploratory subset, still far above the EfficientNet overall numbers from Phase 2. That supports **cross-dataset overall NR-IQA**, not KonIQ memorization of the 140 files (zero hash overlap).

PaQ-2-PiQ authors reported CLIVE transfer SRCC around 0.74–0.78 for their own models. This MUSIQ Spearman (0.767) sits in that band. It is still not ACCESS criterion accuracy.

---

## 7. Overlap and limitations

- LIVEC is a standard holdout for PaQ-2-PiQ-trained models. Residual FLIVE near-duplicates cannot be proven without FLIVE IDs.
- MOS is crowdsourced overall quality, not Sharpness/Blur/Noise.
- n=1,162 is the full official test set, not a random ACCESS photo sample.
- pyiqa remains **PolyForm Noncommercial**. These weights must not ship in production.
- Official Google MUSIQ Apache 2.0 + `paq2piq_ckpt.npz` is still the candidate production path, unproven in this repo.
- The seven technical criteria and EfficientNet-B0 were not replaced.

---

## 8. Interpretation

On authentic in-the-wild photos with published MOS, pretrained MUSIQ PaQ-2-PiQ **generalizes**: Pearson **0.80**, Spearman **0.77**, 0 failures. That is independent evidence that a dedicated overall NR-IQA model beats the current EfficientNet overall mean of seven heads (Phase 2).

It does **not** authorize a production swap until: (1) an Apache-licensed inference path, (2) a 1–5 map fitted **off** LIVEC, (3) a plan for ~0.7 s CPU (or GPU/queue), and (4) UI copy that overall quality is separate from the seven badges.

---

## 9. Production / licensing

- Dataset: UT Austin LIVE Challenge notice (use with full copyright text and citation). Original README preserved.
- pyiqa 0.1.16: research-only, not in `access_backend`.
- FastAPI, PostgreSQL, Flutter, React Admin, PROBE, WaveRep, Gemini: unchanged.

Stopped for review.
