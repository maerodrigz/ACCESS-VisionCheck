@echo off
REM Phase 7B local verification. Does not edit .env or deploy.
cd /d C:\Users\Dell\Desktop\access_mobile\access_backend
if not exist scripts\_verify_out mkdir scripts\_verify_out
python scripts\verify_musiq_phase7b_media_evaluate.py > scripts\_verify_out\phase7b_stdout.txt 2>&1
echo EXIT_CODE=%ERRORLEVEL%
type scripts\_verify_out\phase7b_stdout.txt
