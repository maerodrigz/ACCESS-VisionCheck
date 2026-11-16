# Ringing v4 lightweight evaluation

Overall: **PASS** (6/6 PASS)
Wall seconds: 1.131

Distinction: these gates measure **artifact detection** on synthetics, not ACCESS human rating accuracy.

## Sinc ladder
| sev | v2 amt/badge | v3 amt/badge | v4 amt/badge | bipolar | ms_v4 |
|---:|---:|---:|---:|---:|---:|
| 0 | 0.000/5 | 0.000/5 | 0.000/5 | 0 | 52.0 |
| 1 | 7.000/4 | 15.677/2 | 19.019/1 | 154 | 42.5 |
| 2 | 0.000/5 | 29.232/1 | 28.000/1 | 58 | 39.9 |
| 3 | 0.000/5 | 28.222/1 | 28.000/1 | 29 | 19.5 |

## Unsharp ladder
| amt | v2 | v3 | v4 |
|---:|---:|---:|---:|
| 0.0 | 0.000/5 | 0.000/5 | 0.000/5 |
| 1.2 | 3.333/5 | 27.878/1 | 28.000/1 |
| 2.4 | 6.333/4 | 25.400/1 | 28.000/1 |

## PASS/FAIL
- `clean_step_high_badge_v4`: **PASS**
- `sinc_generally_worsens_v4`: **PASS**
- `unsharp_generally_worsens_v4`: **PASS**
- `texture_not_false_strong_v4`: **PASS**
- `jpeg_not_strong_ringing_v4`: **PASS**
- `limitation_reported_without_edges`: **PASS**

## Runtime means (sinc set): v2 45.6 ms, v3 53.9 ms, v4 38.5 ms

## Recommendation
Ringing v4 clears lightweight artifact gates; research-only. Await approval before SPAQ/pilot.
