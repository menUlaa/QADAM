@echo off
echo ========================================
echo   Qadam Deploy
echo ========================================

set SERVER=root@109.235.118.172
set BACKEND_DIR=d:\projects\internship-platform\backend
set FLUTTER_DIR=d:\projects\internship-platform\mobile\internship_app2

echo.
echo [1/4] Building Flutter Web...
cd /d %FLUTTER_DIR%
call flutter build web --release
if errorlevel 1 (
    echo ERROR: Flutter build failed!
    pause
    exit /b 1
)

echo.
echo [2/4] Uploading Flutter Web to server...
scp -r %FLUTTER_DIR%\build\web\* %SERVER%:/app/web/
if errorlevel 1 (
    echo ERROR: Flutter upload failed!
    pause
    exit /b 1
)

echo.
echo [3/4] Uploading backend to server...
scp -r %BACKEND_DIR%\app %SERVER%:/app/backend/
if errorlevel 1 (
    echo ERROR: Backend upload failed!
    pause
    exit /b 1
)

echo.
echo [4/4] Restarting backend...
ssh %SERVER% "cd /app && docker compose restart backend"

echo.
echo ========================================
echo   Done! Site: http://109.235.118.172
echo ========================================
pause
