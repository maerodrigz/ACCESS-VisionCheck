# Phase 7G — Cutover verification outputs

```bat
cd /d C:\Users\Dell\Desktop\access_mobile\access_backend
scripts\run_phase7g_regression.bat
```

Or:

```bat
cd /d C:\Users\Dell\Desktop\access_mobile\access_backend
python -m pytest tests\test_musiq_cutover_phase7g.py tests\test_musiq_quality_phase7a.py tests\test_opencv_blocking_vectorized_phase7f.py tests\test_media_quality_eval_correctness.py tests\test_musiq_worker_client.py -q --tb=short
python scripts\verify_musiq_cutover_phase7g.py
type phase7g_musiq_cutover_verification\PHASE7G_REPORT.md
```

Does **not** modify `.env`. Production cutover stays off until `cutover_ready: true` and you explicitly set `QUALITY_ENGINE=musiq_worker`.
