# EfficientNet-B0 — archived research executables

EfficientNet-B0 was permanently removed from ACCESS VisionCheck production and from
executable research imports (2026-11).

## Preserved here

Obsolete training / diagnose scripts that previously depended on
`access_backend/app/services/efficientnet_b0_scorer.py` and
`access_backend/ml/efficientnet_b0_heads.pt`.

These scripts are **not** part of the supported evaluation path. They are kept
only as historical research evidence of how the retired model was trained or diagnosed.

## Still in the main tree (evidence, not executable ENET)

- Historical Markdown/JSON reports under `tools/quality_validation/`
- Dataset outputs and SHA256 of former weights recorded in
  `SEVEN_METRIC_RESEARCH_CONSOLIDATED_REPORT.md`
- `EFFICIENTNET_B0_FROZEN_STATUS.md` (status document; model no longer loadable)

## Current quality path

`QUALITY_ENGINE=musiq_worker` (MUSIQ primary, local OpenCV fallback).
