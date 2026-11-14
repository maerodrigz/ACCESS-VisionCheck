@echo off
REM Phase 7G regression + cutover verification. Does not edit .env.
cd /d C:\Users\Dell\Desktop\access_mobile\access_backend
python -m pytest tests\test_musiq_quality_phase7a.py tests\test_musiq_cutover_phase7g.py tests\test_opencv_blocking_vectorized_phase7f.py tests\test_media_quality_eval_correctness.py tests\test_musiq_worker_client.py tests\test_musiq_shadow_worker_integration.py -q --tb=short
echo PYTEST_EXIT=%ERRORLEVEL%
python scripts\verify_musiq_cutover_phase7g.py
echo VERIFY_EXIT=%ERRORLEVEL%
type phase7g_musiq_cutover_verification\PHASE7G_REPORT.md
