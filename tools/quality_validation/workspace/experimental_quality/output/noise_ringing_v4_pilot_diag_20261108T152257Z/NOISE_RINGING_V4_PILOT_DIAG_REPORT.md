# Noise / Ringing v4 frozen-pilot diagnostic

Generated (UTC): 2026-11-08T15:23:17.771109+00:00
Wall seconds: 20.57
Mean ms Noise v4: 607.5109199999133
Mean ms Ringing v4: 65.04786666676712

Secondary diagnostic only. Scales frozen. No tuning. No SPAQ. No production changes.

### Noise

- **v2**: n=30 Spearman=-0.25287816912705735 MAE=0.8333333333333334 bias=0.6333333333333333 within1=0.8333333333333334 hist={'1': 0, '2': 0, '3': 0, '4': 5, '5': 25}
  false_harsh=0 false_clean=5
- **v3**: n=30 Spearman=-0.16637819647012536 MAE=0.9 bias=0.23333333333333334 within1=0.8333333333333334 hist={'1': 0, '2': 0, '3': 4, '4': 9, '5': 17}
  false_harsh=0 false_clean=3
- **v4**: n=30 Spearman=-0.46871337324135887 MAE=0.9666666666666667 bias=0.5666666666666667 within1=0.8 hist={'1': 0, '2': 0, '3': 1, '4': 5, '5': 24}
  false_harsh=0 false_clean=5
- insufficient-evidence excluded: 0
- **Verdict vs v2: REGRESSED**
- Verdict vs v3: REGRESSED

### Ringing

- **v2**: n=30 Spearman=-0.4015781930526186 MAE=0.85 bias=0.35 within1=0.8 hist={'1': 0, '2': 0, '3': 0, '4': 16, '5': 14}
  false_harsh=0 false_clean=6
- **v3**: n=30 Spearman=-0.42235913379503526 MAE=2.45 bias=-2.316666666666667 within1=0.3333333333333333 hist={'1': 18, '2': 5, '3': 3, '4': 3, '5': 1}
  false_harsh=10 false_clean=0
- **v4**: n=25 Spearman=None MAE=3.1 bias=-3.1 within1=0.0 hist={'1': 25, '2': 0, '3': 0, '4': 0, '5': 0}
  false_harsh=9 false_clean=0
- insufficient-evidence excluded: 5 (PILOT-008, 023, 024, 029, 030)
- Auto Spearman verdict vs v2/v3: MIXED (v4 Spearman undefined: all scored badges = 1)
- **Operational verdict vs v2: REGRESSED** (MAE 3.10 vs 0.85; within-1 0% vs 80%; 9 false-harsh)
- **Operational verdict vs v3: REGRESSED** (MAE 3.10 vs 2.45; within-1 0% vs 33%; constant floor)

## Recommendation
Do not integrate into production. Await approval before any further evaluation or composition change.
