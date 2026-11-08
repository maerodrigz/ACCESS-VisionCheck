# ACCESS VisionCheck — Media Quality Accuracy Improvement Plan (Phase 4)

**Status:** research and planning only. No production code, weights, API, database, Flutter, or React Admin changes in this step.

This is **not** a scientific validation of EfficientNet-B0, MUSIQ, OpenCV heuristics, or the seven ACCESS technical criteria. KonIQ MOS, LIVEC MOS, and SPAQ MOS are overall (or attribute) labels from other studies. They are not ACCESS club-documentation badges.

Companion evidence:

- Production contract: `SCORING_CONTRACT.md`
- EfficientNet diagnostic: `MODEL_VALIDITY_DIAGNOSTIC.md`
- KonIQ MUSIQ experiment: `MUSIQ_EXPERIMENTAL_BENCHMARK.md` (Pearson 0.820, Spearman 0.821, n=140)
- Independent LIVEC holdout: `LIVE_CHALLENGE_VALIDATION_REPORT.md` (Pearson 0.801, Spearman 0.767, n=1,162, 0 failures, no LIVEC calibration)
- Human criterion protocol: `HUMAN_VALIDATION_PROTOCOL.md`, `HUMAN_RATING_RUBRIC.md`

---

## 0. Decision this plan is allowed to support

| Allowed now | Not allowed by this document |
|-------------|------------------------------|
| Separate **Overall Perceptual Quality** (OPQ) from the seven technical badges | Treat LIVEC/KonIQ MOS as Sharpness, Blur, Noise, Brightness, Contrast, Blocking, or Ringing |
| Plan an Apache-licensed MUSIQ inference path | Ship `pyiqa` or Hugging Face `musiq_paq2piq_ckpt-364c0c84.pth` |
| Fit a 1–5 map on **disjoint** development data | Fit or report product MAE from a map trained on LIVEC |
| Design criterion-specific evaluation | Retrain EfficientNet, change `_soft_score`, or alter API responses in this phase |
| Feature-flagged sidecar, rollback, regression tests | Mix OPQ into the mean of seven, or into PROBE / WaveRep / Gemini |

Preserve as-is: AI authenticity (PROBE + provenance), Gemini narrative merge, integrity review gates, XP eligibility rules, OpenCV fallback logging.

---

## 1. Current overall score and seven-criterion implementation

Sources: `access_backend/app/services/media_evaluator.py`, `efficientnet_b0_scorer.py`, `opencv_quality.py`, `train_efficientnet_heads.py`.

### 1.1 Overall (production)

```
overall_score = round(mean(criterion.score for criterion in criteria), 2)
```

- Photo: mean of **7 integers**.
- Video: mean of **9 integers** (seven photo heads plus Flickering and Motion Stability).
- `legacy.overall_score` stores `overall / 5` (0–1). XP preview uses `round(legacy.overall_score * 100)`.
- Recommendation bands: Accepted if overall ≥ 3.6, Accepted with Suggestions if ≥ 2.4, else For Officer Review.
- Quality level bands: Excellent ≥ 4.5, Good ≥ 3.5, Fair ≥ 2.5, else Needs Improvement.

This mean is **not** an independent perceptual MOS. Human protocol already treats `overall_visual_quality` as a separate impression.

### 1.2 Engine order

1. EfficientNet-B0 seven-head sigmoid (0–1), ImageNet backbone frozen at train time, 224×224, EXIF transpose.
2. If unavailable or failed: OpenCV heuristics, `analysis.opencv_fallback = true`.
3. If both fail: evaluation failed / unavailable (no placeholder 0.5).

Video: FFmpeg samples frames; the **same still heads** are averaged; Flickering and Motion Stability are frame-to-frame heuristics. There is no video-native quality network.

Authenticity is a **separate** call (`detect_ai_generated` / frames). Quality must not gate or replace it.

### 1.3 Criterion math (displayed 1–5, higher is better)

| Name | Head / heuristic (0–1) | Before `_soft_score` | Notes |
|------|------------------------|----------------------|--------|
| Sharpness | `sharpness` | as-is | OpenCV: Laplacian variance / 420 |
| Blur | `blur` | `1 - blur` | OpenCV blur is `1 - sharpness` (collinear) |
| Noise | `noise` | `1 - min(noise, 0.85)` | Stored DB `noise_score` is inverted again (`1 - Noise/5`) |
| Brightness | `brightness` | `1 - abs(value - 0.48) * 2.2` (clipped) | Triangular “good exposure,” peak 0.48, **not** the raw head |
| Contrast | `contrast` | `min(contrast, 1.0)` | OpenCV: gray std / 72 |
| Blocking Artifacts | `blocking_artifacts` | `1 - blocking` | OpenCV: fraction of 8×8 patches with variance &lt; 8 (flatness proxy, not JPEG blocking) |
| Ringing Artifacts | `ringing_artifacts` | `1 - ringing` | OpenCV: Canny-aligned sign flips of row differences |

Video extras:

- **Flickering:** mean absolute brightness delta across sampled frames, then `1 - flicker * 3`.
- **Motion Stability:** mean absolute sharpness delta, then `1 - blur_delta * 2.5`.
- Fewer than 2 frames: both default to integer **4** (not measured).

### 1.4 Training of the current heads (why overall MOS disagreement was expected)

`SyntheticIQADataset` paints 224×224 solid-color canvases with rectangles, then applies scripted Gaussian blur, noise, brightness/contrast, JPEG re-encode, and unsharp “ringing.” Labels are degradation knobs plus OpenCV statistics, **not** human MOS. Default: 640 samples, 4 epochs, frozen features, MSE on the linear head.

Construct mismatch:

- KonIQ / LIVEC MOS: crowdsourced **overall** quality.
- ACCESS overall: mean of seven quantized technical integers from synthetic heads.

Phase 2 EfficientNet vs KonIQ MOS: Pearson **0.142**, Spearman **0.109**. That is evidence against using the mean-of-seven as perceptual overall. It is **not** evidence that each technical head is wrong on its own construct.

### 1.5 What must stay separate

| Channel | Current instrument | Ground truth that would count |
|---------|--------------------|--------------------------------|
| Overall perceptual quality | Mean of 7/9 integers (inadequate) | Published overall MOS **or** ACCESS `overall_visual_quality` |
| Seven technical badges | EfficientNet heads + `_soft_score` (OpenCV fallback) | ACCESS criterion raters; published **attribute** scores only with a documented mapping |
| AI authenticity | PROBE + provenance policy | Out of scope for this plan |
| Gemini | Client narrative merged after quality | Out of scope |

---

## 2. Design: Overall Perceptual Quality (OPQ), not averaged into the seven

### 2.1 Product construct

**OPQ:** one scalar for “how good does this photograph look overall,” aligned with NR-IQA MOS (higher better).

**Technical badges:** seven (photo) or nine (video) coaching dimensions. Members keep seeing them. OPQ must **not** be averaged with them, and must **not** overwrite `criteria[].score`.

Human rubric already says overall is independent of the mean of seven. Production should eventually match that.

### 2.2 Recommended future payload shape (do **not** implement in this phase)

Keep today’s `overall_score` as the **mean of technical integers** until a later, explicit API/UI change. Add a sidecar, for example:

| Field | Role |
|-------|------|
| `criteria` | Unchanged 1–5 badges |
| `overall_score` | Temporary: still mean of badges (backward compatible) |
| `perceptual_overall_raw` | Frozen MUSIQ raw (PaQ-2-PiQ-like ~0–100) |
| `perceptual_overall_1_5` | Calibrated continuous 1–5 (integer only after a product rule) |
| `perceptual_overall_engine` | e.g. `musiq-paq2piq-official` |
| `perceptual_overall_status` | `ok` / `skipped` / `failed` |

XP, recommendation, and `legacy.overall_score` stay on the technical mean until product explicitly switches. A silent swap would change XP without a science or product review.

Video: OPQ on a **mid or median sampled frame** is a stopgap, not a validated video MOS. LIVE-VQC / KoNViD remain a later track. Do not claim LIVEC photo results cover video.

### 2.3 Why MUSIQ PaQ-2-PiQ for OPQ

| Evidence | Meaning | Does not mean |
|----------|---------|----------------|
| KonIQ 140, PaQ-2-PiQ-trained MUSIQ vs MOS | Pearson 0.820, Spearman 0.821 | ACCESS Sharpness/Blur/… accuracy |
| LIVEC 1,162, same checkpoint, no fit | Pearson 0.801, Spearman 0.767, 0 failures | Production license or 1–5 calibration |
| EfficientNet overall vs KonIQ MOS | ~0.14 / ~0.11 | The seven heads cannot be improved |

Checkpoint used in research: pyiqa `musiq-paq2piq`, SHA-256 `364c0c840a24dcdb48e963b1f2084e56e39785cf5f49f01c0a4d0e06ac9b52f7`. Trained on PaQ-2-PiQ / FLIVE, not KonIQ, not LIVEC. Default pyiqa `musiq` (KonIQ-trained) remains **forbidden** for KonIQ reporting.

MUSIQ outputs **one** overall score. It has no Sharpness/Blur/Noise heads.

### 2.4 Runtime sketch

LIVEC CPU: **~0.66 s/image** after warmup (Phase 2 first-run was ~1.62 s). Too slow for a fully synchronous mobile upload on CPU-only hosts unless:

- background queue (same pattern as deferred authenticity), or
- GPU worker, or
- downsample policy documented and re-validated.

Do not block `evaluate_bytes` authenticity or Gemini on OPQ.

---

## 3. Legally usable production implementation

Phase 2/3 used **pyiqa 0.1.16** (`PolyForm-Noncommercial-1.0.0`; weights commonly treated as CC BY-NC-SA). That path is **research-only**. Do not import pyiqa into `access_backend`. Do not copy the Hugging Face `.pth` into `ml/`.

### 3.1 Candidate vs forbidden engines

| Path | License (as of 2026-11 public docs) | Production? |
|------|--------------------------------------|-------------|
| `pip install pyiqa` + `musiq-paq2piq` | PolyForm-NC package; converted weights noncommercial | **No** |
| Official code `google-research/google-research/musiq` | **Apache 2.0** (source files; repo LICENSE) | **Candidate** after legal review |
| Official `paq2piq_ckpt.npz` (GCS listed in MUSIQ README) | Distributed with that research tree; **confirm NOTICE at download** | **Candidate** if counsel agrees Apache covers the npz |
| `koniq_ckpt.npz` | Same tree, **KonIQ-trained** | **No** for KonIQ-based selection/calibration reporting |
| `spaq_ckpt.npz` | Same tree, SPAQ-trained | Not the Phase 2/3 model; do not mix into LIVEC claims |
| `ava_ckpt.npz` / TF Hub / Kaggle `google/musiq` | Apache 2.0, **AVA aesthetics 1–10** | **No** for technical OPQ |
| In-house PyTorch port loaded from **official npz** (not pyiqa pth) | New code can be project-licensed; weights still Apache/NOTICE | **Candidate** (fits existing Torch stack) |
| Fine-tune on ACCESS overall ratings | Needs labels we do not have | Later, not this plan’s execution |

Google Research README also states **datasets** in that repo are CC BY 4.0. That is not a substitute for checkpoint NOTICE review.

### 3.2 Recommended production track (still not implemented)

1. **Legal review:** Apache 2.0 use/redistribution of `paq2piq_ckpt.npz`, NOTICE/attribution in the binary, TensorFlow vs in-house port.
2. **Research venv #2** (not `access_backend`, not `.venv_musiq_research`): TensorFlow official `run_predict_image` **or** a documented npz→PyTorch converter written in-house.
3. **Engine agreement (not a MOS test):** score a fixed pack that is **not** LIVEC (KonIQ 140 is acceptable here as an *engine* check, because the scientific claim already used it). Require near-identity of raw scores vs pyiqa (Pearson ≈ 1, MAE small on the same 0–100-like scale). If they disagree, **do not** treat LIVEC pyiqa numbers as the production engine’s numbers.
4. **Only after agreement:** sidecar inference behind a feature flag. Weights live under a NOTICE file. No pyiqa import.
5. CPU/GPU/queue is an engineering gate, not a science gate.

There is no drop-in MIT/Apache PyPI package that *is* the pyiqa MUSIQ port. The clean route is Google’s TF + npz, or a port of **those** weights.

---

## 4. 1–5 calibration (disjoint development data; never LIVEC)

Goal: freeze `f(raw_musiq) → [1, 5]` for OPQ only. Seven badges stay on their own mapping.

### 4.1 Forbidden

- Fitting `f` on LIVEC (frozen independent test).
- Fitting `f` on the same 140 KonIQ files used to **choose** MUSIQ if that map’s MAE is then quoted as LIVEC “accuracy.”
- Using criterion integers, `_soft_score`, or mean-of-seven as MOS.
- Reusing production `_soft_score` (`metric * 0.5 + 0.42`) on MUSIQ raw.
- Fitting on FLIVE / PaQ-2-PiQ training IDs (in-domain leak).
- Using SPAQ MOS to fit a **PaQ-2-PiQ** checkpoint without stating the domain shift.

### 4.2 Allowed sources (pick one, freeze `calib_id` + seed)

**A. Disjoint KonIQ (first freeze, preferred if ACCESS ratings are not ready).**  
KonIQ images **not** in Run 001/002 filenames. Published MOS already on 1–5 ACR. Stratify by MOS quintiles, e.g. n=200, new seed `20261107_calib`. Fit once. Save coefficients under `tools/quality_validation/workspace/calibration/` (gitignored media, committed JSON of coefficients only if they contain no image bytes).

**B. ACCESS overall pack.**  
`HUMAN_VALIDATION_PROTOCOL.md`, item `overall_visual_quality` only, ≥3 blinded raters, ACCESS/real documentation photos. Best construct match. Smaller n; report IRR before fitting.

**C. Coefficient-free.**  
Declare a raw range (e.g. 0–100) and use `1 + 4 * (raw/100)`, clipped. No data fit. Weakest alignment, fully leak-free. Useful as a fallback if A/B are delayed.

Do not use LIVEC even as a “check MAE after fit” **in the same table as model selection** without labeling `mapping_fitted_on=<calib_id>` and keeping raw Pearson/Spearman as the primary LIVEC result (already published).

### 4.3 Mapping family (calibration split only)

1. Linear OLS: `y = a + b x` of MOS_1_5 on raw MUSIQ.
2. If residuals are sigmoidal: 3-parameter logistic (standard IQA reporting). Record formula.
3. Clip to [1, 5]. Keep **continuous** until product decides integer badges for OPQ.
4. Optional monotonic PCHIP later; not needed for v1.

Report:

- Calibration-set R² / MAE / residual plots (development).
- LIVEC **raw** Pearson/Spearman (already frozen).
- If `f` is applied to LIVEC: supplementary MAE only, with `mapping_fitted_on`.

### 4.4 Scale facts that calibration must absorb

| Series | Observed span | Implication |
|--------|---------------|-------------|
| LIVEC MOS | 3.42–92.43, mean 55.40 | Humans use nearly 0–100 |
| MUSIQ raw (LIVEC) | 41.04–79.38, mean 68.04 | Compressed high; linear 0–100→1–5 will sit high |
| KonIQ MOS (140) | ~1.6–4.0 on 1–5 | Different numeric family than MUSIQ raw |

A linear map fitted on disjoint KonIQ 1–5 is more defensible than pretending MUSIQ raw is already 0–100 MOS.

### 4.5 Split discipline (no leakage)

| Split | Use |
|-------|-----|
| KonIQ 140 (Run 001+002) | Model **selection** already spent |
| LIVEC 1,162 test | Independent **confirmation** of raw rank correlation; frozen |
| New KonIQ calib 200 (disjoint) **or** ACCESS overall pack | Fit `f` once |
| Future ACCESS overall test pack | After freeze, never used to retune `f` |

---

## 5. Seven technical criteria: datasets and methods

MUSIQ does **not** validate these. Each row needs its own labels and its own metric. Prefer **authentic** smartphone/documentation photos over synthetic LIVE/TID distortions when the product is club photography. Synthetic sets remain useful for **codec-specific** Blocking/Ringing.

Direction in the product UI: **higher displayed 1–5 is always better** (quality of *low* blur, *low* noise, *few* blocks).

| Criterion | Current limitation | Candidate **objective / learned** methods (research) | Published labels (with mapping notes) | ACCESS labels |
|-----------|-------------------|------------------------------------------------------|----------------------------------------|---------------|
| **Sharpness** | Synthetic head; 224×224 erases micro-texture; collinear with Blur in OpenCV | Laplacian / Tenengrad **baselines**; CPBD; SPARISH; do **not** use MUSIQ | SPAQ **sharpness** 0–100 (high = sharp). CID2013 / BID are blur-centric | Rubric Sharpness |
| **Blur** | Train label is `1 - sharpness`; OpenCV identical inversion | CPBD, JNB, FISH; separate **defocus vs motion** if possible | LIVE Gaussian blur, BID, CID2013 (often blur amount; invert to quality) | Rubric Blur (streak / disk bokeh) |
| **Noise** | `min(noise, 0.85)` cap; Run 002 Noise–MOS was **negative** (overall MOS, not noise GT) | Immerkaer σ; high-frequency residual; wavelet MAD. Learned denoise-no-ref only with license review | SPAQ **noisiness** (high = more noise → invert for ACCESS). SIDD/DND are denoise pairs, **not** MOS | Rubric Noise |
| **Brightness** | Triangle around 0.48; head trained as mean luminance then remapped | Keep a **non-monotonic** exposure curve (under **and** over). Histogram clipping + midtone mass | SPAQ **brightness** (paper: low = poorly exposed; confirm overexposure coding before use) | Rubric Brightness (subject exposure) |
| **Contrast** | Run 002: 96/100 at integer 3 | RMS / Michelson **baselines**; SPAQ contrast regressor if license allows | SPAQ **contrast**; CSIQ/TID **contrast change** (synthetic) | Rubric Contrast (usable range, not harsh clip) |
| **Blocking** | OpenCV counts **flat** 8×8 patches (smooth sky looks “blocked”) | Classic NR-JPEG (Wang 2002 blockiness); 8×8 boundary gradient ratio; not flatness | LIVE JPEG, CSIQ JPEG, TID2013 JPEG, KADID JPEG. Authentic phones: weaker, need ACCESS/SPAQ visual check | Rubric Blocking (hunt flat regions at 100–200%) |
| **Ringing** | Sign-flip heuristic; train label is unsharp amount | Edge-halo energy (Marziliano-style); JPEG2000 NR metrics for codec ringing | LIVE JPEG2K, TID2013 JP2K (codec ringing ≠ phone unsharp) | Rubric Ringing (halos / ghost ridges) |

**SPAQ** (11,125 smartphone photos; attributes brightness, colorfulness, contrast, noisiness, sharpness, plus overall MOS) is the closest **public multi-attribute** set to ACCESS badges. Limitations:

- No Blocking, no Ringing, no ACCESS-style Blur vs Sharpness split (sharpness absorbs both).
- Dataset/code README historically **research/educational, not commercial products** without author permission. Use for **offline evaluation**, not for shipping SPAQ-trained weights, unless permission is obtained.
- Do not copy SPAQ overall MOS into ACCESS criterion columns.

**Do not use for criterion GT:** KonIQ MOS, LIVEC MOS, FLIVE MOS, AVA aesthetics.

**Video-only (Flickering, Motion Stability):** LIVE-VQC / KoNViD-1k / CVD2014 are **overall video MOS**, not flicker/shake labels. Keep heuristics until ACCESS video ratings exist. Defaulting to 4 when `n_frames < 2` is a measurement hole, not a quality claim.

### 5.1 Method selection rule

For each criterion, compare **at least two** instruments on the same labeled set:

1. Current production integer (and, separately, raw 0–1 head).
2. One classical NR metric with a published definition.
3. Optional learned attribute model **only** if license allows evaluation use.

Winner is the one with higher Spearman vs **that criterion’s** labels, plus a usable 1–5 histogram (not a single bin). Overall MOS Spearman is not a tie-break.

No retraining in this plan. If a later phase retrains heads, **do not** reuse `SyntheticIQADataset`.

---

## 6. `_soft_score`: integer 1 is unreachable

```
boosted = clip(metric * 0.5 + 0.42, 0, 1)
```

Bins: 5 if ≥ 0.80, 4 if ≥ 0.64, 3 if ≥ 0.46, 2 if ≥ 0.28, else 1.

| Input metric in [0, 1] | boosted | Integer |
|------------------------|---------|---------|
| 0.00 | 0.42 | **2** |
| 0.76 | 0.80 | 5 |
| need boosted &lt; 0.28 | metric &lt; −0.28 | **impossible** |

So **displayed 1 never occurs** from `_soft_score`. Run 002 confirmed 0/100 images at 1 on every criterion. Flicker/motion use the same helper.

This is a **scale-compression defect** if the product promises a true 1–5 rubric. It is **not** by itself proof that heads fail human criterion ratings: raw 0–1 tensors were not dumped in the diagnostic (untested hypothesis 1 in `MODEL_VALIDITY_DIAGNOSTIC.md`).

### 6.1 What to measure before changing it

Read-only dump on frozen Run 002 (and later ACCESS pack):

- raw 0–1 heads
- post-inversion / brightness triangle
- integer after `_soft_score`

Then Spearman of **raw** vs human criterion medians, vs Spearman of **integers**.

| If | Then |
|----|------|
| Raw tracks humans, integers do not | Recalibrate bins (candidate: drop +0.42 offset, or fit thresholds on a **criterion calib** set, never LIVEC) |
| Raw is already saturated / constant | Mapping will not save the head; need new features or new labels + later retrain |
| Humans never use 1 either | Product might keep a compressed scale, but copy should not say “1 = Poor” as if it is reachable |

**Do not** apply a new `_soft_score` in production in this phase. Changing it moves every badge and XP-adjacent overall mean.

**Do not** reuse this helper for MUSIQ OPQ.

---

## 7. Evaluation protocol per criterion

Global rules:

- Report **Spearman** (and Pearson) vs the **matching** label. MAE/RMSE only when both series share a 1–5 (or documented 0–100) scale **without** fitting on the test set.
- Do not quote `|error| ≤ 1` as accuracy.
- IRR (pairwise exact agreement, off-by-more-than-1, optional Krippendorff α) **before** comparing to machines.
- Engine used (`efficientnet-b0` vs `opencv`) must be recorded.
- Direction: all ACCESS displayed scores **higher = better**. Invert published “amount of defect” labels before correlation.
- Show histograms: min, max, mean, stdev, counts of 1–5. Flag near-constant heads (Contrast on Run 002).

| Criterion | Direction (display) | Expected machine spread (today) | Reference-label limitations |
|-----------|---------------------|---------------------------------|------------------------------|
| Sharpness | High = more subject micro-detail | Mostly 3–4 | SPAQ sharpness ≠ ACCESS (no blur split). KonIQ MOS invalid |
| Blur | High = little motion/defocus | Mostly 3–4; collinear with Sharpness | Synthetic LIVE blur ≠ handshake/bokeh. Do not copy Sharpness |
| Noise | High = clean | Mostly 4 | SPAQ noisiness inverted. SIDD has no MOS. Overall MOS invalid (Run 002 even had the wrong sign) |
| Brightness | High = subject well exposed (non-monotonic defect) | 4–5 only | Mean luminance ≠ good exposure. SPAQ brightness coding of *overexposure* must be verified |
| Contrast | High = usable tonal separation | Almost all 3 | SPAQ contrast may reward punchiness ACCESS calls harsh. TID contrast is synthetic |
| Blocking | High = few 8×8 tiles | 3–4 | LIVE JPEG is harsher than phone recompress. OpenCV flatness is the wrong construct |
| Ringing | High = few halos | 3–4 | JP2K ringing ≠ unsharp halo. No SPAQ attribute |
| Flickering | High = stable exposure | Defaults to 4 if &lt;2 frames | No public ACCESS-matched flicker MOS |
| Motion Stability | High = little shake | Defaults to 4 if &lt;2 frames | Overall video MOS is not shake |
| **OPQ** | High = overall look | MUSIQ ~41–79 raw | KonIQ/LIVEC MOS OK for OPQ only. Never for the seven |

**ACCESS human pack (required for a criterion “accuracy” claim):** protocol already written. Pilot size in `VALIDATION_DATASET_PLAN.md`. Raters blinded to MOS and machine scores. Median of 3 raters as reference. Photos: flickering/motion = N/A.

**Published-attribute track (optional, parallel):** SPAQ attributes for Sharpness/Noise/Brightness/Contrast **evaluation only**, with invert/mapping documented, research-use license, disjoint from any future SPAQ-trained weights.

**Holdouts:** LIVEC stays OPQ-only. KonIQ 140 stays OPQ selection, not criterion GT.

---

## 8. Phased integration, flags, rollback, regression

No flags exist in `access_backend` today. Propose **new env flags** in a later implementation PR, default **off**.

### Phase 4 (this document)

Plan only. Stop for review.

### Phase 4.1 — Official engine agreement (research)

- Isolated TF or npz→Torch venv.
- Score engine-agreement pack (KonIQ 140 or calib images), **not** LIVEC.
- Gate: raw-score agreement with pyiqa. If fail, production path is blocked even though LIVEC pyiqa looked strong.

### Phase 4.2 — Freeze `f` off LIVEC

- Option A or B (section 4).
- Write `calibration/opq_musiq_paq2piq_v1.json` (`a`, `b`, clip, `calib_id`, seed, n, date).
- Do not commit LIVEC predictions into that file.

### Phase 4.3 — Shadow sidecar (production code allowed only after explicit approval)

Suggested flags (names illustrative):

| Flag | Default | Behavior |
|------|---------|----------|
| `PERCEPTUAL_OVERALL_ENABLED` | false | Off: today’s payload only |
| `PERCEPTUAL_OVERALL_SHADOW` | true when enabled | Compute OPQ, log/store sidecar, **do not** change `overall_score`, XP, recommendation, criteria |
| `PERCEPTUAL_OVERALL_ENGINE` | `official_paq2piq` | Never `pyiqa` |
| `PERCEPTUAL_OVERALL_SYNC` | false | false: queue/worker; true: only if latency budget proven |

Rollback: set `PERCEPTUAL_OVERALL_ENABLED=false`. No schema drop required if sidecar is JSON-null / omitted.

**Do not** change Flutter/React in 4.3. Admins/members still see mean-of-seven as overall.

### Phase 4.4 — Criterion instruments (separate flag family)

- Dump raw 0–1 vs `_soft_score` (read-only).
- ACCESS (and optional SPAQ) criterion evaluation.
- Replace OpenCV blocking flatness **only** after a labeled comparison.
- `_soft_score` change behind `QUALITY_SOFT_SCORE_VERSION=v1|v2`, default v1.

Never couple criterion flags to OPQ flags.

### Phase 4.5 — Productization (out of this plan’s execution)

- UI copy: “Overall perceptual quality” vs “Technical checks.”
- API additive fields first; deprecate mean-as-overall later.
- XP/recommendation policy decision (technical mean vs OPQ vs both).

### Regression tests (must stay green whenever code is later touched)

- Existing `access_backend/tests/test_media_quality_eval_correctness.py` (engine order, failed eval, Noise polarity).
- Route checklist in `.cursor/rules/access-visioncheck-self-anneal.mdc` (`/api/health`, admin stats). Authenticity payload keys unchanged.
- Frozen research: do not rewrite Run 001/002 or `run_livec_001` numbers.
- New tests (when implementing): flag off ⇒ byte-identical quality payload keys; flag shadow ⇒ extra keys only; authenticity `verdict` / Gemini merge still applied.

### What never rides along

- PROBE / WaveRep thresholds
- Provenance / Media Integrity review
- Gemini explanation/tips merge (`merge_client_gemini`)
- Practice video duration / FFmpeg sampling policy (except documenting that OPQ uses sampled frames)

---

## 9. Authenticity and Gemini (preserve)

Quality improvement is orthogonal:

- `evaluate_authenticity_bytes` / `detect_ai_generated*` stay the integrity path.
- Deferred authenticity preview and review gates stay.
- `merge_client_gemini` still keeps server scores authoritative and merges narrative.
- Do not feed MUSIQ into AI-generation probability.
- Do not hide quality when authenticity is deferred, beyond existing policy.

---

## 10. Risks and non-claims

1. pyiqa LIVEC numbers **do not** transfer to production until official-npz agreement is shown.
2. MUSIQ compression (raw ~41–79 vs MOS ~3–92) means even a good rank correlation can look “too high” after a naive 0–100 map.
3. Averaging OPQ with seven badges would **hide** criterion failures and double-count blur/noise into overall.
4. SPAQ is the best public attribute set and is still not ACCESS Blocking/Ringing/Blur, and may be noncommercial for product training.
5. Video OPQ is unvalidated if implemented as “MUSIQ on one frame.”
6. This plan does not claim EfficientNet-B0 or MUSIQ is scientifically validated for ACCESS documentation quality.

---

## 11. Recommended sequence after review (do not start until approved)

1. Legal: Apache `paq2piq_ckpt.npz` + NOTICE.
2. Engine-agreement research run (official vs pyiqa), non-LIVEC images.
3. Calibration Option A or B; freeze JSON; never LIVEC.
4. Optional: raw 0–1 dump vs `_soft_score` on Run 002 (read-only).
5. Optional: SPAQ attribute evaluation **and/or** ACCESS human criterion pilot.
6. Only then: shadow sidecar PR with flags default off.

Out of scope until a later approved phase: retraining, API/schema/Flutter/React changes, pyiqa in production, LIVEC-fitted maps.

---

## 12. Stop

LIVEC supports a **separate overall NR-IQA channel** (Pearson 0.801, Spearman 0.767, 1,162/1,162). It does not support replacing or averaging the seven technical criteria.

Production-legal OPQ: official MUSIQ **Apache** `paq2piq_ckpt.npz` (or in-house port of that file), after engine agreement and a 1–5 map fitted **off** LIVEC.

`_soft_score` makes criterion **1 unreachable**; measure raw heads before any bin change.

Await review before implementation.
