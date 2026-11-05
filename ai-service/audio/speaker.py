"""Focus on one voice: keep the main speaker's speech, mute everyone else.

Uses a neural speaker-embedding model (NVIDIA TitaNet, ONNX via sherpa-onnx)
on the speech regions found by Silero VAD:

- With an enrolled voiceprint: keep only what matches that person.
- Without one: keep the speaker who talks the most in the recording.

Limit: it separates voices that take turns. Two people talking over each other
in the same moment cannot be split apart by this approach.
"""

from __future__ import annotations

import re
import urllib.request
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from faster_whisper.vad import VadOptions, get_speech_timestamps

SAMPLE_RATE = 16000
MODEL_NAME = "nemo_en_titanet_small.onnx"
MODEL_URL = (
    "https://github.com/k2-fsa/sherpa-onnx/releases/download/"
    f"speaker-recongition-models/{MODEL_NAME}"
)

WINDOW_S = 1.2
HOP_S = 0.6
MIN_WINDOW_S = 0.5
# Below this much speech (a word like "yes") a comparison is unreliable.
MIN_VERIFY_S = 0.6
MIN_ENROLL_S = 2.5

# Calibrated on real speakers: same-person windows p5=0.35, others p95=0.25.
PROFILE_THRESHOLD = 0.30
SAME_SPEAKER_THRESHOLD = 0.30
KEEP_NEAR_DOMINANT = 0.35
PAD_S = 0.12

_ID_RE = re.compile(r"^[A-Za-z0-9_-]{1,64}$")


@dataclass
class FocusResult:
    audio: np.ndarray
    mode: str  # off | no_speech | short | single | dominant | profile
    speakers: int = 1
    kept_ratio: float = 1.0
    rejected: bool = False
    similarity: float | None = None

    def info(self) -> dict:
        return {
            "speaker_focus": self.mode,
            "speakers_detected": self.speakers,
            "speech_kept_ratio": round(self.kept_ratio, 3),
            "speaker_rejected": self.rejected,
            "speaker_similarity": (
                None if self.similarity is None else round(self.similarity, 3)
            ),
        }


def _unit(v: np.ndarray) -> np.ndarray:
    n = float(np.linalg.norm(v))
    return v / n if n > 0 else v


def speech_spans(y: np.ndarray) -> list[tuple[int, int]]:
    spans = get_speech_timestamps(
        y, VadOptions(min_silence_duration_ms=250, speech_pad_ms=60)
    )
    return [(int(s["start"]), int(s["end"])) for s in spans]


class SpeakerFocus:
    def __init__(self, model_dir: Path, profiles_dir: Path) -> None:
        self.model_dir = Path(model_dir)
        self.profiles_dir = Path(profiles_dir)
        self._extractor = None
        self._load_failed = False

    def _get_extractor(self):
        if self._extractor is not None or self._load_failed:
            return self._extractor
        try:
            import sherpa_onnx

            path = self.model_dir / MODEL_NAME
            if not path.exists():
                self.model_dir.mkdir(parents=True, exist_ok=True)
                print(f"Downloading speaker model: {MODEL_NAME} ...")
                urllib.request.urlretrieve(MODEL_URL, path)
            self._extractor = sherpa_onnx.SpeakerEmbeddingExtractor(
                sherpa_onnx.SpeakerEmbeddingExtractorConfig(
                    model=str(path), num_threads=2
                )
            )
            print("Speaker focus ready.")
        except Exception as exc:
            # Transcription must keep working without this feature.
            self._load_failed = True
            print(f"Speaker focus unavailable: {exc}")
        return self._extractor

    @property
    def available(self) -> bool:
        return self._get_extractor() is not None

    def _embed(self, y: np.ndarray) -> np.ndarray:
        ex = self._get_extractor()
        stream = ex.create_stream()
        stream.accept_waveform(SAMPLE_RATE, np.asarray(y, dtype=np.float32))
        stream.input_finished()
        return _unit(np.array(ex.compute(stream), dtype=np.float32))

    # ── voiceprints ──

    def _profile_path(self, speaker_id: str) -> Path | None:
        if not speaker_id or not _ID_RE.match(speaker_id):
            return None
        return self.profiles_dir / f"{speaker_id}.npy"

    def has_profile(self, speaker_id: str | None) -> bool:
        path = self._profile_path(speaker_id or "")
        return bool(path and path.exists())

    def enroll(self, y: np.ndarray, speaker_id: str) -> dict:
        path = self._profile_path(speaker_id)
        if path is None:
            raise ValueError("Invalid speaker id")
        if not self.available:
            raise RuntimeError("Speaker model is not available")
        spans = speech_spans(y)
        speech = (
            np.concatenate([y[a:b] for a, b in spans]) if spans else np.zeros(0)
        )
        seconds = speech.size / SAMPLE_RATE
        if seconds < MIN_ENROLL_S:
            return {"ok": False, "speech_seconds": round(seconds, 2)}
        self.profiles_dir.mkdir(parents=True, exist_ok=True)
        np.save(path, self._embed(speech))
        return {"ok": True, "speech_seconds": round(seconds, 2)}

    def delete_profile(self, speaker_id: str) -> bool:
        path = self._profile_path(speaker_id)
        if path and path.exists():
            path.unlink()
            return True
        return False

    # ── focusing ──

    @staticmethod
    def _windows(spans: list[tuple[int, int]]) -> list[tuple[int, int, int, int]]:
        """Returns (start, end, keep_start, keep_end): a window is embedded over
        start..end, and decides the fate of the samples in keep_start..keep_end."""
        size = int(WINDOW_S * SAMPLE_RATE)
        hop = int(HOP_S * SAMPLE_RATE)
        out = []
        for a, b in spans:
            if b - a <= size:
                if b - a >= MIN_WINDOW_S * SAMPLE_RATE:
                    out.append((a, b, a, b))
                continue
            starts = list(range(a, b - size + 1, hop))
            if starts[-1] + size < b:
                starts.append(b - size)
            for i, s in enumerate(starts):
                keep_a = a if i == 0 else s + (size - hop) // 2
                keep_b = b if i == len(starts) - 1 else s + (size - hop) // 2 + hop
                out.append((s, s + size, keep_a, keep_b))
        return out

    def focus(self, y: np.ndarray, speaker_id: str | None = None) -> FocusResult:
        spans = speech_spans(y)
        if not spans:
            return FocusResult(np.zeros_like(y), "no_speech", speakers=0, kept_ratio=0.0)
        if not self.available:
            return FocusResult(y, "off")

        speech_s = sum(b - a for a, b in spans) / SAMPLE_RATE
        windows = self._windows(spans)
        if speech_s < MIN_VERIFY_S or not windows:
            return FocusResult(y, "short")

        embs = np.stack([self._embed(y[w[0] : w[1]]) for w in windows])

        path = self._profile_path(speaker_id or "")
        if path and path.exists():
            scores = embs @ np.load(path)
            keep = scores >= PROFILE_THRESHOLD
            best = float(scores.max())
            if not keep.any():
                return FocusResult(
                    np.zeros_like(y), "profile", kept_ratio=0.0, rejected=True,
                    similarity=best,
                )
            return self._apply(y, windows, keep, "profile", 1, best)

        labels, centroids = self._cluster(embs)
        if len(centroids) == 1:
            return FocusResult(y, "single")
        counts = np.bincount(labels, minlength=len(centroids))
        main = int(np.argmax(counts))
        # A voice that shifts a little between windows must not lose words.
        keep = (labels == main) | (embs @ centroids[main] >= KEEP_NEAR_DOMINANT)
        # One odd window between two kept ones is the same person, not a guest.
        for i in range(1, len(keep) - 1):
            if not keep[i] and keep[i - 1] and keep[i + 1]:
                keep[i] = True
        if keep.all():
            return FocusResult(y, "single")
        return self._apply(y, windows, keep, "dominant", len(centroids), None)

    @staticmethod
    def _cluster(embs: np.ndarray) -> tuple[np.ndarray, list[np.ndarray]]:
        centroids: list[np.ndarray] = []
        members: list[list[int]] = []
        labels = np.zeros(len(embs), dtype=int)
        for i, e in enumerate(embs):
            sims = [float(e @ c) for c in centroids]
            if sims and max(sims) >= SAME_SPEAKER_THRESHOLD:
                k = int(np.argmax(sims))
                members[k].append(i)
                centroids[k] = _unit(embs[members[k]].mean(axis=0))
            else:
                k = len(centroids)
                centroids.append(e)
                members.append([i])
            labels[i] = k
        # Re-assign once against the final centroids (early ones were noisy).
        for i, e in enumerate(embs):
            labels[i] = int(np.argmax([float(e @ c) for c in centroids]))
        return labels, centroids

    @staticmethod
    def _apply(y, windows, keep, mode, speakers, similarity) -> FocusResult:
        mask = np.zeros(y.size, dtype=np.float32)
        pad = int(PAD_S * SAMPLE_RATE)
        kept = 0
        total = 0
        for (_, _, a, b), k in zip(windows, keep):
            total += b - a
            if k:
                kept += b - a
                mask[max(0, a - pad) : min(y.size, b + pad)] = 1.0
        return FocusResult(
            y * mask, mode, speakers, kept / total if total else 0.0, False, similarity
        )
