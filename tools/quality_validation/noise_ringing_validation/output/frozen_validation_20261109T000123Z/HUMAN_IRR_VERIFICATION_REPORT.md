# Human IRR verification report (NR001–NR015)

Generated (UTC): 2026-11-09T00:02:45.918484+00:00

Independent recalculation against locked `ACCEPTANCE_CRITERIA.md` §1.
Source ratings: frozen copies under `frozen_human_ratings/` with SHA-256 in `frozen_rating_checksums.csv`.

## Checksums

| File | SHA-256 |
|---|---|
| `R1_noise_ringing_ratings.csv` | `5bac25215fa07803b544993ccf5fbbc8501f2124289967808abd99bfd29967ba` |
| `R2_noise_ringing_ratings.csv` | `dca953e7c6b5d7176d1e498ace647891f228684ab1148a8fa16c81661204ea90` |
| `R3_noise_ringing_ratings.csv` | `db7c1ee809cd8fe9032df48ed72ba3657910165b1da29894575fe670ae6000d6` |

## Noise

- Mean pairwise within-1: **0.978** (H1 ≥ 0.85 → PASS)
- Mean pairwise QWK: **0.726** (H2 ≥ 0.40 → PASS)
- Fleiss’ κ: **0.395** (H3 ≥ 0.20 → PASS)
- Disagreement rate (max−min ≥ 3): **0.000** (H4 ≤ 0.15 → PASS)
- Usable coverage: **1.000** (H5 ≥ 0.90 → PASS)
- Limited consensus flag: **False**
- Proceed to machine compare: **True**

Pairwise detail:

| Pair | n | exact | within-1 | QWK |
|---|---:|---:|---:|---:|
| R1-R2 | 15 | 0.600 | 0.933 | 0.687 |
| R1-R3 | 15 | 0.533 | 1.000 | 0.662 |
| R2-R3 | 15 | 0.733 | 1.000 | 0.830 |

## Ringing Artifacts

- Mean pairwise within-1: **0.956** (H1 ≥ 0.85 → PASS)
- Mean pairwise QWK: **0.552** (H2 ≥ 0.40 → PASS)
- Fleiss’ κ: **0.160** (H3 ≥ 0.20 → FAIL)
- Disagreement rate (max−min ≥ 3): **0.000** (H4 ≤ 0.15 → PASS)
- Usable coverage: **1.000** (H5 ≥ 0.90 → PASS)
- Limited consensus flag: **True**
- Proceed to machine compare: **True**

Pairwise detail:

| Pair | n | exact | within-1 | QWK |
|---|---:|---:|---:|---:|
| R1-R2 | 15 | 0.267 | 0.933 | 0.379 |
| R1-R3 | 15 | 0.333 | 0.933 | 0.373 |
| R2-R3 | 15 | 0.800 | 1.000 | 0.904 |
