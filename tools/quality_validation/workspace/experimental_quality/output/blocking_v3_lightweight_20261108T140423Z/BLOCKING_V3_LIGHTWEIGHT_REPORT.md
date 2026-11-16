# Blocking v3 lightweight evaluation

Generated (UTC): 2026-11-08T14:04:24.739353+00:00
Overall: **PASS** (5 PASS / 0 FAIL)
Wall seconds: 0.845

## Diagnosis (v2)
v2 absolute smooth-weighted seam |Δ| confuses natural structure with JPEG blocking; ACCESS pilot humans mostly 4–5 while v2 under-scores clean photos (ρ ≈ −0.33).

## JPEG ladder (smooth gradient)

| Q | v2 amount | v2 badge | v3 amount | v3 badge |
|---:|---:|---:|---:|---:|
| 95 | 0.6537 | 5 | 0.3174 | 5 |
| 75 | 0.8748 | 5 | 1.5846 | 4 |
| 50 | 1.9948 | 4 | 4.2138 | 1 |
| 25 | 2.0067 | 4 | 3.3150 | 2 |
| 10 | 2.9382 | 3 | 6.4802 | 1 |

## Clean texture (JPEG Q95)
- v2 amount/badge: 14.4134 / 1
- v3 amount/badge: 0.0000 / 5

## Runtime (mean over ladder images)
- v2: 20.5 ms
- v3 engine: 129.4 ms
- overhead: 108.9 ms

## PASS/FAIL
- `jpeg_amounts_generally_worsen_v3`: **PASS**
- `q10_worse_than_q95_v3`: **PASS**
- `texture_not_false_strong_blocking_v3`: **PASS**
- `v3_separates_q95_q10`: **PASS**
- `v3_delta_competes_with_v2`: **PASS**

## Recommendation
Blocking v3 clears lightweight JPEG/texture gates; keep research-only. Do not replace v2 or ship to production without SPAQ/pilot approval.
