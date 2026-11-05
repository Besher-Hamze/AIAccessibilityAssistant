"""STT pipeline: speaker focus → denoise → gender LSTM → Whisper → Arabic correction."""

from __future__ import annotations

import re
from collections import Counter
from pathlib import Path

import numpy as np
from scipy.io import wavfile
from scipy.signal import resample_poly

from .arabic_corrector import correct_arabic
from .denoise import denoise
from .gender_rnn import GenderClassifier
from .speaker import SAMPLE_RATE, FocusResult, SpeakerFocus

# Biases Whisper toward the app's vocabulary (accounting + voice navigation).
ACCOUNTING_PROMPT = (
    "أوامر محاسبة عربية: أضف عميل، أنشئ فاتورة، اعرض المنتجات، "
    "ملخص المحاسبة، تقرير الفواتير المعلقة والمدفوعة، مخزون، "
    "محمد الأحمد، علي الحسين، برنامج محاسبة، خدمة استشارية. "
    "افتح العملاء، روح عالفواتير، افتح المنتجات، الإعدادات، الرئيسية، "
    "انزل لتحت، اطلع لفوق، ارجع، اقرأ الشاشة، اسكت، يا مساعد."
)

# Whisper repeats its prompt or loops a phrase when it hears noise, not speech.
_MAX_NO_SPEECH_PROB = 0.6
_MIN_AVG_LOGPROB = -1.0
_MAX_COMPRESSION_RATIO = 2.4


def _norm_words(text: str) -> list[str]:
    t = re.sub(r"[ً-ْـ]", "", text)
    t = re.sub("[إأآ]", "ا", t).replace("ة", "ه").replace("ى", "ي")
    t = re.sub(r"[^\w\s]", " ", t)
    return t.split()


_PROMPT_WORDS = set(_norm_words(ACCOUNTING_PROMPT))


def is_hallucination(text: str) -> bool:
    """True for transcripts that echo the prompt or loop the same phrase."""
    words = _norm_words(text)
    if len(words) >= 8:
        in_prompt = sum(w in _PROMPT_WORDS for w in words) / len(words)
        if in_prompt >= 0.85:
            return True
    if len(words) >= 6:
        grams = Counter(tuple(words[i : i + 2]) for i in range(len(words) - 1))
        if grams.most_common(1)[0][1] >= 3:
            return True
    return False


def load_wav(path: str) -> tuple[np.ndarray, int]:
    sr, data = wavfile.read(path)
    if data.ndim > 1:
        data = data.mean(axis=1)
    if np.issubdtype(data.dtype, np.integer):
        y = data.astype(np.float32) / float(np.iinfo(data.dtype).max)
    else:
        y = data.astype(np.float32)
    return y, int(sr)


def load_wav_16k(path: str) -> np.ndarray:
    y, sr = load_wav(path)
    if sr != SAMPLE_RATE:
        y = resample_poly(y, SAMPLE_RATE, sr).astype(np.float32)
    return y


def save_wav(path: str, y: np.ndarray, sr: int) -> None:
    clipped = np.clip(y, -1.0, 1.0)
    pcm = (clipped * 32767).astype(np.int16)
    wavfile.write(path, sr, pcm)


class VoicePipeline:
    def __init__(self, gender: GenderClassifier, speaker: SpeakerFocus) -> None:
        self.gender = gender
        self.speaker = speaker

    def prepare(
        self, src_path: str, speaker_id: str | None = None
    ) -> tuple[str, dict, FocusResult]:
        y = load_wav_16k(src_path)
        focus = self.speaker.focus(y, speaker_id)
        y_clean = denoise(focus.audio, SAMPLE_RATE)
        gender = self.gender.predict(y_clean, SAMPLE_RATE)
        out = str(Path(src_path).with_name(Path(src_path).stem + "_clean.wav"))
        save_wav(out, y_clean, SAMPLE_RATE)
        return out, gender, focus

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
            if (
                seg.no_speech_prob > _MAX_NO_SPEECH_PROB
                or seg.avg_logprob < _MIN_AVG_LOGPROB
                or seg.compression_ratio > _MAX_COMPRESSION_RATIO
            ):
                continue
            raw_parts.append(raw)
            parts.append(correct_arabic(raw))
            if getattr(seg, "avg_logprob", None) is not None:
                # map logprob (~ -1..0) to 0..1
                confs.append(float(min(1.0, max(0.0, 1.0 + seg.avg_logprob))))

        raw = " ".join(raw_parts).strip()
        text = correct_arabic(" ".join(parts))
        if is_hallucination(text):
            return "", 0.0, raw
        confidence = round(sum(confs) / len(confs), 3) if confs else 0.0
        return text, confidence, raw
