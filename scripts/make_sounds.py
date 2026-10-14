#!/usr/bin/env python3
"""Synthesises the instrument sounds used by SoundSpace (no samples, so no licensing questions).

Each drum is a sine wave whose pitch falls quickly (the 'thump' of a struck membrane) plus a short burst of
noise (the stick attack). Chimes are sums of inharmonic partials with a long decay (metal bars / bells).
The drum kit is built the same way (kick, snare, hi-hat, tom, crash) and the chord pads are three-note pads
with a few harmonics per note, so every chord of the synth is a small pre-rendered file.
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


def save(name, signal, peak=0.8, sr=SR):
    signal = signal / np.max(np.abs(signal)) * peak
    fade = int(sr * 0.01)
    signal[-fade:] *= np.linspace(1, 0, fade)                                              # fade out, no click
    data = (signal * 32767).astype("<i2")
    with wave.open(f"{OUT}/{name}.wav", "wb") as f:
        f.setnchannels(1)          # mono: required for good spatialisation
        f.setsampwidth(2)
        f.setframerate(sr)
        f.writeframes(data.tobytes())
    print(f"{name}.wav  {signal.size / sr:.2f}s")


# ---- Drum kit ---------------------------------------------------------------------------------------------

def bright_noise(seconds):
    """White noise with the low end taken out (first difference), so it sounds like cymbals and snare wires."""
    t = t_axis(seconds)
    n = rng.normal(0, 1, t.size)
    return np.diff(n, prepend=0), t


def snare():
    noise, t = bright_noise(0.28)
    tone = np.sin(2 * np.pi * 190 * t) * np.exp(-t * 28) * 0.7
    return noise * np.exp(-t * 17) + tone


def hihat():
    noise, t = bright_noise(0.1)
    return noise * np.exp(-t * 55)


def crash():
    noise, t = bright_noise(1.6)
    shimmer = sum(np.sin(2 * np.pi * f * t) for f in (3150, 4210, 5330, 6870)) * 0.25
    return (noise + shimmer) * np.exp(-t * 2.6) * np.minimum(1, t / 0.004)


# ---- Chord pads (the synth) -------------------------------------------------------------------------------

CHORD_SR = 22050            # chords have no content above a few kHz, so half the sample rate is plenty
NOTE_NAMES = ["C", "Cs", "D", "Ds", "E", "F", "Fs", "G", "Gs", "A", "As", "B"]


def chord_notes(pitch_class, quality):
    """Closed triad around middle C plus the root an octave lower. Returns MIDI note numbers."""
    base = 60 + pitch_class if pitch_class < 6 else 48 + pitch_class
    third = 4 if quality == "maj" else 3
    return [base - 12, base, base + third, base + 7]


def pad_voice(freq, t):
    """A soft, slightly detuned pad: a few harmonics with the higher ones fading out quickly (a low-pass feel)."""
    out = np.zeros_like(t)
    for detune in (-0.0025, 0.0025):
        for k in range(1, 7):
            out += (1.0 / k) * np.sin(2 * np.pi * freq * (1 + detune) * k * t) * np.exp(-t * (0.5 + 0.7 * k))
    return out


def chord(pitch_class, quality, seconds=2.8):
    t = np.arange(int(CHORD_SR * seconds)) / CHORD_SR
    sig = np.zeros_like(t)
    for i, midi in enumerate(chord_notes(pitch_class, quality)):
        freq = 440.0 * 2 ** ((midi - 69) / 12)
        sig += (0.6 if i == 0 else 1.0) * pad_voice(freq, t)
    sig *= np.minimum(1, t / 0.03)                     # 30 ms attack
    sig *= np.exp(-t * 0.35)                           # slow overall decay
    return sig


def make_all():
    # Existing instruments first and in the same order, so their (seeded) noise is unchanged.
    save("getabera", drum(150, 62, 0.9, 5.0, 0.35, 0.025))
    save("thammattama_high", drum(340, 190, 0.5, 9.0, 0.30, 0.015))
    save("thammattama_low", drum(230, 120, 0.6, 7.5, 0.30, 0.015))
    save("rabana", drum(200, 105, 0.7, 6.0, 0.45, 0.03, 0.9))
    save("chime_1", chime(880.0))
    save("chime_2", chime(1108.73))
    save("chime_3", chime(1318.51))
    # Drum kit
    save("kick", drum(150, 46, 0.5, 8.0, 0.25, 0.008))
    save("snare", snare())
    save("hihat", hihat(), peak=0.6)
    save("tom", drum(210, 105, 0.55, 7.0, 0.2, 0.012))
    save("crash", crash(), peak=0.7)
    # Chords: 12 roots x major / minor
    for pc in range(12):
        for quality in ("maj", "min"):
            save(f"chord_{pc}_{quality}", chord(pc, quality), peak=0.7, sr=CHORD_SR)


if __name__ == "__main__":
    make_all()
