"""AI Voice Service - Whisper STT + Edge TTS for Arabic."""

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

MODELS_DIR = Path(__file__).parent / "models"
MODELS_DIR.mkdir(exist_ok=True)


class Settings(BaseSettings):
    whisper_model: str = "base"
    whisper_device: str = "cpu"
    whisper_compute_type: str = "int8"
    tts_voice: str = "ar-SA-HamedNeural"
    host: str = "0.0.0.0"
    port: int = 8000

    class Config:
        env_file = ".env"
        extra = "ignore"


settings = Settings()
whisper_model = None


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
    try:
        load_whisper()
    except Exception as exc:
        print(f"Warning: Could not preload Whisper: {exc}")
    yield


app = FastAPI(
    title="AI Accessibility Voice Service",
    description="Speech-to-Text (Whisper) and Text-to-Speech (Edge TTS) for Arabic",
    version="1.0.0",
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


@app.get("/health")
async def health():
    return {
        "ok": True,
        "whisper_model": settings.whisper_model,
        "tts_voice": settings.tts_voice,
        "whisper_loaded": whisper_model is not None,
    }


@app.post("/stt")
async def speech_to_text(file: UploadFile = File(...)):
    if not file.filename:
        raise HTTPException(status_code=400, detail="No audio file provided")

    suffix = Path(file.filename).suffix or ".wav"
    content = await file.read()

    if len(content) == 0:
        raise HTTPException(status_code=400, detail="Empty audio file")

    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        tmp.write(content)
        tmp_path = tmp.name

    try:
        model = load_whisper()
        segments, info = model.transcribe(
            tmp_path,
            language="ar",
            beam_size=5,
            vad_filter=True,
        )

        text = " ".join(segment.text.strip() for segment in segments).strip()

        return {
            "text": text,
            "language": info.language,
            "language_probability": round(info.language_probability, 3),
        }
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    finally:
        os.unlink(tmp_path)


@app.post("/tts")
async def text_to_speech(request: TtsRequest):
    voice = request.voice or settings.tts_voice

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
