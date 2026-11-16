@echo off
REM Phase 7H video + authenticity verification. Does not edit .env.
cd /d C:\Users\Dell\Desktop\access_mobile\access_backend
python scripts\verify_phase7h_video_authenticity.py
echo VERIFY_EXIT=%ERRORLEVEL%
type phase7h_video_authenticity_verification\PHASE7H_REPORT.md
