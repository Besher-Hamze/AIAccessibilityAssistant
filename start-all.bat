@echo off
echo Starting all services...

rem Ollama on the integrated Intel Arc GPU (Vulkan): ~7x faster than CPU.
rem Restart it so these settings apply even if the tray app already started it.
taskkill /F /IM "ollama app.exe" >nul 2>&1
taskkill /F /IM ollama.exe >nul 2>&1
start "Ollama" cmd /k "set OLLAMA_VULKAN=1&& set OLLAMA_IGPU_ENABLE=1&& set OLLAMA_FLASH_ATTENTION=1&& set OLLAMA_KEEP_ALIVE=30m&& ollama serve"
timeout /t 3 /nobreak >nul

start "Backend" cmd /k "cd /d %~dp0backend && npm run start:dev"
timeout /t 3 /nobreak >nul
start "AI Voice" cmd /k "cd /d %~dp0ai-service && start.bat"
timeout /t 2 /nobreak >nul
@REM  rem nuget.exe (needed by flutter_tts on Windows) lives in %LOCALAPPDATA%\nuget
@REM  start "Flutter" cmd /k "set PATH=%LOCALAPPDATA%\nuget;%PATH% && cd /d %~dp0mobile && flutter run "

echo All services starting in separate windows...
