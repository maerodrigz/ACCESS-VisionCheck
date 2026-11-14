@echo off
REM Phase 7D performance benchmark. Does not edit .env or production scoring.
cd /d C:\Users\Dell\Desktop\access_mobile\access_backend
python scripts\benchmark_quality_engines_phase7d.py
echo EXIT_CODE=%ERRORLEVEL%
