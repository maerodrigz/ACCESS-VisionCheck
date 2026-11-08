# Phase 12: Technical quality predictor benchmarking (research plan)

**Status:** 12A and 12B complete (2026-11-07). Research only. No downloads after the locked SPAQ-200 set. No training. No production changes.  
**Date:** 2026-11-07.  
**Depends on:** Phase 10 SPAQ-200 evaluation, Phase 11 scoring diagnostics.  
**Results:** `PHASE12_BENCHMARK_REPORT.md` and `workspace/datasets/spaq/output/phase12_run_001/`.  
**Next (not started):** `PHASE12_IMPLEMENTATION_DECISION_MATRIX.md`. Implementation is not authorized.

Production scoring, APIs, Flutter, XP, authenticity, Gemini, and MUSIQ production behavior stay frozen. This document does not authorize replacement of EfficientNet-B0.

---

## 0. Why this phase exists

Phase 10 (n=200 SPAQ, EfficientNet-B0 member badges vs human attributes):

- MOS vs overall badge Spearman **-0.07** (CI includes 0).
- Noise after invert **0.26** (weak, correct sign).
- Sharpness / Brightness / Contrast badges: CIs include 0.
- Blur / Blocking / Ringing: no SPAQ labels.

Phase 11:

- Compression is real (`_soft_score` cannot emit 1; Brightness 146/200 at 5).
- Monotone remapping cannot invent rank signal.
- Mean of seven quality `q` still fails MOS (**-0.02**). Mean of seven **raw** heads is only **0.17**.
- Held-out ridge on seven heads vs MOS **0.37 ± 0.14** (high fold variance, not deployable). Contrast linear “gain” was a **negative slope** (ranking flip).

Conclusion carried forward: **need better predictors per construct**, not a new ladder on the current heads. Overall MOS is a **separate** problem from the seven badges.

---

## 1. Intended constructs (ACCESS photo criteria)

Member-facing badges are 1–5 after `_soft_score`, **higher = better** for all seven names. Raw EfficientNet / OpenCV defect heads are **amount** (higher = more defect) and are inverted before the badge.

| Criterion | Image characteristic (physical / computational) | Perceptual quality judgment (what raters usually mean) | ACCESS badge direction | SPAQ / other GT |
|-----------|--------------------------------------------------|--------------------------------------------------------|------------------------|-----------------|
| **Sharpness** | High-frequency edge energy, resolved detail | “Looks crisp / in focus” | high = sharper | SPAQ Sharpness 0–100, **related proxy**. Paper: inversely related to blur; **no separate Blur scale**. |
| **Blur** | Defocus / motion smear (low pass) | “Looks smeared / out of focus” | high = less blur | **No SPAQ label.** LIVE blur / BID are overall DMOS of blurry images, not ACCESS Blur 1–5. |
| **Noise** | Sensor / compression grain | “Looks clean vs grainy” | high = cleaner | SPAQ Noisiness 0–100, **high = more noise**. Invert before compare. Closest match of the seven. |
| **Brightness** | Mean luminance / exposure | “Well exposed” (under and over both bad) | high = better exposure | SPAQ Brightness: low = poorly exposed; **over/under not split**. Related proxy, not the ACCESS triangle. |
| **Contrast** | Luminance spread | “Punchy vs washed out”; harsh clip is a different complaint | high = more/better contrast | SPAQ Contrast: low = reduced contrast; **no clip penalty**. Related proxy. Phase 11: ENET `q` ranks **opposite** SPAQ. |
| **Blocking** | 8×8 / codec grid | “Blocky JPEG” | high = fewer blocks | **No SPAQ label.** LIVE JPEG / TID JPEG are overall DMOS. |
| **Ringing** | Edge overshoot (sharpening, JPEG2000) | “Halos around edges” | high = fewer halos | **No SPAQ label.** LIVE JP2K / TID ringing-type distortions are overall DMOS. |
| **Overall (not a 7th badge)** | None (aggregate opinion) | SPAQ MOS / KonIQ MOS / LIVEC MOS | n/a | Must **not** be used as criterion GT. Separate channel. |

**Do not** treat Sharpness and Blur as two independent human validations on SPAQ. **Do not** report MOS as Sharpness accuracy.

---

## 2. Frozen evaluation protocol (before any run)

1. **Baseline (already measured):** production `evaluate_production_quality` on SPAQ-200. Do not re-tune `_soft_score` on these photos.
2. **SPAQ-200 is a locked test set** for a priori methods (classical formulas, production OpenCV, frozen official MUSIQ). Scoring it is allowed because **no thresholds are fitted on these 200**.
3. **Forbidden:** grid-search, percentile edges, ridge, isotonic, or head weights fitted on all 200 then reported as validation. Phase 11 already did CV for that class of maps.
4. If a **new** fitted map is proposed later: reuse Phase 11 folds (seed `20261107`, 5-fold, 8 per MOS quintile) or a new split declared **before** looking at test Spearman.
5. Report Spearman + Pearson, n, 95% bootstrap CI, unique values / ties, failure rate, CPU ms/image. No MAE as a primary accuracy claim across 0–100 vs 1–5.
6. **No SPAQ-trained checkpoints** (Fang MT-A, pyiqa `musiq` KonIQ checkpoint on KonIQ, SPAQ MUSIQ). Leakage.
7. Blur / Blocking / Ringing: distributions + Phase 8 knob sensitivity only, unless a new labeled set is approved.
8. Overall MOS: MUSIQ (and similar) only vs MOS. Never vs the seven attributes.

Local evidence already in-repo (do not invent new numbers here): Phase 10/11 SPAQ tables; Phase 5/6 official MUSIQ; Phase 2/3 pyiqa (research NC); Phase 8 controlled distortion.

---

## 3. Candidate matrix

Licensing is summarized for **this project’s use**, not legal advice. “Immediate” means code or weights already on disk or a small OpenCV pass. No >500 MB downloads in this phase.

### 3.1 Overall MOS (separate channel)

| ID | Method | Direction | Weights / deps | License | Cost | Evidence | Immediate? |
|----|--------|-----------|----------------|---------|------|----------|------------|
| O-base | Production overall = mean of 7 badges | high = better | ENET `efficientnet_b0_heads.pt` | project model; synthetic trainer | CPU ~2 s/img (Phase 10 wall ~6 min / 200) | SPAQ MOS Spearman **-0.07** (local) | Done |
| O-musiq-official | MUSIQ PaQ-2-PiQ TF Hub `google/musiq/paq2piq/1` | high = better overall | TF + TF Hub; venv `.venv_musiq_official` | TF Hub card Apache 2.0; **do not use pyiqa in production** | CPU, ~100M params, slower than ENET | **External:** PaQ-2-PiQ/FLIVE paper. **Local:** LIVEC MOS Spearman **0.770** (Phase 6 official); KonIQ engine check vs pyiqa Spearman **0.992** (failed 0.999 gate). **Not measured on SPAQ-200.** | **Yes, research venv only**, if approved. No production import. |
| O-musiq-pyiqa | pyiqa `musiq-paq2piq` | same | `.venv_musiq_research`, PolyForm-NC pth | **Noncommercial. Not production.** | CPU | Same scientific family; Phase 2 KonIQ / Phase 3 LIVEC. Phase 5: not 0.999-equivalent to official. | Research-only fallback |
| O-musiq-spaq | Any SPAQ-trained MUSIQ / MT-A | MOS | various | research | n/a | **Forbidden** (train/test leak vs SPAQ-200). | No |
| O-ridge7 | Ridge on 7 ENET heads → MOS | learned | none new | n/a | tiny | Phase 11 held-out **0.37 ± 0.14**. Ranking change, high variance, SPAQ-fit. | Not a new model; **do not deploy** |
| O-brisque / NIQE | Classical NR-IQA | high/low per impl | OpenCV contrib / sklearn | often BSD/Apache | cheap CPU | **External:** LIVE/TID overall MOS papers. Not seven criteria. | Optional later; overall only |

**Plan for overall:** if approved, score SPAQ-200 with **official TF Hub MUSIQ** already in `.venv_musiq_official`, compare to SPAQ MOS and to ENET overall. Do not fit a 1–5 map on SPAQ. Do not put pyiqa in `access_backend`.

### 3.2 Sharpness (related proxy on SPAQ)

| ID | Method | Direction | Deps | License | Cost | Evidence | Immediate? |
|----|--------|-----------|------|---------|------|----------|------------|
| S-enet | Production ENET sharpness head / badge | high = sharper | existing pt | project | CPU | SPAQ badge **0.09**, raw **0.12** (local) | Done |
| S-opencv | Production `opencv_quality` Laplacian/420 | high = sharper | OpenCV in backend | BSD | cheap | Phase 8: tracks Gaussian blur **severity** (construct), not SPAQ humans | **Yes** (no download) |
| S-classic | Research Laplacian var, Tenengrad (`classical_quality_metrics.py`) | high = more detail | OpenCV | BSD | cheap | Same; Tenengrad vs Laplacian duplication risk | **Yes** |
| S-musiq | MUSIQ overall | overall, not sharpness | TF Hub | Apache card | high | Must **not** be reported as Sharpness | No for this criterion |

### 3.3 Blur (no SPAQ human claim)

| ID | Method | Direction | Notes | Immediate? |
|----|--------|-----------|-------|------------|
| B-enet | ENET blur amount, badge = invert | high badge = less blur | Phase 8 sensitivity only; **duplicate axis with sharpness** in OpenCV (`blur = 1 - sharpness`) | Distro + Phase 8 only |
| B-classic | `1/(1+lap/420)` | high = more blur amount | Same axis as sharpness | Distro only |
| B-live / BID | Human overall on blurry photos | need LIVE/BID download | **Blocked** until dataset + protocol approved | No |

### 3.4 Noise (best SPAQ match)

| ID | Method | Direction | Deps | License | Cost | Evidence | Immediate? |
|----|--------|-----------|------|---------|------|----------|------------|
| N-enet | ENET noise amount; badge invert + 0.85 cap | high badge = cleaner | existing | project | CPU | SPAQ invert Spearman **0.26** badge / **0.29** raw (local) | Done |
| N-opencv | Residual std / 36 | high raw = more noise | OpenCV | BSD | cheap | Phase 8 AWGN sensitivity | **Yes** |
| N-immerkaer | Immerkaer Laplacian σ | high = more noise | already in research classical | BSD | cheap | Standard estimator; not SPAQ-fitted | **Yes** |
| N-cid | CID2013 graininess | human grain | Zenodo CID ~608 MB | research notice | n/a | **Need download approval** (>500 MB gate) | Not now |

### 3.5 Brightness / exposure (related proxy)

| ID | Method | Direction | Notes | Immediate? |
|----|--------|-----------|-------|------------|
| E-enet | ENET “brightness” then triangle at 0.48 | high q = mid luma | SPAQ **0.05** badge; triangle **changes ranking vs raw luma** | Done |
| E-mean | Mean luma / 255 | high = brighter, **not** “better” | Report both amount and triangle | **Yes** |
| E-clip | Shadow+highlight clip fraction | high = worse exposure | Complements mean; SPAQ does not label clip | **Yes** (classical already) |
| E-cid | CID2013 lightness | related | Download | Not now |

### 3.6 Contrast (related proxy; ENET sign problem)

| ID | Method | Direction | Notes | Immediate? |
|----|--------|-----------|-------|------------|
| C-enet | ENET contrast head | high = more contrast | SPAQ Spearman **negative** (~-0.15 `q`). Do not invert in production without a construct decision. | Done |
| C-rms | RMS / 72 (production OpenCV + classical) | high = more contrast | Phase 8: high-contrast family was **anti-monotonic** for some maps | **Yes** |
| C-michelson | (max-min)/(max+min) | high = more range | Classical toolkit | **Yes** |

### 3.7 Blocking (no SPAQ human claim)

| ID | Method | Notes | Immediate? |
|----|--------|-------|------------|
| K-enet | ENET blocking head | Phase 8 JPEG knob; saturated badges | Distro + Phase 8 |
| K-grid | 8×8 boundary energy ratio (classical + production OpenCV) | Standard NR blocking heuristic | Distro + Phase 8 |
| K-live-jpeg | LIVE/TID JPEG DMOS | overall, mixed blur+blocks | Need dataset |

### 3.8 Ringing (no SPAQ human claim)

| ID | Method | Notes | Immediate? |
|----|--------|-------|------------|
| R-enet | ENET ringing head | Phase 8 ringing family | Distro + Phase 8 |
| R-edgelap | Edge-Laplacian energy (classical) | Heuristic | Distro + Phase 8 |
| R-jp2k | LIVE JP2K DMOS | codec ringing ≠ phone unsharp | Need dataset |

### 3.9 Supervised / heavier IQA (not immediate)

| ID | Method | Issue |
|----|--------|--------|
| HyperIQA, DBCNN, TReS, LIQE | Strong **overall** NR-IQA | Mostly MOS, not seven ACCESS attributes; mixed licenses (often NC research weights) |
| Retrain ENET on SPAQ attributes | Would match SPAQ constructs | **Forbidden** on these 200; full SPAQ is 34.8 GB and research-only; leakage risk |
| Unique Sharpness vs Blur heads | Needs a blur-labeled set (BID/LIVE) | Dataset + new labels |

---

## 4. What can be benchmarked immediately (if approved)

No new large downloads. SPAQ-200 JPEGs already on disk. A priori methods only.

| Wave | Predictors | Labels | Claim allowed |
|------|------------|--------|----------------|
| **12A** | Production OpenCV seven-tuple (**scored** on SPAQ-200, 200/200) | SPAQ Sharpness, Noisiness (invert), Brightness, Contrast, MOS | Related-proxy Spearman vs ENET baseline |
| **12A** | Research classical: Laplacian, Tenengrad, Immerkaer, residual std, mean luma, clip frac, RMS, Michelson, 8×8 ratio, edge-Laplacian | Same four attributes + MOS as **not** criterion GT | Same; Blocking/Ringing/Blur: **distributions only** |
| **12B** | Official MUSIQ TF Hub, existing research venv | SPAQ MOS only | Overall baseline vs ENET overall; **not** seven criteria |
| **Not in 12A/B** | pyiqa, CID2013, LIVE, TID, BID, full SPAQ, ridge refit, any download >500 MB | — | Needs explicit approval |

Measured CPU (do not treat as a production SLA): combined 12A OpenCV+classical wall 3806.6 s (mean 19025 ms/img on these full-resolution JPEGs); combined 12B MUSIQ wall 439.4 s (200/200). Split-run walls were 5786.4 s (12A) and 425.3 s (12B). ENET Phase 10 was about 2 s/img. Classical/OpenCV here is **not** ≪ 0.1 s/img at native SPAQ resolution.

Failure handling: decode errors stay in the CSV; no 0.5 fill.

---

## 5. What needs more human-rated data

| Gap | Why SPAQ-200 is not enough | Candidate GT (not on disk) |
|-----|----------------------------|----------------------------|
| Blur vs Sharpness split | SPAQ one sharpness scale | BID; LIVE Gaussian-blur **overall** DMOS (partial) |
| Blocking | no attribute | LIVE JPEG / TID JPEG (overall) |
| Ringing | no attribute | LIVE JP2K / TID |
| Exposure over vs under | SPAQ brightness collapsed | CID2013 lightness; or ACCESS-native ratings |
| Harsh contrast / clip | SPAQ contrast ≠ clip | CID or lab ratings |
| ACCESS-native 1–5 | SPAQ is 0–100 lab attributes | Phase 10 30-photo pack still empty of ratings |

---

## 6. Licensing and compute constraints (blockers)

| Item | Constraint |
|------|------------|
| pyiqa 0.1.16 + converted MUSIQ pth | PolyForm-NC / noncommercial. Research venv only. **Never** `access_backend`. |
| Official MUSIQ TF Hub paq2piq | Usable in research venv today. Production sidecar still needs legal review (Phase 5 note: GCS npz NOTICE not shown). |
| SPAQ images/ratings | Research/educational author notice; do not ship SPAQ-trained weights. |
| CID2013 7z ~608 MB | Over the 500 MB download gate; Helsinki research notice. |
| LIVE / TID | Research agreement; not installed. |
| Disk | SPAQ-200 already extracted; full SPAQ archive still must not be downloaded. |
| GPU | Prior MUSIQ/ENET runs were CPU. |

---

## 7. Ranked shortlist (evidence / feasibility / risk)

1. **12A classical + production OpenCV on SPAQ-200** (a priori). Low risk, no download, answers whether Laplacian/Immerkaer beat ENET on the four SPAQ proxies.  
2. **12B official MUSIQ vs SPAQ MOS** in `.venv_musiq_official`. Medium compute, no production import. Tests the “separate overall channel” hypothesis from Phase 11 item 4.  
3. **Do not** invert Contrast in production based on Phase 11. Treat as a construct bug to investigate with 12A RMS vs ENET.  
4. **Do not** retrain ENET or fit ridge for deployment on these 200.  
5. **Defer** LIVE/TID/CID/BID until you approve specific datasets and the >500 MB rule.  
6. **Keep** Sharpness/Blur as one physical axis until a blur-labeled set exists; product copy should not claim independent human validation of both.

---

## 8. Recovery summary (chat interruption)

The previous Cursor session (transcript `49577af7-380c-48de-af06-f8a25bad16ad`) hit a usage/auth error while a second 12A job was still running. Inference was **not** lost.

| Run | Command | When (UTC) | Exit | Output |
|-----|---------|------------|------|--------|
| Combined 12A+12B (canonical metrics) | `python phase12_benchmark.py` | 08:35–09:46 | 0 | `phase12_per_image.csv`, `phase12_metrics.json`, `musiq_raw.csv`, `PHASE12_BENCHMARK_REPORT.md` |
| Split 12B | `.venv_musiq_official` `phase12_musiq_spaq.py` | ended 09:59 | 0 (n_ok=200) | `phase12b_musiq_scores.csv`, `phase12b_metrics.json` (no Spearman in JSON) |
| Split 12A | `python phase12_classical_benchmark.py` | 09:51–11:28 | 0 | `phase12a_scores.csv`, `phase12a_metrics.json` |

SPAQ-200 (200 JPEGs), Phase 10 `run_001`, and Phase 11 `phase11_run_001` were not rewritten. Inference was not rerun after recovery. Production stayed frozen.

Verification (2026-11-07, saved files only): combined report Spearman table matches `phase12_metrics.json` (24 rows). Toolkit and `phase12_run_001` copies of `PHASE12_BENCHMARK_REPORT.md` are identical. Tenengrad columns match between combined and split CSVs (max abs 0). MUSIQ scores match between `musiq_raw.csv` and `phase12b_musiq_scores.csv` (max abs ~5e-9). Unit tests: `python -m pytest tests/test_phase12_benchmark.py -q` → 2 passed.

### Combined vs split-run discrepancies (not inference failures)

1. **Wall time:** 12A 3806.6 s vs 5786.4 s; 12B 439.4 s vs 425.3 s. Same 200 files, different process timing.
2. **Noise badge sign in JSON only:** combined reports Spearman **-0.264** vs SPAQ noisiness amount. Split 12A inverts the human series first, so the same pair is **+0.264**. Magnitudes match. The combined report declaration is the one to cite.
3. **Clip-fraction correlation table:** combined includes `classic_exposure_clip_frac` vs Brightness (Spearman **-0.168**). Split 12A still **wrote** the column on every row of `phase12a_scores.csv` but omitted that pair from `PAIRS`, so `phase12a_metrics.json` has no clip correlation. Per-image values exist in both CSVs.
4. **Pairs only in combined JSON:** `enet_raw_mean_seven` and `musiq_raw` MOS correlations. Split 12B JSON has scores and runtime, not Spearman. MOS Spearman **0.828** lives in the combined report.
5. **Unlabeled ENET blocking/ringing:** combined unlabeled block lists ENET raw heads; split 12A unlabeled block lists ENET badges as well. No human correlation was computed for Blur, Blocking, or Ringing in either run.

Use the combined report as the scientific record. Split CSVs confirm the same machine series.

---

## 9. Stop

12A and 12B inference is complete. No further scoring of the 200 JPEGs. No production change. No Phase 13.

The decision matrix is in `PHASE12_IMPLEMENTATION_DECISION_MATRIX.md`. **Do not implement** any candidate until that matrix is approved.
