# Combined experimental engine evaluation

Generated (UTC): 2026-11-08T14:55:15.117840+00:00
Engine: `experimental_classical_combined_v1`
Verdict: **RESEARCH_CANDIDATE**

## Composition
- Sharpness / Blur / Noise / Brightness / Contrast: `experimental_classical_v2`
- Blocking Artifacts: `experimental_blocking_v3`
- Ringing Artifacts: `experimental_ringing_v3`
- Noise v3: alternate, not promoted

## Safety
- Production / Flutter / API / DB / human CSVs unchanged.
- Prior engine sources unchanged.
- SPAQ + pilot used diagnostically only (not for selecting thresholds).

## SPAQ-200 (diagnostic)
- n_ok: 200
- mean ms/image combined: 5363.497953000024
- wall seconds: 1073.79
- reused v2 cache: `C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\experimental_quality\output\exp_eval_v2_20261108T123035Z\spaq200_baseline_vs_experimental.csv`

- Sharpness: combined ρ=0.7489208918551082 | v2 ρ=0.7489208918551082 | production ρ=0.0857084463668399
- Noise_cleanliness: combined ρ=0.3191655712781873 | v2 ρ=0.3191655712781873 | production ρ=0.2641357168767402
- Brightness: combined ρ=0.4098933551855809 | v2 ρ=0.4098933551855809 | production ρ=0.045127906524004335
- Contrast: combined ρ=0.3246409153411303 | v2 ρ=0.3246409153411303 | production ρ=-0.027550646605560183

- Overall vs MOS: combined ρ=0.5602219970172676 | v2 ρ=0.5907023455961817 | production ρ=-0.06735113018967094

## ACCESS pilot (frozen secondary)
- n: 30 | mean ms: 2338.485966666849
- Sharpness: combined ρ=0.6225528619993459 | v2 ρ=0.6225528619993459 | production ρ=0.10398898634481626
- Blur: combined ρ=0.8238758407762933 | v2 ρ=0.8238758407762933 | production ρ=0.1603556138949095
- Noise: combined ρ=-0.25287816912705735 | v2 ρ=-0.25287816912705735 | production ρ=-0.2746790210287299
- Brightness: combined ρ=0.40261564670832034 | v2 ρ=0.40261564670832034 | production ρ=0.06356160452261518
- Contrast: combined ρ=0.34382360885315333 | v2 ρ=0.34382360885315333 | production ρ=0.09226196582883571
- Blocking Artifacts: combined ρ=0.21154925294066412 | v2 ρ=-0.3312060914612535 | production ρ=0.0008656835262990237
- Ringing Artifacts: combined ρ=-0.42235913379503526 | v2 ρ=-0.4015781930526186 | production ρ=0.012726710536180666
- Overall vs human: combined ρ=0.4295866448189961 | v2 ρ=0.3793077940337745 | production ρ=0.0350387203165264
- Overall feedback risk flags (min≤2 & overall≤3.5): 13

## Improvements
- Pilot Blocking Artifacts: combined ρ=0.212 > v2 ρ=-0.331

## Regressions
- (none clear)

## Unresolved
- Pilot Noise remains wrong-signed/inconclusive (ρ=-0.253); Noise v3 not promoted
- Pilot Ringing Artifacts: still non-positive vs humans (ρ=-0.422)

## Limitations
- SPAQ has no Blur/Blocking/Ringing attribute labels.
- ACCESS pilot n=30 is frozen secondary evidence, not tuning or final validation.
- Composition selected from prior research modules; these eval correlations are diagnostic only.
- Noise v3 not promoted (SPAQ/pilot tradeoffs unresolved).
- Combined computes v2's five retained heads only; Blocking/Ringing use v3 estimators (Blocking center-crops to ANALYSIS_CAP).

## Overall / skill-classification guidance
Do not map mean-of-seven overall directly to member skill tiers. Prefer per-criterion feedback; if an overall is shown, disclose it is an unweighted mean of proxies and can be dragged by a single defect head.

## Recommendation
Keep combined_v1 as the active research candidate for further diagnostic work. Do not ship to production: Blocking/Ringing human alignment remains provisional, Noise is unresolved, and mean-of-seven overall can mislead member feedback.

Do not integrate into production without approval.
