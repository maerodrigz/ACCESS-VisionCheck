# Ringing v3 lightweight evaluation

Generated (UTC): 2026-11-08T14:12:44.527288+00:00
Overall: **PASS** (5 PASS / 0 FAIL)
Wall seconds: 0.743

## Diagnosis (v2)
v2 near-edge |d2| under-detects real halos on ACCESS photos (humans 3, machine 4–5) and is not specific to plateau overshoot / Gibbs ripples (ρ ≈ −0.40).

## Sinc / Gibbs ladder

| passes | v2 amount | v2 badge | v3 amount | v3 badge |
|---:|---:|---:|---:|---:|
| 0 | 0.0000 | 5 | 0.0000 | 5 |
| 1 | 7.0000 | 4 | 15.6772 | 2 |
| 2 | 0.0000 | 5 | 29.2324 | 1 |
| 3 | 0.0000 | 5 | 28.2220 | 1 |

## Unsharp ladder

| amount | v2 amount | v2 badge | v3 amount | v3 badge |
|---:|---:|---:|---:|---:|
| 0.0 | 0.0000 | 5 | 0.0000 | 5 |
| 1.2 | 3.3333 | 5 | 27.8785 | 1 |
| 2.4 | 6.3333 | 4 | 25.4002 | 1 |

## Clean texture
- v2 amount/badge: 0.0000 / 5
- v3 amount/badge: 0.0000 / 5

## Runtime (mean over sinc ladder)
- v2: 28.2 ms
- v3 engine: 60.1 ms
- overhead: 31.9 ms

## PASS/FAIL
- `sinc_generally_worsens_v3`: **PASS**
- `clean_step_high_badge_v3`: **PASS**
- `strong_sinc_worse_than_clean_v3`: **PASS**
- `unsharp_worse_than_clean_v3`: **PASS**
- `texture_not_false_strong_ringing_v3`: **PASS**

## Recommendation
Ringing v3 clears lightweight controlled gates; keep research-only. Do not replace v2 or ship to production without approved larger eval.
