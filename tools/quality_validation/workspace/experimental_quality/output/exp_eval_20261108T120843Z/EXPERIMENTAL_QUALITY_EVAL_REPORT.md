# Experimental photo-quality engine evaluation

Generated (UTC): 2026-11-08T12:12:04.180724+00:00
Experimental engine: `experimental_classical_v1`

## Safety

- Production scoring, Run 001/002 folders, and human CSVs were not modified.
- Experimental scales are a priori (not fitted on SPAQ-200 or the ACCESS pilot).
- SPAQ attributes are related proxies, not ACCESS rubric labels.
- Blur / Blocking / Ringing have no SPAQ attribute ground truth here.

## SPAQ-200 runtime

- n_ok: 200 / 200
- wall seconds: 191.685
- mean ms/image: 949.45595

## Badge distributions (baseline production vs experimental)

- **Sharpness**: baseline unique=3 {'1': 0, '2': 1, '3': 154, '4': 45, '5': 0}; experimental unique=5 {'1': 31, '2': 46, '3': 33, '4': 41, '5': 49}
- **Blur**: baseline unique=3 {'1': 0, '2': 2, '3': 180, '4': 18, '5': 0}; experimental unique=1 {'1': 0, '2': 0, '3': 0, '4': 0, '5': 200}
- **Noise**: baseline unique=3 {'1': 0, '2': 0, '3': 67, '4': 129, '5': 4}; experimental unique=2 {'1': 0, '2': 0, '3': 0, '4': 7, '5': 193}
- **Brightness**: baseline unique=3 {'1': 0, '2': 0, '3': 2, '4': 52, '5': 146}; experimental unique=5 {'1': 10, '2': 19, '3': 26, '4': 58, '5': 87}
- **Contrast**: baseline unique=3 {'1': 0, '2': 20, '3': 174, '4': 6, '5': 0}; experimental unique=5 {'1': 2, '2': 15, '3': 36, '4': 78, '5': 69}
- **Blocking Artifacts**: baseline unique=2 {'1': 0, '2': 0, '3': 131, '4': 69, '5': 0}; experimental unique=1 {'1': 0, '2': 0, '3': 0, '4': 0, '5': 200}
- **Ringing Artifacts**: baseline unique=2 {'1': 0, '2': 0, '3': 94, '4': 106, '5': 0}; experimental unique=5 {'1': 72, '2': 30, '3': 36, '4': 39, '5': 23}

## SPAQ attribute Spearman (proxy human labels)

| Pair | Baseline ρ | Experimental ρ | n |
|---|---:|---:|---:|
| Sharpness | 0.086 | 0.749 | 200 |
| Noise_cleanliness | 0.264 | 0.206 | 200 |
| Brightness | 0.045 | 0.410 | 200 |
| Contrast | -0.028 | 0.325 | 200 |

## Overall vs SPAQ MOS (exploratory; different constructs)

- Baseline ρ: -0.067
- Experimental ρ: 0.264

## Controlled-distortion diagnostics

- `gaussian_blur` primary `blur` sequence: []
- `awgn` primary `noise` sequence: []
- `jpeg` primary `blocking` sequence: []
- `underexposure` primary `brightness` sequence: []
- `overexposure` primary `brightness` sequence: []

## ACCESS pilot frozen secondary check

ACCESS pilot was not used to select experimental scales. These correlations are descriptive only and are not an unbiased claim of improvement.

| Criterion | Baseline ρ | Experimental ρ | n |
|---|---:|---:|---:|
| Sharpness | 0.104 | 0.623 | 30 |
| Blur | 0.160 | N/A | 30 |
| Noise | -0.275 | -0.314 | 30 |
| Brightness | 0.064 | 0.403 | 30 |
| Contrast | 0.092 | 0.344 | 30 |
| Blocking Artifacts | 0.001 | 0.183 | 30 |
| Ringing Artifacts | 0.013 | -0.564 | 30 |

## Recommendation

Experimental v1 shows mixed SPAQ-proxy results (some gains, some losses). Do not replace production scoring.

- Do not auto-integrate into production from this run alone.
- Preserve production EfficientNet + `_soft_score` until ACCESS-criterion humans on a held-out set show stable gains.
- Experimental engine increases ordinal spread via equal-bin mapping and classical proxies.
- SPAQ proxy Spearman improved for: Sharpness (0.086→0.749), Brightness (0.045→0.410), Contrast (-0.028→0.325)
- SPAQ proxy Spearman worsened for: Noise_cleanliness (0.264→0.206)
- Broader experimental badge support on: Sharpness, Brightness, Contrast, Ringing Artifacts
- Blocking/Ringing remain proxies; edge-Laplacian ringing can confuse texture with halos.
- Blur remains a focus-related proxy, not a validated motion-blur detector.
- Next smallest step: freeze experimental v1, collect more ACCESS-rubric labels on a disjoint set, then re-evaluate without retuning.
