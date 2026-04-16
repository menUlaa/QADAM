@echo off
echo Starting Qadam...

start "Qadam Backend" cmd /k "cd /d %~dp0backend && python -m uvicorn app.main:app --reload --port 8000"

timeout /t 3 /nobreak > nul

start "Qadam Frontend" cmd /k "cd /d %~dp0mobile\internship_app2 && flutter run -d chrome --web-port 3000"
