@echo off
REM READ-ONLY storage audit. Does not delete/move/modify project data.
REM Writes only: _storage_audit_raw.json (size inventory) then you can open STORAGE_CLEANUP_AUDIT.md after the agent finalizes it.
cd /d C:\Users\Dell\Desktop\access_mobile
powershell -NoProfile -ExecutionPolicy Bypass -File ".\_storage_audit_scan.ps1"
echo.
echo Also run Docker read-only:
docker system df
docker system df -v
docker images
docker volume ls
pause
