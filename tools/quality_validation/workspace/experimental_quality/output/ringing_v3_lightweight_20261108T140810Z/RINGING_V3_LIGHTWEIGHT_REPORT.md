# Ringing v3 lightweight evaluation

Generated (UTC): 2026-11-08T14:08:11.588501+00:00
Overall: **MIXED** (2 PASS / 3 FAIL)
Wall seconds: 1.103

## Diagnosis (v2)
v2 near-edge |d2| under-detects real halos on ACCESS photos (humans 3, machine 4–5) and is not specific to plateau overshoot / Gibbs ripples (ρ ≈ −0.40).

## Sinc / Gibbs ladder

| passes | v2 amount | v2 badge | v3 amount | v3 badge |
|---:|---:|---:|---:|---:|
| 0 | 0.0000 | 5 | 0.0000 | 5 |
| 1 | 0.0000 | 5 | 146.4125 | 1 |
| 2 | 1.0000 | 5 | 0.0000 | 5 |
| 3 | 0.0000 | 5 | 0.0000 | 5 |
| 4 | 4.0000 | 5 | 0.0000 | 5 |

## Unsharp ladder

| amount | v2 amount | v2 badge | v3 amount | v3 badge |
|---:|---:|---:|---:|---:|
| 0.0 | 0.0000 | 5 | 0.0000 | 5 |
| 1.2 | 3.3333 | 5 | 38.4750 | 1 |
| 2.4 | 6.3333 | 4 | 32.8250 | 1 |

## Clean texture
- v2 amount/badge: 0.0000 / 5
- v3 amount/badge: 0.0000 / 5

## Runtime (mean over sinc ladder)
- v2: 30.2 ms
- v3 engine: 77.6 ms
- overhead: 47.5 ms

## PASS/FAIL
- `sinc_generally_worsens_v3`: **FAIL**
- `clean_step_high_badge_v3`: **PASS**
- `strong_sinc_worse_than_clean_v3`: **FAIL**
- `unsharp_worse_than_clean_v3`: **PASS**
- `texture_not_false_strong_ringing_v3`: **FAIL**

## Recommendation
Ringing v3 needs further iteration before any promotion discussion.
