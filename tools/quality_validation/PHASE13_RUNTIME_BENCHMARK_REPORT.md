# Phase 13 runtime benchmark: technical image quality on SPAQ-200

**Generated:** 2026-11-07T13:32:03.005667+00:00

Per-stage latency (decode / resize / OpenCV analysis / Tenengrad) at 512 / 1024 / 1600 px longest side, plus exploratory Spearman vs the existing SPAQ human ratings. No thresholds fitted. No EfficientNet, MUSIQ, or WaveRep inference. No production code changes. No dataset download. Phase 10-12 outputs untouched.

## Environment

| Key | Value |
|---|---|
| python | `3.12.10` |
| platform | `Windows-11-10.0.26200-SP0` |
| cpu_count | `8` |
| cv2 | `5.0.0` |
| numpy | `2.5.4` |
| PIL | `13.0.0` |

## Config

| Key | Value |
|---|---|
| images_dir | `C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\datasets\spaq\images` |
| csv | `C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\datasets\spaq\output\run_001\spaq_200_machine_scores.csv` |
| sizes | `[512, 1024, 1600]` |
| repeat | `3` |
| limit | `None` |
| warmup | `1` |
| inter | `area` |
| output_dir | `c:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\datasets\spaq\output\phase13_run_001` |
| no_correlation | `False` |
- images_found: `200`
- images_scored: `200`
- failures: `0`

## Latency by stage and size (ms, over per-image stage medians)

Decode is size-independent (decoded once at native resolution); the same decode value is shown for every size for completeness.

| Stage | Size | n | min | mean | median | p95 | max |
|---|---|---|---|---|---|---|---|
| decode | 512 | 200 | 102.4856 | 271.43 | 266.112 | 393.9678 | 583.261 |
| resize | 512 | 200 | 2.4567 | 15.9113 | 14.8202 | 26.6206 | 31.8716 |
| opencv | 512 | 200 | 41.2822 | 70.9643 | 70.0129 | 91.7961 | 132.201 |
| tenengrad | 512 | 200 | 1.7088 | 4.6987 | 4.5878 | 6.1582 | 8.1071 |
| pipeline | 512 | 200 | 178.5834 | 363.0043 | 355.6424 | 520.221 | 693.1211 |
| decode | 1024 | 200 | 102.4856 | 271.43 | 266.112 | 393.9678 | 583.261 |
| resize | 1024 | 200 | 4.7775 | 15.1893 | 15.0851 | 21.3156 | 27.6265 |
| opencv | 1024 | 200 | 169.8741 | 290.4258 | 292.2355 | 355.3098 | 413.0433 |
| tenengrad | 1024 | 200 | 12.6703 | 18.8767 | 18.9474 | 21.827 | 30.9967 |
| pipeline | 1024 | 200 | 343.9625 | 595.922 | 594.011 | 761.4068 | 945.971 |
| decode | 1600 | 200 | 102.4856 | 271.43 | 266.112 | 393.9678 | 583.261 |
| resize | 1600 | 200 | 8.7012 | 18.1867 | 17.8959 | 25.4182 | 32.9168 |
| opencv | 1600 | 200 | 419.2261 | 695.5938 | 701.5144 | 816.1273 | 980.9506 |
| tenengrad | 1600 | 200 | 26.7502 | 44.0971 | 44.6627 | 52.5641 | 73.9519 |
| pipeline | 1600 | 200 | 613.8561 | 1029.3076 | 1029.6216 | 1248.1901 | 1466.6961 |

## Exploratory rank correlation vs SPAQ human ratings (no fitting)

| Size | Metric | n | Spearman r | 95% CI | Pearson r |
|---|---|---|---|---|---|
| 512 | opencv_sharpness | 200 | 0.7222304223646215 | 0.6546668078462878, 0.7750511527474332 | 0.7138020366524346 |
| 512 | opencv_noise | 200 | 0.6837816715662347 | 0.5860184953192591, 0.7510026238110279 | 0.6263280594057553 |
| 512 | tenengrad | 200 | 0.6602502297935603 | 0.5711675587969973, 0.7374621948851624 | 0.5537190022548758 |
| 512 | opencv_contrast | 200 | 0.28534990198096705 | 0.16356978337003664, 0.40680278043915447 | 0.33623386670732097 |
| 512 | opencv_brightness | 200 | 0.14962061764850595 | -0.004941556998809317, 0.2941415624030751 | 0.1713695809616195 |
| 1024 | opencv_sharpness | 200 | 0.7441998015551505 | 0.6853438638888596, 0.7961235401646494 | 0.7480576334177566 |
| 1024 | opencv_noise | 200 | 0.6823138782663175 | 0.6005114202257121, 0.7451143590496501 | 0.6374639941560187 |
| 1024 | tenengrad | 200 | 0.7529416794328195 | 0.6789386339430699, 0.798856659350841 | 0.5414538064501235 |
| 1024 | opencv_contrast | 200 | 0.29914787677906546 | 0.18009140022801032, 0.42337223695077447 | 0.35263016366846295 |
| 1024 | opencv_brightness | 200 | 0.14962061764850595 | -0.004941556998809317, 0.2941415624030751 | 0.17137009159712993 |
| 1600 | opencv_sharpness | 200 | 0.7133727069717782 | 0.6433111619479984, 0.7748787920484388 | 0.7059110500672047 |
| 1600 | opencv_noise | 200 | 0.6695380013778199 | 0.5912292007049975, 0.7271262420280955 | 0.6271972210135704 |
| 1600 | tenengrad | 200 | 0.7666873297750029 | 0.7075185369730622, 0.8118118299577036 | 0.536372852782963 |
| 1600 | opencv_contrast | 200 | 0.30742787706873925 | 0.1867633073640717, 0.42850423300184903 | 0.36018075088389256 |
| 1600 | opencv_brightness | 200 | 0.14962061764850595 | -0.004941556998809317, 0.2941415624030751 | 0.1713780356894285 |

Correlations are exploratory and computed on the locked SPAQ-200. They are NOT used to fit thresholds, 1-5 maps, or calibration. No production decision is made here.

## Failures

None.

No production code was changed. No Phase 10-12 result was modified.

Artifacts: `c:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\datasets\spaq\output\phase13_run_001`
