"""STT pipeline: denoise → gender LSTM → Whisper → Arabic correction."""

from __future__ import annotations

from pathlib import Path

import numpy as np
from scipy.io import wavfile

from .arabic_corrector import correct_arabic
from .denoise import denoise
from .gender_rnn import GenderClassifier

ACCOUNTING_PROMPT = (
    "أوامر محاسبة عربية: أضف عميل، أنشئ فاتورة، اعرض المنتجات، "
    "ملخص المحاسبة، تقرير الفواتير المعلقة والمدفوعة، مخزون، "
    "محمد الأحمد، علي الحسين، برنامج محاسبة، خدمة استشارية."
)


def load_wav(path: str) -> tuple[np.ndarray, int]:
    sr, data = wavfile.read(path)
    if data.ndim > 1:
        data = data.mean(axis=1)
    if np.issubdtype(data.dtype, np.integer):
        y = data.astype(np.float32) / float(np.iinfo(data.dtype).max)
    else:
        y = data.astype(np.float32)
    return y, int(sr)


def save_wav(path: str, y: np.ndarray, sr: int) -> None:
    clipped = np.clip(y, -1.0, 1.0)
    pcm = (clipped * 32767).astype(np.int16)
    wavfile.write(path, sr, pcm)


class VoicePipeline:
    def __init__(self, gender: GenderClassifier) -> None:
        self.gender = gender

    def prepare(self, src_path: str) -> tuple[str, dict]:
        y, sr = load_wav(src_path)
        y_clean = denoise(y, sr)
        gender = self.gender.predict(y_clean, sr)
        out = str(Path(src_path).with_name(Path(src_path).stem + "_clean.wav"))
        save_wav(out, y_clean, sr)
        return out, gender

    def transcribe(self, model, audio_path: str) -> tuple[str, float, str]:
        segments, info = model.transcribe(
            audio_path,
            language="ar",
            beam_size=5,
            temperature=0.0,
            vad_filter=True,
            vad_parameters={"min_silence_duration_ms": 350},
            condition_on_previous_text=False,
            initial_prompt=ACCOUNTING_PROMPT,
        )

        parts: list[str] = []
        confs: list[float] = []
        raw_parts: list[str] = []
        for seg in segments:
            raw = (seg.text or "").strip()
            if not raw:
                continue
            raw_parts.append(raw)
            parts.append(correct_arabic(raw))
            if getattr(seg, "avg_logprob", None) is not None:
                # map logprob (~ -1..0) to 0..1
                confs.append(float(min(1.0, max(0.0, 1.0 + seg.avg_logprob))))

        raw = " ".join(raw_parts).strip()
        text = correct_arabic(" ".join(parts))
        confidence = round(sum(confs) / len(confs), 3) if confs else 0.0
        return text, confidence, raw
