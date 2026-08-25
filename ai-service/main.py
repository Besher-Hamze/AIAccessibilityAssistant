"""AI Voice Service: denoise + LSTM gender + Whisper STT + Edge TTS."""

from __future__ import annotations

import io
import os
import tempfile
import uuid
from contextlib import asynccontextmanager
from pathlib import Path

import edge_tts
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field
from pydantic_settings import BaseSettings

from audio.gender_rnn import GenderClassifier
from audio.pipeline import VoicePipeline

MODELS_DIR = Path(__file__).parent / "models"
MODELS_DIR.mkdir(exist_ok=True)


class Settings(BaseSettings):
    whisper_model: str = "medium"
    whisper_device: str = "cpu"
    whisper_compute_type: str = "int8"
    tts_voice: str = "ar-SA-HamedNeural"
    tts_voice_female: str = "ar-SA-ZariyahNeural"
    host: str = "0.0.0.0"
    port: int = 8000

    class Config:
        env_file = ".env"
        extra = "ignore"


settings = Settings()
whisper_model = None
pipeline: VoicePipeline | None = None


def load_whisper():
    global whisper_model
    if whisper_model is not None:
        return whisper_model

    from faster_whisper import WhisperModel

    print(f"Loading Whisper model: {settings.whisper_model}...")
    whisper_model = WhisperModel(
        settings.whisper_model,
        device=settings.whisper_device,
        compute_type=settings.whisper_compute_type,
        download_root=str(MODELS_DIR),
    )
    print("Whisper model loaded.")
    return whisper_model


@asynccontextmanager
async def lifespan(app: FastAPI):
    global pipeline
    pipeline = VoicePipeline(GenderClassifier())
    print("Gender LSTM ready.")
    try:
        load_whisper()
    except Exception as exc:
        print(f"Warning: Could not preload Whisper: {exc}")
    yield


app = FastAPI(
    title="AI Accessibility Voice Service",
    description="Denoise + LSTM gender + Whisper STT + Edge TTS",
    version="2.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


class TtsRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=5000)
    voice: str | None = None
    gender: str | None = None


@app.get("/health")
async def health():
    return {
        "ok": True,
        "whisper_model": settings.whisper_model,
        "tts_voice": settings.tts_voice,
        "whisper_loaded": whisper_model is not None,
        "denoise": "spectral_gating",
        "gender_model": "tiny_lstm",
    }


@app.post("/stt")
async def speech_to_text(file: UploadFile = File(...)):
    if not file.filename:
        raise HTTPException(status_code=400, detail="No audio file provided")

    suffix = Path(file.filename).suffix or ".wav"
    content = await file.read()
    if len(content) == 0:
        raise HTTPException(status_code=400, detail="Empty audio file")

    tmp_path = None
    clean_path = None
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
            tmp.write(content)
            tmp_path = tmp.name

        model = load_whisper()
        assert pipeline is not None

        try:
            audio_path, gender = pipeline.prepare(tmp_path)
            clean_path = audio_path
        except Exception:
            audio_path = tmp_path
            gender = {
                "gender": "unknown",
                "gender_ar": "غير محدد",
                "confidence": 0.0,
                "mean_pitch_hz": None,
            }

        text, confidence, raw = pipeline.transcribe(model, audio_path)

        return {
            "text": text,
            "raw_text": raw,
            "confidence": confidence,
            "language": "ar",
            "denoised": clean_path is not None,
            **gender,
        }
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    finally:
        for p in (tmp_path, clean_path):
            if p and os.path.exists(p):
                try:
                    os.unlink(p)
                except OSError:
                    pass


@app.post("/tts")
async def text_to_speech(request: TtsRequest):
    voice = request.voice
    if not voice:
        if (request.gender or "").lower() == "female":
            voice = settings.tts_voice_female
        else:
            voice = settings.tts_voice

    try:
        communicate = edge_tts.Communicate(request.text, voice)
        audio_buffer = io.BytesIO()
        async for chunk in communicate.stream():
            if chunk["type"] == "audio":
                audio_buffer.write(chunk["data"])
        audio_buffer.seek(0)
        return StreamingResponse(
            audio_buffer,
            media_type="audio/mpeg",
            headers={
                "Content-Disposition": f'inline; filename="speech_{uuid.uuid4().hex[:8]}.mp3"'
            },
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@app.get("/voices")
async def list_voices():
    voices = await edge_tts.list_voices()
    arabic_voices = [v for v in voices if v["Locale"].startswith("ar")]
    return {"voices": arabic_voices[:20]}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "main:app",
        host=settings.host,
        port=settings.port,
        reload=False,
    )
