# Final frozen Noise and Ringing validation decision

Generated (UTC): 2026-11-09T00:02:45.918484+00:00
Images: NR001–NR015 (n=15)
Machine runtime: 70.72 s

## Human reliability (verified)

- Noise: proceed=True; LIMITED CONSENSUS=False
- Ringing: proceed=True; **LIMITED CONSENSUS=True**

Ringing proceeds under the pre-registered H3 soft-gate rule (H1/H2/H4/H5 pass, Fleiss below 0.20).

## Machine gate summary (M1–M6)

| Candidate | Criterion | Available | Spearman ρ | p | MAE | Within-1 | Distinct badges | False-harsh | M1–M6 eligible |
|---|---|---|---:|---:|---:|---:|---:|---:|---|
| C-prod | noise | True | -0.102 | 0.7168 | 0.667 | 0.867 | 2 | 0.000 | False |
| C-prod | ringing_artifacts | True | -0.073 | 0.7951 | 1.267 | 0.667 | 2 | 0.000 | False |
| C-v2 | noise | True | -0.078 | 0.7817 | 0.800 | 0.933 | 3 | 0.000 | False |
| C-v2 | ringing_artifacts | True | -0.021 | 0.9417 | 0.800 | 0.800 | 4 | 0.083 | False |
| C-combined | noise | True | -0.078 | 0.7817 | 0.800 | 0.933 | 3 | 0.000 | False |
| C-combined | ringing_artifacts | True | -0.067 | 0.8135 | 2.867 | 0.200 | 2 | 0.917 | False |

## Study outcome (locked vocabulary)

**Keep unvalidated**

No candidate passed M1–M6 for either criterion.

### Eligible candidates

- Noise: (none)
- Ringing: (none)

## Go / no-go recommendation

**NO-GO for further review / production.** Keep Noise and Ringing unvalidated. No production, Flutter, sandbox scoring, or threshold changes.

## Hard constraints honored

- No detector retune / retrain / new versions
- No SPAQ-200 or frozen-30 pilot re-run
- No production / Flutter / sandbox scoring / weight changes
- Locked acceptance criteria unchanged
- Unavailable estimators marked unavailable (no silent substitute)

## Artifacts

- `HUMAN_IRR_VERIFICATION_REPORT.md`
- `frozen_rating_checksums.csv` + `frozen_human_ratings/`
- `human_consensus_by_image.csv`
- `per_image_machine_vs_human.csv`
- `machine_gate_summary.csv`
- `validation_payload.json`

