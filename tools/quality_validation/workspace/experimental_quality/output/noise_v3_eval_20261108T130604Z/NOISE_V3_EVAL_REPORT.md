# Noise v3 evaluation report

Generated (UTC): 2026-11-08T13:28:38.155887+00:00
Output: `C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\experimental_quality\output\noise_v3_eval_20261108T130604Z`

## Safety

- Production scoring unchanged.
- `experimental_quality_engine_v2.py` unchanged.
- Human CSVs and prior experiment outputs unchanged.
- Thresholds not fitted on SPAQ or ACCESS pilot.

## Diagnosis of v2 Noise

- Luma-only residual under-detects chroma noise.
- Homogeneous residual still admits texture/JPEG/sharpening leakage.
- ACCESS pilot often shows machine badge 5 when humans rate ~3 (under-detection).

## Synthetic results

- AWGN monotone v3: **True**
- Chroma v3 delta: **33.023** (v2 delta 0.084)
- Texture vs AWGN20 guard: **True**
- Low-light monotone v3: **True**

### AWGN ladder

| sigma | v2 amount | v2 badge | v3 amount | v3 badge |
|---:|---:|---:|---:|---:|
| 0 | 0.000 | 5 | 0.000 | 5 |
| 5 | 1.732 | 5 | 5.266 | 3 |
| 10 | 3.490 | 4 | 10.223 | 1 |
| 20 | 7.088 | 3 | 21.529 | 1 |
| 40 | 14.220 | 1 | 42.743 | 1 |

## SPAQ-200

- n_ok: 200
- mean ms/image v2: 2053.788191000058
- mean ms/image v3: 4291.001327499962
- runtime overhead (v3-v2) mean ms: 2237.213136499904
- badge hist v2: {'1': 0, '2': 1, '3': 6, '4': 23, '5': 170}
- badge hist v3: {'1': 0, '2': 0, '3': 0, '4': 11, '5': 189}
- SPAQ cleanliness Spearman v2: 0.3191655712781873
- SPAQ cleanliness Spearman v3: -0.03209944139794023

## ACCESS pilot (frozen secondary; not for tuning)

ACCESS pilot was not used to choose Noise v3 thresholds.
- Spearman v2: -0.25287816912705735 (n=30)
- Spearman v3: 0.2602684415255437 (n=30)

## PASS/FAIL

Overall: **MIXED**

- `synthetic_awgn_monotone_v3`: **PASS** — v3 amounts=[0.0, 5.2664826932676325, 10.223114262001014, 21.528667031018074, 42.74250131567876]
- `synthetic_chroma_sensitivity_v3`: **PASS** — v3_delta=33.023 v2_delta=0.084
- `synthetic_texture_not_false_strong_noise`: **PASS** — texture=0.613 awgn20=21.529
- `synthetic_lowlight_monotone_v3`: **PASS** — lowlight=[{'sigma': 0, 'v2_amount': 0.0, 'v2_badge': 5, 'v3_amount': 0.0, 'v3_badge': 5}, {'sigma': 6, 'v2_amount': 2.0697230317838144, 'v2_badge': 5, 'v3_amount': 6.902415123196321, 'v3_badge': 2}, {'sigma': 12, 'v2_amount': 4.197453874513756, 'v2_badge': 4, 'v3_amount': 13.373024405007996, 'v3_badge': 1}, {'sigma': 18, 'v2_amount': 6.260651558459536, 'v2_badge': 3, 'v3_amount': 20.87675947588268, 'v3_badge': 1}]
- `spaq_proxy_corr_nonnegative_v3`: **FAIL** — v2_rho=0.3191655712781873 v3_rho=-0.03209944139794023
- `spaq_proxy_corr_improved_or_close_v3`: **FAIL** — v2_rho=0.3191655712781873 v3_rho=-0.03209944139794023
- `access_pilot_corr_improved_descriptive`: **PASS** — v2_rho=-0.25287816912705735 v3_rho=0.2602684415255437 (not for tuning)
- `access_pilot_corr_nonnegative_v3`: **PASS** — v3_rho=0.2602684415255437

## Recommendation

Noise v3 does not yet clear enough gates for promotion. Keep v2 as fallback research baseline; iterate on flat-block / chroma estimation.

Do not integrate into production without approval.
