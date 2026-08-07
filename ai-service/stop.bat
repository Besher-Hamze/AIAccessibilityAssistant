@echo off
cd /d "%~dp0"
echo Stopping AI Voice Service on port 8000...

for /f "tokens=5" %%a in ('netstat -ano ^| findstr :8000 ^| findstr LISTENING') do (
    echo Killing process PID %%a
    taskkill /F /PID %%a >nul 2>&1
)

echo Done.
