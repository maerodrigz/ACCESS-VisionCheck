# Blocking v3 lightweight evaluation

Generated (UTC): 2026-11-08T14:02:03.467472+00:00
Overall: **MIXED** (4 PASS / 1 FAIL)
Wall seconds: 0.264

## Diagnosis (v2)
v2 absolute smooth-weighted seam |Δ| confuses natural structure with JPEG blocking; ACCESS pilot humans mostly 4–5 while v2 under-scores clean photos (ρ ≈ −0.33).

## JPEG ladder (smooth gradient)

| Q | v2 amount | v2 badge | v3 amount | v3 badge |
|---:|---:|---:|---:|---:|
| 95 | 0.6537 | 5 | 0.4804 | 5 |
| 75 | 0.8748 | 5 | 0.1248 | 5 |
| 50 | 1.9948 | 4 | 9407.2286 | 1 |
| 25 | 2.0067 | 4 | 78.3103 | 1 |
| 10 | 2.9382 | 3 | 8.3752 | 1 |

## Clean texture (JPEG Q95)
- v2 amount/badge: 14.4134 / 1
- v3 amount/badge: 0.0173 / 5

## Runtime (mean over ladder images)
- v2: 21.1 ms
- v3 engine: 18.8 ms
- overhead: -2.3 ms

## PASS/FAIL
- `jpeg_amounts_monotone_v3`: **FAIL**
- `jpeg_badges_monotone_v3`: **PASS**
- `q10_worse_than_q95_v3`: **PASS**
- `texture_not_false_strong_blocking_v3`: **PASS**
- `v3_separates_q95_q10`: **PASS**

## Recommendation
Blocking v3 needs further iteration before any promotion discussion.
