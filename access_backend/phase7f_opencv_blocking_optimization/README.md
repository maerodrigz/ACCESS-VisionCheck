# Phase 7F — OpenCV blocking vectorization

## Run verification (required for measured speedup numbers)

```bat
cd /d C:\Users\Dell\Desktop\access_mobile\access_backend
python -m pytest tests\test_opencv_blocking_vectorized_phase7f.py -q --tb=short
python scripts\verify_opencv_blocking_phase7f.py
type phase7f_opencv_blocking_optimization\PHASE7F_REPORT.md
```

## Rollback

In `app/services/opencv_quality.py` set:

```python
USE_VECTORIZED_BLOCKING = False
```

Loop reference remains as `_blocking_artifacts_loop_reference`.
