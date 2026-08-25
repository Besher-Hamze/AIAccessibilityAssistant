@echo off
echo Starting all services...

start "Backend" cmd /k "cd /d %~dp0backend && npm run start:dev"
timeout /t 3 /nobreak >nul
start "AI Voice" cmd /k "cd /d %~dp0ai-service && start.bat"
timeout /t 2 /nobreak >nul
start "Flutter" cmd /k "cd /d %~dp0mobile && flutter run "

echo All services starting in separate windows...
