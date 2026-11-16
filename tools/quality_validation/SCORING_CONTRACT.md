# ACCESS VisionCheck — Quality scoring contract (as implemented)

This is a description of **current production code**, not a claim that the model is scientifically validated.

Source: `access_backend/app/services/media_evaluator.py`.

## What this is not

Quality evaluation is **not** AI-generated-content detection. PROBE / WaveRep / Gemini are separate pipelines and must not be used as quality ground truth.

## Photo criteria (7)

Displayed 1–5, **higher is better** for every name:

1. Sharpness
2. Blur (quality of low blur; high score means little blur)
3. Noise (quality of low noise; high score means clean image)
4. Brightness
5. Contrast
6. Blocking Artifacts (high score means few blocks)
7. Ringing Artifacts (high score means few halos)

## Video criteria (9)

The seven photo criteria, plus:

8. Flickering
9. Motion Stability

Video stills are scored with the same heads after FFmpeg (or OpenCV) frame extraction. Flicker and motion use frame-to-frame heuristics. Limited samples currently default some video-only scores (production `_flickering` / `_motion_stability` when fewer than 2 frames).

## Score range

- Rubric integers: **1, 2, 3, 4, 5**
- Mapping from continuous metrics uses `_soft_score` (unchanged for this study)
- Overall in the API payload: arithmetic **mean of the criterion integers**, rounded to 2 decimals, still on the 1–5 scale
- `legacy.overall_score` stores overall/5 (0–1)
- Stored DB `noise_score` is inverted (`1 - Noise/5`); member/admin **display** uses higher-is-better Noise

## Overall formula (system)

```
overall_score = mean(criterion.score for criterion in criteria)
```

Photo: mean of 7. Video: mean of 9. This **computed mean is not the same** as an independent human “overall visual quality” rating.

## Engines

1. Prefer EfficientNet-B0 (`efficientnet-b0`)
2. If that engine is unavailable or returns no metrics, OpenCV heuristics (`opencv`) with `analysis.opencv_fallback = true`
3. If both fail, evaluation is **failed / unavailable** (no invented 0.5)

This validation study must record the engine actually used.
