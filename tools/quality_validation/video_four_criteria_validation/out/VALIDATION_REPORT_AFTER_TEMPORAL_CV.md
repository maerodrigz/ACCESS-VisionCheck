# After: Classical Motion / Flicker Heuristics

**Date:** 2026-11-09  
**Change:** `video_temporal_quality_criteria.py` wired into `evaluate_video` only.

## Before → after (same controlled clips)

| Criterion | Clip | Before | After | Notes |
|---|---|---:|---:|---|
| Motion Stability | baseline | 5 | 5 | Stable still |
| Motion Stability | geometric shake | 5 | **4** | Direction improved (was unchanged) |
| Motion Stability | variable blur | 5 | 4 | Still responds |
| Flickering | baseline | 5 | 5 | Steady |
| Flickering | mild sine | 5 | 5 | Sparse samples still miss mild oscillation |
| Flickering | extreme dark/bright | 5 | **2** | Fixed ENET-brightness blindness |
| Color Balance / Saturation | all prior cases | unchanged | unchanged | 5→4 tint, N/A desat, 5→3 oversat |

Determinism: identical across 2 runs for every clip.

## Runtime

- Temporal criteria alone (~4 frames @320px): ~**20 ms**/call average
- Full `evaluate_video` (ENET + authenticity deferred): ~**12 s** dominated by ENET, not temporal CV

## Limitations

- Sparse FFmpeg samples (~4) still miss mild high-frequency flicker.
- Geometric shake only dropped one level (5→4); thresholds are experimental.
- Feature tracking can return N/A on low texture; does not invent 5/5.
- Not scientifically validated against human ratings.
