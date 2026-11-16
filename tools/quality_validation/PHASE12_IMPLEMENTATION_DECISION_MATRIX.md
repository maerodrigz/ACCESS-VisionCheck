# Phase 12 implementation decision matrix

**Status:** research decision record only. **Not an implementation approval.**  
**Date:** 2026-11-07.  
**Evidence source:** combined SPAQ-200 run `phase12_run_001` (`PHASE12_BENCHMARK_REPORT.md`, n=200, no thresholds fitted on this set).

Production scoring, APIs, Flutter, XP, authenticity, Gemini, and MUSIQ-in-app stay frozen until a later explicit approval.

Spearman values below are vs the SPAQ human field named in the row, 95% bootstrap CI in the combined report. "Beats ENET" uses the predeclared Phase 12 rule (declared sign and larger |r| than ENET raw and/or badge on the same human field).

---

## Evidence classes

| Class | Meaning | Allowed claim |
|-------|---------|----------------|
| **Human-rated (SPAQ proxy)** | Locked SPAQ-200 attribute or MOS vs an a priori machine series | Related-proxy rank agreement on this 200. Not ACCESS-native 1–5. Not a license to fit a new map on these photos. |
| **Technical only** | Distribution, Phase 8 knob, or duplicate physical axis. No SPAQ label | Construct / sensitivity only. **No** human-accuracy claim. |

Do not treat MOS as Sharpness (or any of the seven badges). Do not treat Sharpness and Blur as two independently validated human scales on SPAQ.

---

## Criterion matrix

### Sharpness (human-rated SPAQ proxy: `attr_sharpness_raw`, high = sharper)

| Candidate | Spearman | Evidence | vs ENET | Deploy now? | Before any deploy |
|-----------|----------|----------|---------|-------------|-------------------|
| ENET raw / badge (baseline) | 0.117 / 0.086 | Human proxy, CI includes 0 | n/a | Keep until replaced | N/A |
| OpenCV Laplacian/420 | 0.571 | Human proxy | Beats raw and badge | **No** | A priori 1–5 ladder (not fit on these 200); XP/copy review; confirm OpenCV path vs ENET fallback policy |
| Classical Laplacian var | 0.571 | Human proxy (same axis as OpenCV, unnormalized) | Beats raw and badge | **No** | Prefer production OpenCV scale if swapping this axis |
| Classical Tenengrad | 0.734 | Human proxy, strongest 12A sharpness | Beats raw and badge | **No** | Needs an a priori scale (raw energy, not 0–1); overlap with Laplacian; do not also claim independent Blur |

**Research preference if a later phase is approved:** Tenengrad or production OpenCV sharpness instead of the ENET sharpness head. Not both plus a separate Blur human claim.

### Noise (human-rated SPAQ proxy: `attr_noisiness_raw`, high = more noise)

| Candidate | Spearman | Evidence | vs ENET | Deploy now? | Before any deploy |
|-----------|----------|----------|---------|-------------|-------------------|
| ENET raw amount / badge cleanliness | 0.290 / −0.264 | Human proxy, weak, correct signs | n/a | Keep until replaced | Badge invert must stay documented |
| OpenCV residual std/36 | 0.600 | Human proxy | Beats raw and badge | **No** | Map amount → cleaner badge without fitting on SPAQ-200; same series as classical residual std |
| Classical residual std | 0.600 | Human proxy (duplicate of OpenCV residual) | Beats raw and badge | **No** | Do not ship two residual metrics |
| Immerkaer σ | 0.369 | Human proxy, weaker than residual | Beats raw and badge | **No** | Optional research comparator only |

**Research preference if approved:** one residual-noise amount (production OpenCV), invert for the member badge. Still weak-to-moderate, not a strong IQA score.

### Brightness / exposure (human-rated SPAQ proxy: `attr_brightness_raw`; SPAQ does not split over vs under)

| Candidate | Spearman | Evidence | vs ENET | Deploy now? | Before any deploy |
|-----------|----------|----------|---------|-------------|-------------------|
| ENET raw luma | −0.075 | Characteristic (`?`), CI includes 0 | Not judged | No change | Do not treat as "better exposure" |
| ENET badge (triangle then bins) | 0.045 | Human proxy, CI includes 0 | n/a | Keep until replaced | Phase 11: 146/200 sit at badge 5 |
| OpenCV / classical mean luma | 0.150 | Characteristic (`?`) | Not judged | **No** as quality | Fine as a debug amount |
| Exposure triangle @ 0.48 | 0.427 | Human proxy (quality-like) | Beats raw and badge | **No** | A priori triangle, not SPAQ-fit; ACCESS-native over/under still missing |
| Clip fraction | −0.168 | Human proxy, high = worse | Beats raw and badge | **No** as sole badge | Complement only; SPAQ does not label clip |

**Research preference if approved:** quality-like triangle (already in production brightness `q`) is the SPAQ-aligned piece, not ENET's raw luma head. Mean luma is a characteristic.

### Contrast (human-rated SPAQ proxy: `attr_contrast_raw`)

| Candidate | Spearman | Evidence | vs ENET | Deploy now? | Before any deploy |
|-----------|----------|----------|---------|-------------|-------------------|
| ENET raw / badge | −0.147 / −0.028 | Human proxy, **wrong sign** vs SPAQ | Fail declared + | **Do not invert in production** from this set | Construct bug, not a display-ladder fix |
| OpenCV RMS/72 | 0.319 | Human proxy, correct sign | Beats raw and badge | **No** | A priori scale; Phase 8 high-contrast family was anti-monotonic for some maps |
| Classical RMS | 0.316 | Human proxy (near-duplicate of OpenCV) | Beats raw and badge | **No** | Prefer one RMS |
| Michelson | 0.346 | Human proxy, best 12A contrast | Beats raw and badge | **No** | Clip/harsh contrast still unlabeled on SPAQ |

**Research preference if approved:** OpenCV RMS or Michelson instead of the ENET contrast head. Do not silently negate ENET contrast.

### Blur (technical only: no SPAQ label)

| Candidate | What 12A showed | Evidence | Deploy now? | Before any human claim |
|-----------|-----------------|----------|-------------|------------------------|
| ENET blur amount | n=200, mean 0.701, unique 200 | Technical + Phase 8 | Keep as-is | BID / LIVE blur overall DMOS (download + protocol approval) |
| OpenCV blur | mean 0.709; **blur = 1 − sharpness** | Technical duplicate of sharpness | Do not advertise as independent | New labels that split defocus/motion from sharpness |
| Classical inv-Laplacian | mean 0.800, unique 200 | Technical, same Laplacian axis | No | Same as OpenCV |

### Blocking (technical only: no SPAQ label)

| Candidate | What 12A showed | Evidence | Deploy now? | Before any human claim |
|-----------|-----------------|----------|-------------|------------------------|
| ENET blocking | mean 0.612, unique 200 | Technical + Phase 8 JPEG | Keep as-is | LIVE/TID JPEG overall DMOS (not ACCESS 1–5) |
| OpenCV 8×8 | mean 0.512, unique 200 | Technical heuristic | No accuracy claim | Same |
| Classical boundary ratio | mean 1.162, min 0.95, max 2.57 | Technical | No accuracy claim | Same |

### Ringing (technical only: no SPAQ label)

| Candidate | What 12A showed | Evidence | Deploy now? | Before any human claim |
|-----------|-----------------|----------|-------------|------------------------|
| ENET ringing | mean 0.549, unique 200 | Technical + Phase 8 | Keep as-is | LIVE JP2K / TID (codec ringing ≠ phone unsharp) |
| OpenCV ringing | mean 0.113, unique 185, max 0.5 | Technical, compressed range | No accuracy claim | Same |
| Classical edge-Laplacian | mean 16.85, max 117.8 | Technical, unnormalized | No accuracy claim | Same |

### Overall MOS (human-rated SPAQ MOS; **not** a seventh badge)

| Candidate | Spearman | Evidence | vs ENET | Deploy now? | Before any deploy |
|-----------|----------|----------|---------|-------------|-------------------|
| Mean of seven badges | −0.067 | Human MOS, CI includes 0 | n/a | Keep as current overall | Product decision: overall vs seven criteria |
| Mean of seven ENET raw heads | 0.171 | Mixed polarities (`?`) | Not judged as a win | **No** | Phase 11 ridge 0.37 ± 0.14 is SPAQ-fit, not deployable |
| Official TF Hub MUSIQ PaQ-2-PiQ | 0.828 | Human MOS only | Beats badge (and the raw-mean |r|) | **No** | See licensing, performance, and validation below. Separate channel. No 1–5 map on these 200. Do not score MUSIQ vs the seven attributes. |

pyiqa MUSIQ remains research-only (PolyForm-NC). Not a production candidate.

---

## Licensing (must clear before production MUSIQ or weight copies)

| Artifact | Research use here | Production |
|----------|-------------------|------------|
| OpenCV classical / production OpenCV | BSD-style, already in tree | Allowed from a license standpoint; still needs product approval |
| ENET `efficientnet_b0_heads.pt` | Project model | Status quo |
| TF Hub `google/musiq/paq2piq/1` | Used in `.venv_musiq_official`; card says Apache 2.0 | **Legal review required.** GCS `paq2piq_ckpt.npz` has no NOTICE in the bucket listing. PaQ-2-PiQ **training data** is CC BY-NC-SA 4.0. Do not copy SavedModel into `access_backend` until counsel signs off. |
| pyiqa 0.1.16 + converted pth | Not used in 12B | **Forbidden** in production |
| SPAQ-200 images/ratings | Locked test set | Do not ship SPAQ-trained weights. Do not fit deploy maps on these 200. |

---

## Performance (CPU, this hardware, native SPAQ JPEGs)

| Engine | Combined-run measurement | Implication |
|--------|--------------------------|-------------|
| OpenCV + classical (12A) | Wall 3806.6 s / 200, mean 19025 ms/img | Far slower than the pre-phase guess of ≪ 0.1 s/img at **full resolution**. Any production swap needs a resize policy measured on phone-sized uploads, not a rerun of this 200. |
| Split 12A | OpenCV mean 6913 ms/img, classical mean 22014 ms/img, wall 5786.4 s | Confirms native-res cost; do not treat as a second scientific result |
| Official MUSIQ (12B) | Wall 439.4 s / 200; split mean 2126 ms/img after a 14.7 s first load | Same order as Phase 10 ENET (~2 s/img), plus TensorFlow + TF Hub cache. First-image penalty. CPU-only (`CUDA_VISIBLE_DEVICES=-1`). |
| ENET seven heads | Phase 10 ~2 s/img | Current production path |

No GPU requirement was used. Adding TensorFlow to the API process is an ops and binary-size decision, not done here.

---

## Validation still required before deployment (any criterion)

1. **Do not fit** percentile edges, ridge, isotonic, or 1–5 maps on all 200 SPAQ photos and report the same 200 as validation (Phase 11 already covered that class).
2. If a new fitted map is proposed: reuse Phase 11 folds (seed `20261107`, 5-fold, 8 per MOS quintile) or declare a split **before** looking at test Spearman.
3. ACCESS-native 1–5 ratings are still missing (Phase 10 30-photo pack empty). SPAQ 0–100 is a related proxy only.
4. Blur, Blocking, Ringing: need approved labeled sets (LIVE/TID/BID/CID) before any human-accuracy claim. CID2013 is over the 500 MB download gate.
5. Member-facing copy: all seven badges remain "higher = better." Amount metrics (noise, blur, blocking, ringing, clip) must be inverted or relabeled in the product layer, not silently mixed.
6. XP, analytics, and admin Media Integrity must be reviewed if badge histograms change (Phase 11: Brightness pile-up at 5, unreachable 1).
7. MUSIQ: MOS-only sidecar. Do not average it into the seven-head overall without a product decision. Engine check vs pyiqa on KonIQ was 0.992, not the 0.999 gate (Phase 5).
8. Video: this matrix is photo SPAQ-200. Production video still uses frame sampling; do not assume photo Spearman transfers.

---

## Ranked research options (if a later phase is approved)

1. Replace ENET **Sharpness** with Tenengrad or production OpenCV Laplacian (human proxy). Keep Blur as the inverse of that axis until new labels exist.
2. Replace ENET **Noise** with OpenCV residual amount + invert (human proxy).
3. Replace ENET **Contrast** with OpenCV RMS or Michelson (human proxy, correct sign). Do not negate ENET.
4. Keep **Brightness** as a triangle on luma; do not promote mean luma to "quality."
5. Add official MUSIQ as a **separate overall MOS** channel after legal review. Do not replace the seven badges with it.
6. Leave Blur, Blocking, Ringing as technical indicators until a labeled set is approved.

**Do not implement any of the above in this step.**

No production code was changed for this document.
