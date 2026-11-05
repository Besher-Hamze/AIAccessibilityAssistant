"""AI Voice Service: speaker focus + denoise + LSTM gender + Whisper STT + Edge TTS."""

from __future__ import annotations

import io
import os
import tempfile
import uuid
from contextlib import asynccontextmanager
from pathlib import Path

import edge_tts
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field
from pydantic_settings import BaseSettings

from audio.gender_rnn import GenderClassifier
from audio.pipeline import VoicePipeline, load_wav_16k
from audio.speaker import SpeakerFocus

MODELS_DIR = Path(__file__).parent / "models"
MODELS_DIR.mkdir(exist_ok=True)
VOICEPRINTS_DIR = Path(__file__).parent / "voiceprints"


class Settings(BaseSettings):
    whisper_model: str = "small"
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
    speaker = SpeakerFocus(MODELS_DIR / "speaker", VOICEPRINTS_DIR)
    pipeline = VoicePipeline(GenderClassifier(), speaker)
    print("Gender LSTM ready.")
    _ = speaker.available  # load (or download) the model before the first request
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
        "speaker_focus": pipeline is not None and pipeline.speaker.available,
    }


@app.post("/stt")
async def speech_to_text(
    file: UploadFile = File(...),
    speaker_id: str | None = Form(None),
):
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

        focus_info: dict = {"speaker_focus": "off"}
        try:
            audio_path, gender, focus = pipeline.prepare(tmp_path, speaker_id)
            clean_path = audio_path
            focus_info = focus.info()
            # Nothing to transcribe: Whisper would only invent text from noise.
            if focus.rejected or focus.mode == "no_speech":
                return {
                    "text": "",
                    "raw_text": "",
                    "confidence": 0.0,
                    "language": "ar",
                    "denoised": True,
                    **gender,
                    **focus_info,
                }
        except Exception as exc:
            print(f"Audio preparation failed, using the raw recording: {exc}")
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
            **focus_info,
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


@app.post("/voiceprint")
async def enroll_voiceprint(
    file: UploadFile = File(...),
    speaker_id: str = Form(...),
):
    """Saves this person's voice so the app listens only to them."""
    content = await file.read()
    if len(content) == 0:
        raise HTTPException(status_code=400, detail="Empty audio file")
    tmp_path = None
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as tmp:
            tmp.write(content)
            tmp_path = tmp.name
        assert pipeline is not None
        return pipeline.speaker.enroll(load_wav_16k(tmp_path), speaker_id)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    finally:
        if tmp_path and os.path.exists(tmp_path):
            os.unlink(tmp_path)


@app.get("/voiceprint/{speaker_id}")
async def voiceprint_status(speaker_id: str):
    assert pipeline is not None
    return {
        "enrolled": pipeline.speaker.has_profile(speaker_id),
        "available": pipeline.speaker.available,
    }


@app.delete("/voiceprint/{speaker_id}")
async def delete_voiceprint(speaker_id: str):
    assert pipeline is not None
    return {"deleted": pipeline.speaker.delete_profile(speaker_id)}


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
