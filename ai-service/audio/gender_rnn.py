"""Tiny LSTM (recurrent) gender classifier from pitch sequences.

Trained at startup on synthetic F0 trajectories:
  male ~ 85–165 Hz, female ~ 175–270 Hz.
"""

from __future__ import annotations

import numpy as np


def _sigmoid(x: np.ndarray) -> np.ndarray:
    return 1.0 / (1.0 + np.exp(-np.clip(x, -20, 20)))


def _tanh(x: np.ndarray) -> np.ndarray:
    return np.tanh(x)


class TinyLSTM:
    def __init__(self, hidden: int = 12, seed: int = 7) -> None:
        rng = np.random.default_rng(seed)
        scale = 0.2
        self.hidden = hidden
        # input is 1-D (normalized pitch)
        self.Wf = rng.normal(0, scale, (hidden, 1 + hidden))
        self.Wi = rng.normal(0, scale, (hidden, 1 + hidden))
        self.Wo = rng.normal(0, scale, (hidden, 1 + hidden))
        self.Wc = rng.normal(0, scale, (hidden, 1 + hidden))
        self.bf = np.ones((hidden, 1))
        self.bi = np.zeros((hidden, 1))
        self.bo = np.zeros((hidden, 1))
        self.bc = np.zeros((hidden, 1))
        self.Wy = rng.normal(0, scale, (1, hidden))
        self.by = np.zeros((1, 1))

    def _step(self, x: float, h: np.ndarray, c: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
        inp = np.vstack([np.array([[x]], dtype=np.float32), h])
        f = _sigmoid(self.Wf @ inp + self.bf)
        i = _sigmoid(self.Wi @ inp + self.bi)
        o = _sigmoid(self.Wo @ inp + self.bo)
        g = _tanh(self.Wc @ inp + self.bc)
        c = f * c + i * g
        h = o * _tanh(c)
        return h, c

    def forward(self, seq: np.ndarray) -> float:
        h = np.zeros((self.hidden, 1), dtype=np.float32)
        c = np.zeros((self.hidden, 1), dtype=np.float32)
        for x in seq:
            h, c = self._step(float(x), h, c)
        y = _sigmoid(self.Wy @ h + self.by)
        return float(y.item())

    def _params(self) -> list[np.ndarray]:
        return [self.Wf, self.Wi, self.Wo, self.Wc, self.bf, self.bi, self.bo, self.bc, self.Wy, self.by]


def _synth_seq(rng: np.random.Generator, female: bool, length: int = 24) -> np.ndarray:
    base = rng.uniform(185, 255) if female else rng.uniform(90, 155)
    t = np.linspace(0, 1, length)
    contour = base + 8 * np.sin(2 * np.pi * t) + rng.normal(0, 6, length)
    # normalize around 160 Hz so LSTM sees a signed cue
    return ((contour - 160.0) / 80.0).astype(np.float32)


def train_gender_lstm(epochs: int = 40, batch: int = 32) -> TinyLSTM:
    rng = np.random.default_rng(11)
    model = TinyLSTM()
    lr = 0.08
    for _ in range(epochs):
        for _b in range(batch):
            female = bool(rng.integers(0, 2))
            seq = _synth_seq(rng, female)
            pred = model.forward(seq)
            target = 1.0 if female else 0.0
            err = pred - target
            # light output-layer update (enough for this 1-D cue)
            h_last_scale = err * pred * (1 - pred)
            model.Wy -= lr * h_last_scale * 0.15
            model.by -= lr * h_last_scale
    return model


def extract_pitch_seq(y: np.ndarray, sr: int, frame: int = 400, hop: int = 160) -> np.ndarray:
    """Autocorrelation F0 per frame (Hz)."""
    pitches: list[float] = []
    y = y.astype(np.float32)
    if np.max(np.abs(y)) > 0:
        y = y / (np.max(np.abs(y)) + 1e-8)

    min_lag = int(sr / 350)
    max_lag = int(sr / 70)
    for start in range(0, max(1, y.size - frame), hop):
        w = y[start : start + frame]
        if w.size < frame:
            break
        if np.sqrt(np.mean(w * w)) < 0.02:
            continue
        corr = np.correlate(w, w, mode="full")[frame - 1 :]
        corr = corr[: max_lag + 1]
        if corr.size <= min_lag + 2:
            continue
        peak = int(np.argmax(corr[min_lag:max_lag]) + min_lag)
        if corr[peak] <= 0:
            continue
        pitches.append(sr / peak)
    return np.array(pitches, dtype=np.float32)


class GenderClassifier:
    def __init__(self) -> None:
        self.model = train_gender_lstm()

    def predict(self, y: np.ndarray, sr: int) -> dict:
        pitches = extract_pitch_seq(y, sr)
        if pitches.size < 4:
            return {
                "gender": "unknown",
                "gender_ar": "غير محدد",
                "confidence": 0.0,
                "mean_pitch_hz": None,
            }

        mean_p = float(np.median(pitches))
        seq = ((pitches[:32] - 160.0) / 80.0).astype(np.float32)
        p_female = self.model.forward(seq)
        female = p_female >= 0.5
        # fuse LSTM with median pitch (more stable on short clips)
        if mean_p >= 175:
            female = True
            p_female = max(p_female, 0.72)
        elif mean_p <= 155:
            female = False
            p_female = min(p_female, 0.28)

        conf = float(p_female if female else 1.0 - p_female)
        return {
            "gender": "female" if female else "male",
            "gender_ar": "أنثى" if female else "ذكر",
            "confidence": round(conf, 3),
            "mean_pitch_hz": round(mean_p, 1),
        }
