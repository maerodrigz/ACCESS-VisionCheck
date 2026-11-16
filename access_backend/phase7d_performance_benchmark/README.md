# Phase 7D — Performance benchmark outputs

This folder is filled by:

```bat
cd /d C:\Users\Dell\Desktop\access_mobile\access_backend
python scripts\benchmark_quality_engines_phase7d.py
```

Expected artifacts after a successful run:

| File | Contents |
|------|----------|
| `benchmark_raw.json` | Full per-image timings, RSS/CPU samples, Docker stats |
| `comparison_table.csv` | Summary table |
| `BENCHMARK_REPORT.md` | Human-readable comparison + recommendation |

Does **not** modify Phase 6B datasets, `.env`, Flutter, authenticity, DB records, or production `QUALITY_ENGINE`.
