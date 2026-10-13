#!/usr/bin/env python3
"""Synthesises the instrument sounds used by SoundSpace (no samples, so no licensing questions).

Each drum is a sine wave whose pitch falls quickly (the 'thump' of a struck membrane) plus a short burst of
noise (the stick attack). Chimes are sums of inharmonic partials with a long decay (metal bars / bells).
Run:  python3 scripts/make_sounds.py   (needs numpy)
"""
import wave
import numpy as np

SR = 44100
OUT = "SoundSpace/Resources/Sounds"
rng = np.random.default_rng(7)


def t_axis(seconds):
    return np.arange(int(SR * seconds)) / SR


def drum(f_start, f_end, seconds, decay, noise_amount, noise_decay=0.02, tone_mix=1.0):
    t = t_axis(seconds)
    freq = f_end + (f_start - f_end) * np.exp(-t * 25)         # pitch drops quickly
    phase = 2 * np.pi * np.cumsum(freq) / SR
    body = np.sin(phase) * np.exp(-t * decay) * tone_mix
    body += 0.35 * np.sin(2 * phase) * np.exp(-t * decay * 1.6)  # a little overtone
    attack = rng.normal(0, 1, t.size) * np.exp(-t / noise_decay) * noise_amount
    return body + attack


def chime(f0, seconds=1.8):
    t = t_axis(seconds)
    partials = [(1.0, 1.0, 2.2), (2.76, 0.5, 3.2), (5.4, 0.25, 5.0), (8.9, 0.1, 8.0)]   # ratio, level, decay
    sig = sum(level * np.sin(2 * np.pi * f0 * ratio * t) * np.exp(-t * decay) for ratio, level, decay in partials)
    sig *= np.minimum(1, t / 0.003)                                                       # 3 ms attack, no click
    return sig


def save(name, signal, peak=0.8):
    signal = signal / np.max(np.abs(signal)) * peak
    fade = int(SR * 0.01)
    signal[-fade:] *= np.linspace(1, 0, fade)                                              # fade out, no click
    data = (signal * 32767).astype("<i2")
    with wave.open(f"{OUT}/{name}.wav", "wb") as f:
        f.setnchannels(1)          # mono: required for good spatialisation
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(data.tobytes())
    print(f"{name}.wav  {signal.size / SR:.2f}s")


if __name__ == "__main__":
    save("getabera", drum(150, 62, 0.9, 5.0, 0.35, 0.025))
    save("thammattama_high", drum(340, 190, 0.5, 9.0, 0.30, 0.015))
    save("thammattama_low", drum(230, 120, 0.6, 7.5, 0.30, 0.015))
    save("rabana", drum(200, 105, 0.7, 6.0, 0.45, 0.03, 0.9))
    save("chime_1", chime(880.0))
    save("chime_2", chime(1108.73))
    save("chime_3", chime(1318.51))
