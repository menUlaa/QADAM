@echo off
echo ========================================
echo   Qadam Deploy Backend
echo ========================================

set SERVER=root@109.235.118.172
set BACKEND_DIR=d:\projects\internship-platform\backend

echo.
echo [1/2] Uploading backend...
scp -r %BACKEND_DIR%\app %SERVER%:/app/backend/

echo.
echo [2/2] Restarting backend...
ssh %SERVER% "cd /app && docker compose restart backend"

echo.
echo ========================================
echo   Done!
echo ========================================
pause
