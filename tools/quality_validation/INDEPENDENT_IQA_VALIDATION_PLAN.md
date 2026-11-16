# Independent IQA validation plan (LIVE Challenge)

Research and planning only. **Do not download LIVEC, checkpoints, or TensorFlow packages until this plan is approved.** Do not modify production API, `media_evaluator.py`, `efficientnet_b0_scorer.py`, PostgreSQL, Flutter, React Admin, PROBE, WaveRep, or Gemini.

This plan follows Phase 2 (`MUSIQ_EXPERIMENTAL_BENCHMARK.md`): MUSIQ PaQ-2-PiQ vs EfficientNet-B0 on 140 KonIQ images (Pearson 0.820 vs 0.142, Spearman 0.821 vs 0.109, about 1.62 s/image on CPU). Phase 2 is **exploratory and KonIQ-based**. Phase 3 is an **independent** overall-quality check.

KonIQ MOS is not ACCESS criterion ground truth. LIVE Challenge MOS is also overall-only.

---

## 1. Why LIVE Challenge (LIVEC / CLIVE)

**Official name:** LIVE In the Wild Image Quality Challenge Database (Ghadiyaram and Bovik, 2015/2016). Common aliases: **LIVEC**, **CLIVE**, **LIVE Challenge**.

| Property | Documented value |
|----------|------------------|
| Content | Authentic mobile-camera photos (no synthetic distortion overlays) |
| Test images | **1,162** (`Images/`) |
| Subject-training images | **7** (`Images/trainingImages/`). These trained *human raters* in the original study, not MUSIQ. |
| Total in MOS MAT files | **1,169** names in `AllImages_release.mat` / `AllMOS_release.mat` |
| Raters | Crowdsourced (Mechanical Turk); >350,000 scores; >8,100 observers; about 175 ratings per test image |
| Distortion type | In-the-wild mixtures (capture, processing, storage). Not labeled as Sharpness/Blur/Noise. |
| Role vs KonIQ | Different lab, different collection, different MOS protocol. Not the 140 Phase 2 files. |

This matches ACCESS member photos better than synthetic IQA sets (LIVE IQA, TID2013). LIVE-VQC is **video** and is the wrong independent set for still-image MUSIQ.

**Primary Phase 3 test set:** the **1,162 test images**. Exclude the 7 subject-training images from correlation unless a sensitivity table is added and labeled as such.

---

## 2. Availability (no download in this phase)

| Item | Status now | After approval |
|------|------------|----------------|
| In this repo | **Not present.** Workspace has `koniq10k/` and empty `live_vqc/` only. No `livec/` folder yet. | Create `tools/quality_validation/workspace/datasets/livec/` (images + metadata). Gitignore media and `.mat`. |
| Official host | [LIVE Challenge](https://live.ece.utexas.edu/research/ChallengeDB/index.html) and [CU Boulder LIVE page](https://www.colorado.edu/lab/live/live-wild-image-quality-challenge-database) | A human fills the LIVE **access request form**. The lab emails a download link. |
| Typical package | `Images/` JPEGs, `Data/*.mat` (`AllImages_release.mat`, `AllMOS_release.mat`, std files), README copyright | Inspect MAT keys first (`research_preview.py --inspect-only` pattern). Do not guess variable names. |
| Mirrors (Kaggle, etc.) | Exist | Prefer the official LIVE release so MOS order matches filenames. Do not scrape unofficial copies. |

This repository must **not** fetch the archive. The operator downloads it locally after agreeing to LIVE terms.

---

## 3. Licensing (dataset)

LIVE Challenge ships a UT Austin copyright notice (2015). Typical terms:

- Use, copy, modify, and distribute the **database** (images, results, source files) **without royalty**, for **any purpose**, provided the **full copyright notice** appears on copies and LIVE / UT Austin is **acknowledged in publications**.
- Database is **AS IS**, no warranty, no maintenance duty.

This is **more permissive than pyiqa** (PolyForm Noncommercial / CC BY-NC-SA weights). It is a **dataset** license, not a license to ship MUSIQ weights.

Cite if used:

- D. Ghadiyaram and A.C. Bovik, "Massive Online Crowdsourced Study of Subjective and Objective Picture Quality," IEEE TIP.
- D. Ghadiyaram and A.C. Bovik, "LIVE In the Wild Image Quality Challenge Database."

Record the exact README text into `livec/metadata/LICENSE_NOTES.md` after download. Do not paraphrase over the notice.

---

## 4. MOS scale

| Item | Plan assumption | Confirm after inspect |
|------|-----------------|------------------------|
| Scale | Continuous **MOS**, literature and pyiqa `livec` config: **about 0–100**, higher better | Print min/max/mean of `AllMOS_release.mat` before scoring |
| Not | KonIQ ACR 1–5; not ACCESS 1–5 integers | |
| Per-image extras | MOS std / variance usually provided | Keep as sidecar, not as ACCESS criteria |
| Mapping | Store **raw MOS** always. Optional linear 0–100 → 1–5 is only for display tables, never as if raters used ACCESS rubrics | Reuse `scale_mapping.map_mos_to_1_5` only as a documented sidecar column |

Phase 2 lesson: MUSIQ PaQ-2-PiQ raw scores on KonIQ were **50.23–79.03** (declared `~0, ~100`). LIVEC MOS is also ~0–100, so **raw vs raw** Pearson/Spearman is the primary comparison. MAE/RMSE vs LIVEC MOS is only allowed if the observed MUSIQ range is also MOS-like on 0–100 **and** no eval-set affine fit is used. If ranges still disagree (for example MUSIQ clustered 50–80 while MOS spans 20–90), report distributions and skip MAE until a **frozen** calibration from a **non-LIVEC** set is applied.

---

## 5. Training overlap with MUSIQ PaQ-2-PiQ

| Model / data | Relation to LIVEC |
|--------------|-------------------|
| MUSIQ paper (ICCV 2021) | Separate checkpoints: PaQ-2-PiQ, SPAQ, KonIQ-10k, AVA. PaQ-2-PiQ training used that dataset’s **train split** (about 30k full images + 90k patches). LIVEC is **not** listed as MUSIQ training data. |
| PaQ-2-PiQ / FLIVE | New ~40k authentic-photo dataset. Authors **transfer-tested** on CLIVE and KonIQ **without fine-tuning**. That is the literature pattern this phase copies. |
| pyiqa `musiq-paq2piq` | Converted PaQ-2-PiQ weights (`musiq_paq2piq_ckpt-364c0c84.pth`). Same training origin. |
| pyiqa default `musiq` | **KonIQ-trained. Do not use** for Phase 3 (and do not reuse it to “confirm” Phase 2). |
| Phase 2 140 KonIQ files | Not in LIVEC. Do not mix into the LIVEC correlation table. |

**Independence claim (what we can say):** LIVEC is a standard **cross-dataset** holdout for PaQ-2-PiQ-trained models. It is not KonIQ and not the FLIVE train list as published.

**Independence claim (what we cannot prove without IDs):** both FLIVE and LIVEC are in-the-wild photos. Residual near-duplicate content is unlikely in the papers but is **not** a cryptographic disjointness proof. After LIVEC filenames are on disk, optionally hash them and compare against KonIQ 140 SHA-256 values already in Phase 2 CSVs (expect zero matches). Do not attempt a FLIVE join unless that dataset is later obtained under its own terms.

**Do not** fine-tune or calibrate MUSIQ on LIVEC.

---

## 6. Reproducible evaluation protocol (after approval)

Keep Phase 2 artifacts read-only.

### 6.1 Layout (to create later)

```
tools/quality_validation/workspace/datasets/livec/
  images/                 # 1,162 test JPEGs only
  metadata/               # MAT/CSV MOS, inspect notes, LICENSE_NOTES.md
  output/run_livec_001/   # MUSIQ raw predictions + metrics (new)
```

Do not write into `koniq10k/metadata/output/run_001/` or `run_002/output/`.

### 6.2 Script (later, not now)

New standalone script, for example `tools/quality_validation/livec_musiq_benchmark.py`, modeled on `musiq_paq2piq_benchmark.py`:

- Isolated research venv only (`.venv_musiq_research` or a TF venv if using official Google weights).
- Load MOS after inspect-then-map (same discipline as LIVE-VQC: no hardcoded MAT keys).
- Score each of 1,162 test images once.
- Save **raw** MUSIQ scores before any 1–5 column.
- Optional EfficientNet-B0 overall via existing research `evaluate_production_quality` (read-only production modules). That comparison is secondary. If run, it is still overall-vs-MOS, not criterion validation.
- Do not call PROBE, WaveRep, Gemini, or the database.

### 6.3 Metrics (locked before scoring)

Compute on paired rows with finite MOS and finite raw prediction.

1. **Pearson r, Spearman r** of **raw MUSIQ vs raw LIVEC MOS** (primary).
2. Same two correlations for EfficientNet overall vs MOS if that sidecar is run.
3. **Inference time:** mean ms/image, total seconds, device (CPU vs GPU), n_ok, n_failed.
4. **Distributions:** min, max, mean, stdev for MOS, MUSIQ raw, and EfficientNet overall.
5. **MAE / RMSE:**
   - Raw MUSIQ vs LIVEC MOS: only if both are documented as comparable ~0–100 **and** no fit on LIVEC. Otherwise `not comparable`.
   - After **frozen** calibration to ACCESS 1–5: MAE/RMSE only against MOS that has been linearly mapped 0–100 → 1–5 **with a fixed formula** (not fitted on LIVEC). Label that table `mapped_display_only`. It is not ACCESS rater GT.
6. Scatter diagnostics: MOS vs raw MUSIQ (report or saved PNG under the output folder). No production UI.

**No logistic/linear coefficients may be estimated on the 1,162 LIVEC test images.**

### 6.4 Success interpretation (not a ship decision)

| Outcome | Meaning |
|---------|---------|
| Spearman on LIVEC still high (literature PaQ-2-PiQ transfer on CLIVE was about 0.74–0.78 SRCC for their models; MUSIQ PaQ-2-PiQ paper reports strong in-domain PaQ-2-PiQ, not a LIVEC number we should invent) | Independent support that overall NR-IQA beats EfficientNet overall on authentic photos |
| Spearman collapses vs Phase 2 | Phase 2 may have been KonIQ-specific; do not replace overall scoring |
| EfficientNet remains ~0.1 Spearman | Confirms overall head is the wrong instrument for MOS, not a reason to change the seven criteria |

Do not treat any LIVEC number as scientific validation of EfficientNet-B0 or of ACCESS badges.

### 6.5 Runtime sketch

Phase 2: 1.62 s/image CPU × 1,162 ≈ **31 minutes** plus model load, before any EfficientNet pass. Plan a single overnight CPU job or a later GPU research box. Do not block the production server.

---

## 7. Calibration to ACCESS 1–5 (separate from the LIVEC test)

Goal: a **frozen** map `f(raw_musiq) → {1..5}` for a future overall product field. The seven technical criteria stay on their current path.

### 7.1 Forbidden

- Fitting `f` on LIVEC (the independent test).
- Fitting `f` on the same 140 KonIQ images used to **choose** MUSIQ over EfficientNet if that map will then be reported as LIVEC MAE (selection leak into the error table). Pearson/Spearman on raw LIVEC scores stay valid either way.
- Using criterion labels, `_soft_score`, or the mean of seven badges as MOS.

### 7.2 Allowed calibration sources (pick one, document seed)

**Option A (preferred for a first freeze):** KonIQ images **disjoint** from Run 001 + Run 002 (not the 140 filenames). Use published MOS on 1–5. Draw a stratified calibration set (for example 200 images, new seed `20261107_calib`, empirical MOS quintiles). Fit once. Freeze coefficients in a JSON file under `tools/quality_validation/workspace/calibration/` (not production).

**Option B (ACCESS construct):** a new overall 1–5 human pack on ACCESS photos (protocol already in `HUMAN_VALIDATION_PROTOCOL.md`), **overall item only**, raters blinded to MOS and machine scores. Fit `f` there. This measures ACCESS overall, not LIVEC.

**Option C (theoretical, no fit):** monotone linear map from a **declared** MUSIQ range (for example 0–100) to 1–5: `1 + 4 * (raw/100)`, clipped. No coefficients estimated on any eval set. Weaker alignment, fully leak-free.

Do **not** use SPAQ MOS to fit `f` unless the production checkpoint remains PaQ-2-PiQ (SPAQ-trained MUSIQ is a different model).

### 7.3 Mapping family (fit only on the calibration split)

Fit in this order, calibration-set only, then freeze:

1. **Linear:** `y = a + b x` (ordinary least squares of MOS_1_5 on raw MUSIQ).
2. If residuals are clearly sigmoidal: **3-parameter logistic** (common IQA reporting). Record formula and coefficients.
3. Clip to [1, 5]. Do not integer-quantize until a product rule is approved. Phase 2 `_soft_score` must **not** be reused for MUSIQ.

Report calibration-set R² / MAE **and** LIVEC metrics on **raw** scores in separate sections. If a frozen `f` is applied to LIVEC, that MAE table is supplementary and must say `mapping_fitted_on=<calib_id>`.

### 7.4 What calibration does not do

It does not create Sharpness/Blur/Noise labels. It does not replace EfficientNet heads. It does not justify shipping pyiqa.

---

## 8. Production-legal implementation (without pyiqa)

Phase 2 used **pyiqa 0.1.16** (`PolyForm-Noncommercial-1.0.0`) and converted weights (typically CC BY-NC-SA). That path is **research-only**. It must not be imported by `access_backend`.

| Path | License (as documented 2026-11) | Use for ACCESS production? |
|------|----------------------------------|----------------------------|
| `pip install pyiqa` + `musiq-paq2piq` | Package PolyForm-NC; weights treated as noncommercial | **No** |
| Official code `google-research/musiq` | **Apache 2.0** | **Candidate**, after legal review |
| Official `paq2piq_ckpt.npz` (Google Research GCS / listed in musiq README) | Distributed with that Apache-licensed tree; confirm NOTICE at download time | **Candidate** if the npz terms match the repo |
| TF Hub / Kaggle `google/musiq` AVA variant | Apache 2.0, but **AVA aesthetics 1–10**, wrong task | **No** for technical overall quality |
| Own PyTorch reimplementation + official npz converted in-house | Code we write can be project-licensed; conversion must start from official Apache weights, not from pyiqa `.pth` | **Candidate** |
| Fine-tune on ACCESS data | Needs labeled overall MOS we do not have yet | Not this phase |

**Recommended production track (planning only):**

1. Keep research scoring on the existing isolated venv / pyiqa **until** LIVEC results are reviewed.
2. If LIVEC supports the overall-quality claim, prototype inference with **TensorFlow + official `paq2piq_ckpt.npz`** in a **second** research venv (not `access_backend`). Compare a few dozen images against pyiqa raw scores (same files, not LIVEC if those must stay untouched for the frozen test; use KonIQ 140 or calibration images for engine-agreement).
3. Only after numeric agreement and legal sign-off, add a **sidecar** FastAPI overall field (new key, for example `perceptual_overall_raw`) that does not overwrite the seven criteria.
4. CPU cost (~1.6 s/image) is too high for synchronous mobile upload unless we queue, downsample policy, or GPU. That is an engineering gate, not a science gate.

There is **no** drop-in MIT/Apache PyPI package that is the pyiqa MUSIQ port. The legally cleaner route is Google’s TF code and npz, or an in-house port of **those** weights.

---

## 9. Keep the seven technical criteria separate

| Channel | Instrument | Ground truth | Phase 3 action |
|---------|------------|--------------|----------------|
| Overall perceptual quality | MUSIQ (research); later official Apache weights | Published MOS (KonIQ, LIVEC) or ACCESS overall ratings | Evaluate overall only |
| Sharpness, Blur, Noise, Brightness, Contrast, Blocking, Ringing | Current EfficientNet-B0 heads / OpenCV fallback | ACCESS criterion raters only (`HUMAN_VALIDATION_PROTOCOL.md`) | **Unchanged** |

Do not:

- Average MUSIQ into criterion badges.
- Retrain EfficientNet on LIVEC MOS.
- Report LIVEC MOS as Blur or Noise accuracy.
- Hide OpenCV fallback behavior; production quality path stays as-is.

If overall MUSIQ ships later, UI copy must say it is overall perceptual quality, not a substitute for the seven checks.

---

## 10. Work sequence (approval gates)

1. **This document reviewed.** Stop. (Current step.)
2. Operator requests LIVEC from LIVE, stores it under `workspace/datasets/livec/`, records license text. No scoring yet.
3. Inspect-then-map MOS MAT keys. Confirm 1,162 test files, MOS min/max, exclude 7 subject-training images.
4. Hash-overlap check vs KonIQ 140.
5. Run raw MUSIQ (research venv) → `output/run_livec_001/`. Pearson/Spearman/time/distributions. No LIVEC calibration.
6. Optional: EfficientNet overall sidecar on the same IDs.
7. Separate calibration Option A or C on non-LIVEC data; freeze JSON; optional supplementary MAE table.
8. Legal/engineering note on Apache TF vs pyiqa. Still no production merge until a later phase.

---

## 11. Out of scope

- Downloading LIVEC or Google checkpoints in this step
- Changing production code, API responses, or the database
- Flutter / React Admin
- PROBE / WaveRep / Gemini
- Replacing the seven criteria
- Claiming scientific validation
- Using SPAQ or KonIQ-trained MUSIQ as the Phase 3 model
- Fitting any map on the LIVEC test set

---

## 12. Stop

Independent test dataset: **LIVE Challenge, 1,162 authentically distorted photos, MOS ~0–100, request-based download, attribution required.**

Overlap: **PaQ-2-PiQ/FLIVE training, not LIVEC.** Cross-dataset by design. Not a duplicate of the 140 KonIQ images.

Calibration: **fit only on a disjoint KonIQ or ACCESS overall pack, or use a coefficient-free 0–100 → 1–5 formula.** Never on LIVEC.

Production: **do not ship pyiqa.** Candidate path is official Google MUSIQ **Apache 2.0** TensorFlow + `paq2piq_ckpt.npz`, as a sidecar overall score, after LIVEC review and legal sign-off.

Await approval before any download or new benchmark run.
