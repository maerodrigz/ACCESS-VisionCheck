# Phase 5 Criterion-Level Quality Validation — Asset Audit

**Status:** audit only. No production code changed. No new statistics invented.  
**Date:** 2026-11-14  
**Stop point:** review this audit before any Phase 5 implementation.

`QUALITY_ENGINE=enet` remains the production default. PROBE-DINOv2, WaveRep G4, member-facing scores, and feedback are out of scope for this phase.

---

## 1. Files found (30-image human pilot)

### 1.1 Canonical pilot root

`tools/quality_validation/workspace/human_pilot/`

| Asset | Path | Role |
|-------|------|------|
| Blinded images (30 JPG) | `rater_pack/images/PILOT-001.jpg` … `PILOT-030.jpg` | Rater-facing media |
| Empty templates | `rater_pack/ratings_R1.csv`, `ratings_DEV.csv` | Blank sheets (not filled) |
| Rubric / instructions | `rater_pack/HUMAN_RATING_RUBRIC.md`, `INSTRUCTIONS.md` | 1–5 anchors |
| Filled locked ratings | `actual_ratings/ratings_R1.csv.csv`, `ratings_R2.csv.csv`, `ratings_R3.csv.csv` | Source human sheets (odd double `.csv.csv` suffix) |
| Facilitator unblind map | `facilitator/facilitator_manifest.csv` | `anonymous_id` ↔ `source_media_key` / SHA-256 |
| Facilitator checklist | `facilitator/CHECKLIST.md`, `verification.json` | Ops notes |
| Human consensus (locked analysis) | `output/pilot_hvsm_20261108T114511Z/human_consensus_by_image.csv` | Per-image medians |
| Combined raw ratings | `…/human_ratings_combined.csv` | 90 rows (30×3) |
| ENET machine join | `…/machine_scores_joined.csv` | Locked EfficientNet-B0 badges |
| Prior H-vs-M summary | `…/criterion_comparison_summary.csv`, `overall_construct_comparison.csv` | ENET vs human (already computed) |
| Manuscript report | `…/FINAL_HUMAN_VALIDATION_REPORT.md` | Methods + results |
| Phase 1 hybrid outputs | `output/phase1_hybrid_nr_iqa_20261113/` | Hybrid OpenCV + joined MUSIQ CSV |
| Phase 1 classical-only tmp | `output/phase1_hybrid_nr_iqa_classical_tmp/` | Intermediate classical run |
| Analysis scripts | `tools/quality_validation/analyze_human_pilot_validation.py`, `run_phase1_hybrid_pilot_comparison.py` | Existing runners |
| Read-only audit helper | `tools/quality_validation/scripts/_audit_phase5_pilot_assets.py` | Coverage check used for this report |

### 1.2 Related but not this pilot

| Asset | Notes |
|-------|-------|
| Phase 4A holdout (`workspace/phase4a_indval/`) | 100 KonIQ images, **disjoint** from pilot; human sheets exist but **ratings empty** |
| SPAQ-200 | Exploratory set; not the 30-pilot criterion GT |
| Docker MUSIQ worker live smoke | `access_backend/research_logs/quality_shadow_live_verify/` | 1 anonymized shadow line; **not** joined to PILOT IDs |
| Prior MUSIQ benchmark CSV | `workspace/datasets/koniq10k/musiq_paq2piq_benchmark/raw_predictions.csv` | Joined into Phase 1 by `source_media_key` |

Images, filled CSVs, and facilitator maps are gitignored under `human_pilot/.gitignore` but **present on disk**.

---

## 2. Human-rated criteria and scales

### 2.1 Scale (all rated constructs)

- Integer **1–5**, higher is always better (including Blur and Noise).
- `N/A` allowed when unjudgeable; photo fields `flickering` / `motion_stability` are N/A by protocol.
- Rubric: `rater_pack/HUMAN_RATING_RUBRIC.md`.

### 2.2 Columns present in filled R1/R2/R3 sheets

| Column | Human ratings exist? | Notes |
|--------|----------------------|-------|
| `sharpness` | **Yes** | Required Phase 5 comparison vs OpenCV |
| `blur` | **Yes** | Required vs OpenCV |
| `brightness` | **Yes** | Required vs OpenCV |
| `contrast` | **Yes** | Required vs OpenCV |
| `overall_visual_quality` | **Yes** | Required vs **MUSIQ overall only** (not vs criteria) |
| `noise` | **Yes** | Human exists; hybrid Phase 1 OpenCV **q** does **not** emit a noise badge |
| `blocking_artifacts` | **Yes** | Human exists; hybrid OpenCV **does** emit blocking badge |
| `ringing_artifacts` | **Yes** | Human exists; hybrid OpenCV **does not** emit ringing in Phase 1 q set |
| Color Balance | **No** | Not on pilot sheets |
| Color Saturation | **No** | Not on pilot sheets |
| Flickering / Motion stability | N/A for photos | Not usable as photo GT |

Consensus reference for analysis: **`{criterion}_median`** in `human_consensus_by_image.csv` (median of available R1/R2/R3; blanks excluded per cell).

### 2.3 Explicit missing human cells (already documented; still present)

| Rater | Image | Blank criterion |
|-------|-------|-----------------|
| R1 | PILOT-020 | `blocking_artifacts` |
| R2 | PILOT-012 | `contrast` |
| R3 | PILOT-012 | `brightness` |
| R3 | PILOT-013 | `ringing_artifacts` |

Medians still exist for all 30 images on every technical criterion and overall (n_raters 2 or 3 where a blank occurred).

---

## 3. Prior machine results

### 3.1 EfficientNet-B0 (locked)

- File: `output/pilot_hvsm_20261108T114511Z/machine_scores_joined.csv`
- Join key: `media_id` = `PILOT-xxx`
- Also carries `source_media_key`, `koniq2_media_id`, `quality_engine=efficientnet-b0`
- Columns: `sharpness`, `blur`, `noise`, `brightness`, `contrast`, `blocking_artifacts`, `ringing_artifacts`, `overall_score` (mean of seven badges)
- **Not recomputed** in the original pilot analysis; joined from KonIQ Run 002 exports
- Prior Spearman vs human medians already tabulated in `criterion_comparison_summary.csv` (all criteria weak; do not re-claim validation)

### 3.2 Hybrid OpenCV (Phase 1, 2026-11-13)

- File: `output/phase1_hybrid_nr_iqa_20261113/hybrid_per_image.csv`
- Join key: `media_id` = `PILOT-xxx`
- Continuous `q_*`, equal-bin `badge_*`, raw Laplacian / brightness / contrast / blocking
- Criteria with hybrid badges: sharpness, blur, brightness, contrast, blocking
- Color badges inventoried only (no human GT)
- Joined comparison: `comparison_joined.csv` (human medians + ENET + hybrid + MUSIQ OPQ)

### 3.3 MUSIQ overall (Phase 1 provenance — important)

- Present in hybrid outputs as `musiq_opq_raw` (~0–100)
- Engine recorded as **`prior_research_musiq_paq2piq_benchmark_csv`** (join by Run002 `source_media_key`)
- **`live_tfhub`: false** in `musiq_meta.json`
- Not the Docker worker scores from 2026-11-14 shadow smoke
- Therefore Phase 5 “human overall vs MUSIQ” should either:
  1. Reuse this locked CSV with clear provenance labeling, **or**
  2. Prefer a **new live Docker worker** pass over the same 30 `PILOT-*.jpg` files (recommended for alignment with the now-working worker), writing a separate versioned output (do not overwrite Phase 1 files)

### 3.4 Shadow / worker logs

- `access_backend/research_logs/quality_shadow_live_verify/quality_shadow_YYYYMMDD.jsonl`: **1** anonymized smoke record (`media_anon_id` HMAC), **not** pilot-joined
- Not suitable as the Phase 5 pilot machine table without a dedicated pilot rescore

---

## 4. ID matching and integrity

| Check | Result |
|-------|--------|
| Image count | **30 / 30** `PILOT-001`…`030`, unique names |
| Facilitator rows | **30**, no duplicate `anonymous_id`, no duplicate `file_sha256` |
| Consensus rows | **30**, IDs match images |
| ENET machine rows | **30**, IDs match images |
| Hybrid rows | **30**, IDs match images |
| Phase 1 joined rows | **30** |
| Missing images vs any locked table | **None** |
| Duplicate PILOT IDs in actual R1/R2/R3 | **None** |
| Primary join key | **`media_id` / `anonymous_id` = `PILOT-xxx`** |
| Secondary unblind key | `source_media_key` (e.g. `5596270310.jpg`) via facilitator manifest |
| KonIQ MOS | Metadata only (`mos_quality_raw`); **not** criterion GT |

`rater_pack/ratings_R1.csv` remains an **empty template** (0 sharpness filled). Use `actual_ratings/` or consensus CSV for GT.

---

## 5. Required Phase 5 comparisons (eligibility)

| Comparison | Human GT | Machine source available | Comparable scale for MAE? |
|------------|----------|--------------------------|---------------------------|
| Human sharpness vs OpenCV sharpness | median | Hybrid `badge_sharpness` and/or `q_sharpness` | Badge 1–5: **yes**; continuous q: Spearman only |
| Human blur vs OpenCV blur | median | Hybrid `badge_blur` / `q_blur` | Same |
| Human brightness vs OpenCV brightness | median | Hybrid `badge_brightness` / `q_brightness` | Same |
| Human contrast vs OpenCV contrast | median | Hybrid `badge_contrast` / `q_contrast` | Same |
| Human overall vs MUSIQ overall | `overall_visual_quality` median | `musiq_opq_raw` (~0–100) | **Spearman/Pearson only**; MAE **not** justified without a frozen 0–100→1–5 map (none exists; do not fit on this pilot) |

### Additional human criteria (optional, if Phase 5 expands)

| Criterion | Include? | Caveat |
|-----------|----------|--------|
| Blocking | Possible | Hybrid badge exists; already in Phase 1 table |
| Noise | Human yes / hybrid badge **no** | Would need a declared OpenCV noise mapping; not in current hybrid q set |
| Ringing | Human yes / hybrid badge **no** | Same |
| Color | **No GT** | Inventory only |

**Do not** treat MUSIQ as a criterion-specific predictor for sharpness/blur/etc.

---

## 6. Calibration vs evaluation (do not blur)

| Dataset | Prior use | Phase 5 role |
|---------|-----------|--------------|
| 30-image pilot | ENET H-vs-M **evaluation** already done; hybrid maps **not** fitted here | Transparent **retrospective** criterion check for OpenCV badges + MUSIQ OPQ rank vs human overall. **Not** a fresh independent holdout for ENET. |
| Phase 4A 100-image holdout | Machine prep done; **human ratings empty** | Future independent evaluation **after** humans submit; not usable now |
| SPAQ-200 / controlled distortion | Exploratory / a priori scale design | Not Phase 5 GT |

**Forbidden for Phase 5 implementation:** training, recalibrating, or tuning thresholds on evaluation labels from this pilot (or claiming the pilot is an unseen ENET holdout).

---

## 7. Proposed reproducible validation procedure (after audit approval)

1. **Freeze inputs (read-only copies or path pins)**  
   - Images: `rater_pack/images/PILOT-*.jpg`  
   - Human: `human_consensus_by_image.csv`  
   - ENET locked: `machine_scores_joined.csv` (reference only; production engine stays enet)  
   - Hybrid OpenCV: reuse `hybrid_per_image.csv` **or** re-run classical only into a new `phase5_*` folder without overwriting Phase 1  
   - MUSIQ: **prefer live Docker worker** rescore of the 30 JPGs → `phase5_musiq_live_*/musiq_scores.csv` (versioned)

2. **Join** on `media_id` (`PILOT-xxx`). Assert 30/30 match; fail on duplicates.

3. **Per-criterion stats** (only where GT exists):  
   - n valid pairs  
   - Spearman ρ (+ p-value)  
   - MAE/RMSE **only** for 1–5 vs 1–5 badge (or documented linear 1–5 maps already frozen a priori, not fitted here)  
   - Missing-data table (the 4 blank cells)

4. **Overall:** Spearman(human overall median, MUSIQ raw); explicitly **omit MAE**.

5. **Report template:** n, ρ, MAE (if allowed), provenance of each machine column, calibration/holdout disclaimer.

6. **Non-goals:** no Flutter/API changes; no `QUALITY_ENGINE` switch; no PROBE/WaveRep edits; no invented ratings.

### Recommended next commands (after you approve implementation)

```powershell
# 1) Re-confirm coverage (read-only)
cd tools\quality_validation
python scripts\_audit_phase5_pilot_assets.py

# 2) (Proposed) Live MUSIQ on the 30 pilot JPGs via Docker worker — new output dir only
#    (script to be added in Phase 5 implementation; do not overwrite phase1_hybrid_nr_iqa_20261113)

# 3) (Proposed) Criterion stats script reading consensus + hybrid badges + live MUSIQ
#    Write to workspace/human_pilot/output/phase5_criterion_validation_<timestamp>/
```

Existing analyzers already available for reference (do not silently retune):

- `python analyze_human_pilot_validation.py --help`
- `python run_phase1_hybrid_pilot_comparison.py --help`

---

## 8. Gaps and risks summary

| Issue | Severity | Action |
|-------|----------|--------|
| Phase 1 MUSIQ is CSV-joined, not live worker | Medium | Rescore with Docker worker for Phase 5 OPQ column |
| Shadow smoke log not pilot-linked | Low | Ignore for Phase 5 tables |
| Empty `rater_pack/*.csv` templates | Low | Use `actual_ratings/` / consensus |
| Odd filenames `ratings_R*.csv.csv` | Low | Document; do not rename until copy/archive |
| No color human GT | Info | Exclude color from correlations |
| Sharpness/blur share Laplacian axis | Analysis caveat | Report as dependent measures |
| Pilot already used for ENET evaluation | Critical for claims | Label ENET numbers retrospective; prefer Phase 4A once rated for independent claims |
| Phase 4A humans empty | Blocker for independent n=100 | Out of scope until sheets filled |

---

## 9. Audit verdict

**Assets are sufficient to start Phase 5 analysis design** for:

- OpenCV (hybrid) sharpness / blur / brightness / contrast (/ optional blocking) vs human medians  
- MUSIQ overall vs human overall (with live worker rescoring recommended)

**Not sufficient** to validate color criteria, or to claim independent ENET validation on this pilot alone.

**No production changes made.** Awaiting review before implementing Phase 5 scripts or regenerating tables.
