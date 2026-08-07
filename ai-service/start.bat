@echo off
cd /d "%~dp0"

if not exist ".venv\Scripts\activate.bat" (
    echo Virtual environment not found. Run setup.bat first.
    pause
    exit /b 1
)

call .venv\Scripts\activate.bat

for /f "tokens=5" %%a in ('netstat -ano ^| findstr :8000 ^| findstr LISTENING') do (
    echo Port 8000 is in use by PID %%a - stopping old instance...
    taskkill /F /PID %%a >nul 2>&1
    ping 127.0.0.1 -n 3 >nul
)

echo Starting AI Voice Service on http://localhost:8000
python main.py
