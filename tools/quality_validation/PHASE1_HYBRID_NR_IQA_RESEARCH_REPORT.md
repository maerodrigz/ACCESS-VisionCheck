# Phase 1 Research Report: Hybrid NR-IQA vs EfficientNet-B0

**Generated (UTC):** 2026-11-13T12:06:53.752546+00:00
**Status:** research only. Not enabled in production.

## Verdict

PROMISING BUT NOT PRODUCTION-READY: hybrid criterion badges beat ENET on 5/5 criteria (Spearman margin >0.05), with 0 near-ties and 0 losses. Results do **not** alone authorize production cutover.

**Recommendation on production integration:** Do not proceed to production wiring. Phase 1 requires a separate approval gate after larger holdout and licensing review.

## 1. Goal and constraints

Build a research-only hybrid NR-IQA (MUSIQ OPQ + classical/OpenCV criteria) and compare retrospectively to the locked EfficientNet-B0 pilot scores without tuning and evaluating on the same samples, without modifying production.

Unchanged by design: production API, Flutter, database, XP, rule-based feedback, PROBE-DINOv2, WaveRep G4, authenticity thresholds, EfficientNet checkpoint.

## 2. Model implementation and licenses

| Component | Implementation | License / limitation |
|-----------|----------------|----------------------|
| OPQ (overall) | Prior research MUSIQ PaQ-2-PiQ raw scores joined by source_media_key (engine=`prior_research_musiq_paq2piq_benchmark_csv`; live TF Hub deferred) | Preferred weight source remains TF Hub Apache-labeled SavedModel. Joined benchmark scores come from the earlier KonIQ MUSIQ research run (pyiqa packaging is PolyForm-NC: research OK, not production). GCS npz production rights **not established**. |
| Sharpness / Blur / Brightness / Contrast / Blocking | `classical_quality_metrics.py` + a priori q maps (LAP_SCALE=420, brightness triangle 0.48, blocking boundary ratio) | Research code under repo; OpenCV/NumPy BSD-style dependencies |
| Color Balance / Color Saturation | Read-only reuse of `access_backend/app/services/color_quality_criteria.py` | Same as production heuristics; heuristic estimates, not IQA-trained |
| EfficientNet-B0 baseline | Locked pilot join only (no re-inference) | Existing production checkpoint retained; not deleted |

### MUSIQ license notes (verbatim research findings)

- **preferred_engine:** TensorFlow Hub google/musiq TensorFlow2/paq2piq/1
- **tfhub_license_label:** Apache License 2.0 (as listed on TF Hub / Kaggle model card)
- **google_research_source:** google-research/google-research musiq/*.py headers: Apache License 2.0
- **gcs_npz_limitation:** gs://gresearch/musiq/*.npz weights have no LICENSE/NOTICE in the bucket. Apache labeling of repo code does not automatically cover those npz files. Production use of GCS npz is not established.
- **pyiqa_limitation:** IQA-PyTorch (pyiqa) is PolyForm Noncommercial License 1.0.0. Research-only OK; commercial / production redistribution is not permitted under that license. Phase 1 prefers the official TF Hub SavedModel, not pyiqa.
- **training_data_note:** MUSIQ PaQ-2-PiQ was trained on public IQA corpora (PaQ-2-PiQ/FLIVE and related). Those dataset licenses are separate from the model card Apache label.
- **intended_use_this_phase:** Research comparison only inside tools/quality_validation. Not enabled in production API, Flutter, XP, or rule-based feedback.

**MUSIQ engine handle:** `prior_research_musiq_paq2piq_benchmark_csv`

**OPQ provenance (live TF Hub deferred):**

Live official TF Hub scoring was not completed in this Phase 1 session (tensorflow-cpu wheel download failed on this host). OPQ values are the locked research MUSIQ PaQ-2-PiQ raw scores for the identical Run002 source files used to build the 30-image pilot. Prefer re-running --with-musiq when TF Hub is available. pyiqa packaging is PolyForm-NC (research OK); TF Hub card remains the preferred production-candidate weight source pending legal review.

Prior official TF Hub vs that benchmark engine (n=24): Pearson=0.9997477772016965, Spearman=0.9921739130434782, MAD=0.07349046071370442 (primary_equivalent under 0.999 Spearman bar: False).

Note on MAE vs Spearman: hybrid equal-bin can improve rank correlation while MAE stays similar or worse than ENET (badge offsets). Do not equate higher Spearman with better absolute 1-5 agreement.

## 3. Test dataset and evaluation protocol

| Item | Detail |
|------|--------|
| Images | 30 blinded photos `PILOT-001`…`PILOT-030` |
| Image path | `C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\human_pilot\rater_pack\images` |
| Human labels | 3-rater medians from locked `human_consensus_by_image.csv` |
| ENET scores | Locked `machine_scores_joined.csv` (Run002 join) |
| Hybrid maps | A priori equal-bin / Phase 9 scales; **not** fit on these 30 |
| Resize | Longest side 1024 px, INTER_AREA, no upscale |
| Same-set tuning | **Forbidden and not performed** |

### Was this pilot previously used for development or calibration?

- Used for ENET human-vs-machine **evaluation**: **True**
- Used to fit ENET thresholds/weights: **False**
- Used to fit hybrid a priori maps: **False**
- Used to calibrate MUSIQ to 1–5: **False**
- Phase 1 role: Transparent retrospective comparison only. Hybrid maps and MUSIQ weights were not tuned on these 30 images. ENET scores are the locked Run002 join from the same pilot analysis folder.
- Related development sets: SPAQ-200 was used for exploratory classical/Tenengrad readiness (not this pilot). Phase 8/9 controlled distortion informed a priori classical scales. LIVEC / official MUSIQ validation used public MOS, not this pilot.

Because the pilot was already used to **evaluate** ENET, this comparison is a transparent retrospective check for the hybrid against the same locked human medians. It is **not** an independent first look at human agreement for ENET. Hybrid parameters were not adjusted after seeing these correlations.

## 4. Metric comparison table

### 4.1 Overall perceptual quality

| Pair | n | Spearman | Pearson | MAE | MAE allowed? |
|------|--:|---------:|--------:|----:|:------------:|
| ENET overall_score vs human overall median | 30 | 0.035 | 0.040 | 0.738 | yes |
| MUSIQ raw OPQ vs human overall median | 30 | 0.450 | 0.443 | n/a | no |
| MUSIQ raw OPQ vs ENET overall_score | 30 | -0.135 | -0.088 | n/a | no |

MUSIQ OPQ is ~0-100; human overall and ENET overall_score are 1-5. Report Spearman/Pearson only for MUSIQ; MAE only for ENET vs human.

### 4.2 Criterion badges vs human medians (1–5)

| Criterion | ENET Spearman | Hybrid equal-bin Spearman | ENET Pearson | Hybrid Pearson | ENET MAE | Hybrid MAE | Hybrid − ENET Spearman |
|-----------|--------------:|--------------------------:|-------------:|---------------:|---------:|-----------:|------------------------:|
| sharpness | 0.104 | 0.651 | 0.122 | 0.664 | 0.933 | 1.067 | +0.547 |
| blur | 0.160 | 0.800 | 0.163 | 0.810 | 0.933 | 1.033 | +0.640 |
| brightness | 0.064 | 0.403 | 0.067 | 0.402 | 0.800 | 1.167 | +0.339 |
| contrast | 0.092 | 0.344 | 0.085 | 0.312 | 1.017 | 1.017 | +0.252 |
| blocking_artifacts | 0.001 | 0.183 | -0.025 | 0.183 | 0.950 | 0.483 | +0.182 |

MAE is reported because both ENET badges and hybrid equal-bin badges are on the human 1–5 scale. Continuous q∈[0,1] vs human uses Spearman/Pearson only (see `metrics.json`).

### 4.3 Color criteria

Human pilot sheets have no Color Balance / Color Saturation columns. Hybrid color badges are scored for inventory only; no human correlation.
Inventory: Color Balance available on 26/30; Color Saturation available on 28/30.

## 5. Errors and limitations

- Classical/color scoring errors: **0** / 30 images.
- MUSIQ per-image errors / skips: **0** / 30 (includes 'not requested' if `--with-musiq` omitted).
- n=30 is small; Spearman CIs are wide; do not over-interpret single-criterion flips.
- Sharpness and Blur share one Laplacian quality axis (Phase 9 duplication). They are not independent evidence.
- Human pilot has no color-balance / saturation ratings; those hybrid heads cannot be validated here.
- Pilot was previously used to evaluate ENET; ENET agreement figures are retrospective repeats, not a fresh holdout for ENET.
- No frozen MUSIQ→1–5 calibration was applied; therefore MAE(MUSIQ, human) is intentionally omitted.
- TF Hub Apache label does not clear GCS npz production licensing; commercial integration needs a separate legal/product decision.
- Classical maps can still emit compressed badge histograms; equal-bin fixes reachability of 1/5 relative to `_soft_score` but is not perceptual calibration.

## 6. Files

- Output directory: `c:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\human_pilot\output\phase1_hybrid_nr_iqa_20261113`
- `hybrid_per_image.csv` — hybrid scores per pilot image
- `comparison_joined.csv` — hybrid + human + locked ENET
- `metrics.json` — full correlation blocks
- `musiq_meta.json` — engine load + license notes
- `PHASE1_HYBRID_NR_IQA_RESEARCH_REPORT.md` — this report

## 7. Production integration recommendation

**Do not enable the hybrid evaluator in production.** Keep EfficientNet-B0 as the live quality engine. Next research steps (only after approval): larger ACCESS-native holdout disjoint from this pilot, optional frozen MUSIQ 1–5 calibration on a non-pilot set, licensing sign-off for TF Hub weights in deployment, and a Phase 2 design for API dual-run shadow scoring.

