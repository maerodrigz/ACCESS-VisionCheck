# Phase 1: Hybrid NR-IQA research prototype

Research-only. Not wired into production API, Flutter, XP, PROBE, WaveRep, or the EfficientNet checkpoint.

## Entrypoints

| File | Role |
|------|------|
| `hybrid_nr_iqa_research.py` | Classical OpenCV/NumPy criteria + MUSIQ OPQ helpers + license notes |
| `run_phase1_hybrid_pilot_comparison.py` | Score 30-image pilot, compare to locked ENET, write report |
| `classical_quality_metrics.py` | Reused classical NR signals |
| `official_musiq_engine_verification.py` | Prior official TF Hub vs research engine check |

## Run

```bash
# Classical + color (backend venv)
access_backend/venv312/Scripts/python.exe run_phase1_hybrid_pilot_comparison.py

# Prefer live official MUSIQ when TensorFlow research venv is available
tools/quality_validation/.venv_musiq_official_phase1/Scripts/python.exe \
  run_phase1_hybrid_pilot_comparison.py --with-musiq

# If TF Hub cannot be installed: join prior Run002 MUSIQ raw scores
access_backend/venv312/Scripts/python.exe run_phase1_hybrid_pilot_comparison.py \
  --reuse-classical-csv workspace/human_pilot/output/.../hybrid_per_image.csv \
  --musiq-from-benchmark-csv
```

## Latest outputs

`workspace/human_pilot/output/phase1_hybrid_nr_iqa_20261113/`

- `PHASE1_HYBRID_NR_IQA_RESEARCH_REPORT.md`
- `metrics.json`, `comparison_joined.csv`, `hybrid_per_image.csv`, `musiq_meta.json`
