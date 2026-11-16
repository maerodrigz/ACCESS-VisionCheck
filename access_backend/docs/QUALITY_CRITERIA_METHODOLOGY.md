# Quality criteria methodology (developer notes)

Member-facing criterion cards intentionally omit research jargon. Technical
details stay here so product copy can stay short and clear.

## Motion Stability / Flickering

- Classical OpenCV heuristics on **sparse FFmpeg-sampled frames** (often ~4).
- Not a full optical-stabilization analysis or calibrated flicker meter.
- Sparse sampling limits sensitivity to high-frequency flicker; gradual
  exposure ramps are softened so ordinary fades are not scored as flicker.
- `estimate_kind` remains `heuristic_experimental` in API payloads for
  tooling; do not surface that string in member UI.

## Color Balance / Color Saturation

- OpenCV LAB / HSV heuristics. Thresholds are documented constants in
  `color_quality_criteria.py`, not human-validated aesthetic scores.
- Grayscale / extreme luma cases may return N/A rather than a low score.

## Scoring engines

- Do not change MUSIQ / OpenCV / PROBE / WaveRep / Clarity v2 (EfficientNet-B0 is retired from production)
  algorithms when editing user-facing explanation text.
