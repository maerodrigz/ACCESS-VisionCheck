# Phase 5B–5D: Live MUSIQ + OpenCV Criterion Validation

**Output folder:** `C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\human_pilot\output\phase5_criterion_validation_20261114T010303Z`
**UTC stamp:** 20261114T010303Z
**Worker ready:** `{"status": "ready", "musiq_ready": true, "model_id": "tfhub:google/musiq/paq2piq/1", "model_version": "paq2piq/1", "engine_handle": "https://tfhub.dev/google/musiq/paq2piq/1"}`
**Successful evaluations:** 30/30 (MUSIQ ok: 30/30; failed/errored requests recorded: 0)

## Constraints honored

- No production / Flutter / PROBE / WaveRep changes.
- `QUALITY_ENGINE=enet` remains production default.
- No threshold recalibration on these 30 pilot images.
- Equal-bin OpenCV badges labeled **experimental / uncalibrated**.
- MUSIQ used as **overall** perceptual quality only (not criterion-specific).
- MAE omitted for MUSIQ ~0–100 vs human 1–5.
- Token never written to research outputs.

## Methodology

1. Verified `GET /ready` on the local Docker MUSIQ worker.
2. Authenticated `POST /v1/evaluate` for each `PILOT-001`…`030` JPG (live OpenCV classical + live MUSIQ PaQ-2-PiQ).
3. Joined on `media_id` to locked human consensus medians (`human_consensus_by_image.csv`) and locked ENET badges (`machine_scores_joined.csv`).
4. Spearman ρ per criterion; MAE only for 1–5 vs 1–5 OpenCV equal-bin badges (and retrospective ENET).
5. Classical map version from worker: `['phase9_a_priori_equal_bin_v1']`.

## Missing data

Four individual rater cells were blank (audit §2.3). Consensus medians exclude blanks per cell; all 30 images retain medians for Phase 5 criteria:

- R1 / PILOT-020 / `blocking_artifacts`
- R2 / PILOT-012 / `contrast`
- R3 / PILOT-012 / `brightness`
- R3 / PILOT-013 / `ringing_artifacts`

Joined table: **0** missing human medians for sharpness, blur, brightness, contrast, blocking, overall.

Live machine missing: badges {none}; MUSIQ OPQ missing=0.

## Per-criterion results (primary)

| Criterion | Machine | n | Spearman ρ | Spearman p | MAE | Notes |
|---|---|---:|---:|---:|---:|---|
| sharpness | live_opencv_badge_equal_bin | 30 | 0.6513 | 0.0001 | 1.0667 | experimental_uncalibrated_equal_bin |
| blur | live_opencv_badge_equal_bin | 30 | 0.8004 | 0.0000 | 1.0333 | experimental_uncalibrated_equal_bin |
| brightness | live_opencv_badge_equal_bin | 30 | 0.4026 | 0.0274 | 1.1667 | experimental_uncalibrated_equal_bin |
| contrast | live_opencv_badge_equal_bin | 30 | 0.3438 | 0.0628 | 1.0167 | experimental_uncalibrated_equal_bin |
| blocking_artifacts | live_opencv_badge_equal_bin | 30 | 0.1829 | 0.3334 | 0.4833 | experimental_uncalibrated_equal_bin |
| overall_visual_quality | live_musiq_opq_paq2piq | 30 | 0.4542 | 0.0117 | omitted | musiq_overall_only_not_criterion_predictor |

### OpenCV continuous q (Spearman only)

| Criterion | n | Spearman ρ | Spearman p |
|---|---:|---:|---:|
| sharpness | 30 | 0.7026 | 0.0000 |
| blur | 30 | 0.8327 | 0.0000 |
| brightness | 30 | 0.4090 | 0.0248 |
| contrast | 30 | 0.3266 | 0.0781 |
| blocking_artifacts | 30 | 0.0614 | 0.7472 |

## Descriptive comparison vs locked EfficientNet-B0

ENET numbers are **retrospective** on a pilot already used for ENET human-vs-machine evaluation. No claim of statistically significant improvement is made without a formal paired test pre-registered on an independent holdout (Phase 4A humans still empty).

| Criterion | Live OpenCV badge ρ | Locked ENET badge ρ | Live MAE | ENET MAE |
|---|---:|---:|---:|---:|
| sharpness | 0.6513 | 0.1040 | 1.0667 | 0.9333 |
| blur | 0.8004 | 0.1604 | 1.0333 | 0.9333 |
| brightness | 0.4026 | 0.0636 | 1.1667 | 0.8000 |
| contrast | 0.3438 | 0.0923 | 1.0167 | 1.0167 |
| blocking_artifacts | 0.1829 | 0.0009 | 0.4833 | 0.9500 |
| overall (MUSIQ vs ENET mean) | 0.4542 | 0.0350 | omitted | 0.7380 |

Live MUSIQ vs Phase 1 CSV-joined MUSIQ (machine provenance): n=30, Spearman ρ=0.9982.

## Reproducibility

- Worker URL: `http://127.0.0.1:8080`
- Token source (not value): `docker-compose-default`
- Worker model: `tfhub:google/musiq/paq2piq/1` / `paq2piq/1`
- Observed worker_version: `['1.0.0']`
- Classical map: `['phase9_a_priori_equal_bin_v1']`
- Image root: `C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\human_pilot\rater_pack\images`
- Human consensus: `C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\human_pilot\output\pilot_hvsm_20261108T114511Z\human_consensus_by_image.csv`
- Artifacts: `live_evaluations.jsonl`, `live_scores.csv`, `comparison_joined.csv`, `criterion_stats.csv`, `run_meta.json`

## Limitations

- n=30; correlations are unstable and exploratory.
- Sharpness and blur share the Laplacian axis (dependent measures).
- Equal-bin badges are experimental; do not present as validated member feedback.
- Pilot already used for ENET evaluation; not an independent ENET holdout.
- No human GT for color; noise/ringing lack live OpenCV badges in worker q set.
- Phase 4A (n=100) remains the intended independent set once humans rate it.

## Conclusion: readiness for further validation

Live Docker MUSIQ + OpenCV scoring of the locked 30-image pilot **completed** with versioned research outputs. Criterion-level Spearman/MAE tables are available for research review. This does **not** authorize switching `QUALITY_ENGINE`, publishing experimental badges to members, or claiming criterion validation. Next appropriate step: independent human ratings on Phase 4A (or a new sealed set), then pre-registered analysis without retuning on that holdout.

