"""Noise reduction: high-pass filter + spectral gating."""

from __future__ import annotations

import numpy as np
from scipy.signal import butter, sosfilt


def highpass(y: np.ndarray, sr: int, cutoff: float = 80.0) -> np.ndarray:
    sos = butter(4, cutoff, btype="highpass", fs=sr, output="sos")
    return sosfilt(sos, y).astype(np.float32)


def spectral_gate(y: np.ndarray, sr: int, n_fft: int = 512, hop: int = 128) -> np.ndarray:
    """Keep bins that stay above a noise-floor estimate (median magnitude)."""
    if y.size < n_fft:
        return y

    window = np.hanning(n_fft).astype(np.float32)
    frames = []
    for start in range(0, y.size - n_fft + 1, hop):
        frames.append(y[start : start + n_fft] * window)
    if not frames:
        return y

    spec = np.fft.rfft(np.stack(frames), axis=1)
    mag = np.abs(spec)
    noise = np.median(mag, axis=0, keepdims=True)
    mask = (mag > (noise * 1.8)).astype(np.float32)
    if mask.shape[0] >= 3:
        mask[1:-1] = (mask[:-2] + mask[1:-1] + mask[2:]) / 3.0
    cleaned = spec * mask
    rec_frames = np.fft.irfft(cleaned, n=n_fft, axis=1)

    out = np.zeros(y.size, dtype=np.float32)
    wsum = np.zeros(y.size, dtype=np.float32)
    for i, start in enumerate(range(0, y.size - n_fft + 1, hop)):
        out[start : start + n_fft] += rec_frames[i] * window
        wsum[start : start + n_fft] += window
    wsum[wsum == 0] = 1
    return (out / wsum).astype(np.float32)


def denoise(y: np.ndarray, sr: int) -> np.ndarray:
    y = y.astype(np.float32)
    peak = np.max(np.abs(y)) + 1e-8
    y = y / peak
    y = highpass(y, sr)
    y = spectral_gate(y, sr)
    peak2 = np.max(np.abs(y)) + 1e-8
    return (y / peak2 * 0.95).astype(np.float32)
