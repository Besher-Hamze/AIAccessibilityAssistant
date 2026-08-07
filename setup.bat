@echo off
echo ========================================
echo  AI Accessibility Assistant - Setup
echo ========================================

cd /d "%~dp0"

echo.
echo [1/4] Backend setup...
cd backend
if not exist ".env" copy .env.example .env
call npm install
call npx prisma generate
echo.
echo Run database migration manually after PostgreSQL is ready:
echo   cd backend ^&^& npx prisma migrate dev --name init ^&^& npm run prisma:seed
cd ..

echo.
echo [2/4] AI Voice Service setup...
cd ai-service
if exist setup.bat call setup.bat
cd ..

echo.
echo [3/4] Flutter setup...
cd mobile
call flutter pub get
cd ..

echo.
echo [4/4] Ollama model...
where ollama >nul 2>&1
if %ERRORLEVEL%==0 (
    echo Pulling qwen2.5:7b model...
    ollama pull qwen2.5:7b
) else (
    echo Ollama not found. Install from https://ollama.com
)

echo.
echo ========================================
echo  Setup complete!
echo.
echo  Start services:
echo    1. PostgreSQL (or docker compose up -d)
echo    2. cd backend ^&^& npm run start:dev
echo    3. cd ai-service ^&^& start.bat
echo    4. cd mobile ^&^& flutter run
echo ========================================
pause
