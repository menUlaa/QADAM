@echo off
echo ========================================
echo   Qadam Deploy Frontend
echo ========================================

set SERVER=root@109.235.118.172
set FLUTTER_DIR=d:\projects\internship-platform\mobile\internship_app2

echo.
echo [1/2] Building Flutter Web...
cd /d %FLUTTER_DIR%
call flutter build web --release
if errorlevel 1 (
    echo ERROR: Flutter build failed!
    pause
    exit /b 1
)

echo.
echo [2/2] Uploading to server...
scp -r %FLUTTER_DIR%\build\web\* %SERVER%:/app/web/

echo.
echo ========================================
echo   Done! http://109.235.118.172
echo ========================================
pause
