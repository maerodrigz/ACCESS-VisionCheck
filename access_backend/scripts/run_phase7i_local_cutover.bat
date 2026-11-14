@echo off
REM Phase 7I controlled LOCAL cutover. Does not deploy to cloud.
REM Backs up .env, sets QUALITY_ENGINE=musiq_worker, restarts FastAPI, runs smoke tests.
REM On critical smoke failure: restores .env and restarts FastAPI.
setlocal EnableExtensions
cd /d C:\Users\Dell\Desktop\access_mobile\access_backend

if not exist phase7i_local_cutover mkdir phase7i_local_cutover

echo === 1) Backup .env and apply QUALITY_ENGINE=musiq_worker ===
python scripts\apply_phase7i_local_cutover_env.py
if errorlevel 1 (
  echo APPLY_ENV_FAILED
  exit /b 1
)

echo === 2) Check Docker MUSIQ worker on 127.0.0.1:8080 ===
curl -s -o phase7i_local_cutover\worker_ready.json -w "READY_HTTP=%%{http_code}\n" http://127.0.0.1:8080/ready
if errorlevel 1 (
  echo WORKER_CURL_FAILED - start worker with:
  echo   cd /d C:\Users\Dell\Desktop\access_mobile\musiq_worker
  echo   docker compose up -d
  echo Restoring .env because worker is unavailable.
  python scripts\apply_phase7i_local_cutover_env.py --restore
  exit /b 2
)

echo === 3) Restart local FastAPI on port 3001 ===
REM Stop listeners on 3001 (existing manage.py runserver / uvicorn).
for /f "tokens=5" %%P in ('netstat -ano ^| findstr :3001 ^| findstr LISTENING') do (
  echo Stopping PID %%P on :3001
  taskkill /PID %%P /F >nul 2>&1
)
timeout /t 2 /nobreak >nul
start "ACCESS-FastAPI-Phase7I" cmd /k "cd /d C:\Users\Dell\Desktop\access_mobile\access_backend && python manage.py runserver"
echo Waiting for /api/health ...
set HEALTH_OK=0
for /l %%I in (1,1,30) do (
  curl -s -o nul -w "%%{http_code}" http://127.0.0.1:3001/api/health | findstr /r "^200$" >nul
  if not errorlevel 1 (
    set HEALTH_OK=1
    goto :health_done
  )
  timeout /t 2 /nobreak >nul
)
:health_done
if "%HEALTH_OK%"=="0" (
  echo FASTAPI_HEALTH_FAILED - restoring .env
  python scripts\apply_phase7i_local_cutover_env.py --restore
  for /f "tokens=5" %%P in ('netstat -ano ^| findstr :3001 ^| findstr LISTENING') do taskkill /PID %%P /F >nul 2>&1
  timeout /t 2 /nobreak >nul
  start "ACCESS-FastAPI-Rollback" cmd /k "cd /d C:\Users\Dell\Desktop\access_mobile\access_backend && python manage.py runserver"
  exit /b 3
)

echo === 4) Smoke verify cutover (loads .env; temporary docker stop for offline) ===
python scripts\verify_phase7i_local_cutover.py
set VERIFY_EXIT=%ERRORLEVEL%
echo VERIFY_EXIT=%VERIFY_EXIT%

if not "%VERIFY_EXIT%"=="0" (
  echo === CRITICAL SMOKE FAILED - restore .env and restart FastAPI ===
  python scripts\apply_phase7i_local_cutover_env.py --restore
  for /f "tokens=5" %%P in ('netstat -ano ^| findstr :3001 ^| findstr LISTENING') do taskkill /PID %%P /F >nul 2>&1
  timeout /t 2 /nobreak >nul
  start "ACCESS-FastAPI-Rollback" cmd /k "cd /d C:\Users\Dell\Desktop\access_mobile\access_backend && python manage.py runserver"
  type phase7i_local_cutover\PHASE7I_REPORT.md
  exit /b %VERIFY_EXIT%
)

type phase7i_local_cutover\PHASE7I_REPORT.md
echo PHASE7I_LOCAL_CUTOVER_OK
exit /b 0
