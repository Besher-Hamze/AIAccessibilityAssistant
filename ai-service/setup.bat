@echo off
echo ========================================
echo  AI Voice Service Setup
echo ========================================

cd /d "%~dp0"

if not exist ".venv" (
    echo Creating Python virtual environment...
    python -m venv .venv
)

call .venv\Scripts\activate.bat

echo Installing dependencies...
pip install -r requirements.txt

if not exist ".env" (
    copy .env.example .env
    echo Created .env from .env.example
)

echo.
echo Downloading Whisper model on first run...
python -c "from faster_whisper import WhisperModel; WhisperModel('base', device='cpu', compute_type='int8', download_root='models')"

echo.
echo ========================================
echo  Setup complete! Run: start.bat
echo ========================================
pause
