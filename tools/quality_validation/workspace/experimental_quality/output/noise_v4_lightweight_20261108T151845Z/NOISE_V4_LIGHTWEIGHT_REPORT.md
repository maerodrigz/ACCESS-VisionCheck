# Noise v4 lightweight evaluation

Overall: **PASS** (5/5 PASS)
Wall seconds: 3.391

Distinction: these gates measure **artifact detection** on synthetics, not ACCESS human rating accuracy.

## AWGN ladder
| sigma | v2 amt/badge | v3 amt/badge | v4 amt/badge | wavelet | ms_v4 |
|---:|---:|---:|---:|---:|---:|
| 0 | 0.000/5 | 0.000/5 | 0.000/5 | 0.000 | 45.1 |
| 5 | 1.854/5 | 5.670/3 | 4.508/4 | 2.965 | 48.5 |
| 10 | 3.603/4 | 10.650/1 | 9.015/2 | 6.672 | 54.9 |
| 20 | 7.226/2 | 21.301/1 | 18.030/1 | 13.343 | 46.1 |
| 40 | 14.292/1 | 42.752/1 | 36.560/1 | 26.687 | 47.9 |

## PASS/FAIL
- `awgn_monotone_v4`: **PASS**
- `chroma_raises_v4`: **PASS**
- `lowlight_monotone_v4`: **PASS**
- `texture_not_false_strong_v4`: **PASS**
- `wavelet_secondary_present`: **PASS**

## Runtime means (AWGN set): v2 21.7 ms, v3 126.4 ms, v4 48.5 ms

## Recommendation
Noise v4 clears lightweight artifact gates; research-only. Await approval before SPAQ/pilot.
