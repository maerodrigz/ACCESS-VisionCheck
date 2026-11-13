# ACCESS VisionCheck — Brightness/Contrast candidate diagnostic (research only)

**Generated:** 2026-11-08T01:13:54.376397+00:00

Research-only diagnostic. No production code/weights/thresholds changed. No SPAQ-200 access. No retraining. Candidate parameters are a-priori placeholders, **not** fit on these distortions; no winner is selected. Controlled distortions measure objective behavior, **not** perceptual accuracy. 
1-5 anchors [0.20,0.40,0.62,0.82] are TEMPORARY DIAGNOSTIC labels, unvalidated, not for production.

## Validation

- records: 280/280 **ok=True**; sources=40; variants=7; failures=0

## Mean by variant (across sources)

| Variant | luma_mean | luma_std | Q_B1 | Q_B2 | Q_C1 | Q_C2 | lbl_B1 | lbl_B2 | lbl_C1 | lbl_C2 | enet_B | opencv_B | enet_C | opencv_C |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| original | 0.4237 | 0.2373 | 0.563 | 0.5878 | 0.6536 | 0.4826 | 3.275 | 3.4 | 3.7 | 2.85 | 4.55 | 4.25 | 2.975 | 4.475 |
| underexposed | 0.2312 | 0.1305 | 0.3902 | 0.4169 | 0.5144 | 0.3966 | 2.4 | 2.575 | 2.925 | 2.425 | 4.7 | 3.575 | 3.05 | 3.525 |
| severely_underexposed | 0.1044 | 0.0592 | 0.1376 | 0.176 | 0.3302 | 0.2088 | 1.2 | 1.425 | 2.075 | 1.575 | 4.725 | 2.825 | 3.1 | 2.975 |
| overexposed | 0.5666 | 0.2731 | 0.4288 | 0.3735 | 0.6859 | 0.3066 | 2.575 | 2.35 | 3.75 | 1.9 | 4.425 | 3.85 | 3.05 | 4.675 |
| severely_overexposed | 0.6883 | 0.2607 | 0.2983 | 0.2658 | 0.6713 | 0.2423 | 1.975 | 1.775 | 3.825 | 1.525 | 4.425 | 3.45 | 3.025 | 4.725 |
| low_contrast | 0.4675 | 0.095 | 0.8764 | 0.8764 | 0.4379 | 0.4379 | 4.725 | 4.725 | 2.7 | 2.7 | 4.825 | 4.825 | 3.05 | 3.225 |
| excessively_high_contrast | 0.4035 | 0.3117 | 0.3362 | 0.2559 | 0.6985 | 0.1662 | 2.25 | 1.725 | 3.825 | 1.125 | 4.475 | 3.975 | 3.025 | 4.725 |

## Within-source direction (counts over evaluable sources)

brightness: drops_both = label(original) >= label(under) AND >= label(over); severe_*_low = <=2.
contrast: monotone = label(low) <= label(orig) <= label(excessive); drops_at_excessive = label(excessive) < label(orig).

| Series | n | drops_both / monotone | severe_under_low | severe_over_low | drops_at_excessive |
|---|---|---|---|---|---|
| brightness B1 | 40 | 27 | 40 | 32 | - |
| brightness B2 | 40 | 27 | 40 | 33 | - |
| brightness enet | 40 | 29 | 0 | 0 | - |
| brightness opencv | 40 | 29 | 7 | 4 | - |
| contrast C1 | 40 | 40 | - | - | 0 |
| contrast C2 | 40 | 2 | - | - | 31 |
| contrast enet | 40 | 34 | - | - | 2 |
| contrast opencv | 40 | 40 | - | - | 0 |

## False-positive risk (based on ORIGINAL images)

- high_key originals (luma_mean>0.65): 5
- low_key originals (luma_mean<0.25): 7
- naturally low-contrast originals (luma_std<0.10): 1

Potential false-positives (high/low key with NO clipped spike but B2 diagnostic label <= 2):
- high_key: 0 sources
- low_key: 4 sources

Note: intentionally high-key/low-key or flat scenes may receive low diagnostic labels. This is a known limitation of clipping/exposure heuristics; final tolerances require independent human-rated validation.

## Limitations

- Controlled distortions are diagnostic, not perceptual accuracy. No human ground-truth invented.
- Parameters are placeholders; do not deploy. No winner selected from these data.
- detail_mid_raw is diagnostic only and is NOT used in B/C quality.
- B2/C2 clipping heuristics can false-positive on intentional high-key/low-key or flat scenes.
- Video aggregation is NOT implemented. Future research alternatives: per-frame median(Q), lower-percentile(Q) for worst-frame sensitivity, and poor-frame-fraction (fraction of frames below a Q threshold).

No production code changed. No deploy or integration. Stopped for review.

Artifacts: `C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\datasets\brightness_contrast_candidates`
