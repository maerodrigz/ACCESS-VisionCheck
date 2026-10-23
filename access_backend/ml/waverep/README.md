# WaveRep G4 assets

Layout (required by `waverep_detector.py`):

```
ml/waverep/
  waverep_detector.py
  demo/
    utils.py
    weights/
      weights_dinov2_G4.ckpt
```

Checkpoint (~330 MB) is gitignored. After copy, verify SHA-256 matches your source project.

Keep `WAVEREP_ENABLED=false` until dependency install and smoke tests pass. See `access_backend/docs/WAVEREP_INTEGRATION.md`.
