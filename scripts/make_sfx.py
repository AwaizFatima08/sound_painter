#!/usr/bin/env python3
"""Synthesise the app's short sound effects into assets/audio/sfx/ (soft, never startling)."""
import pathlib
import wave

import numpy as np

SR = 24000
OUT = pathlib.Path(__file__).resolve().parent.parent / "assets" / "audio" / "sfx"


def env(n, attack=0.005, decay=None):
    t = np.arange(n) / SR
    a = np.minimum(1, t / attack)
    d = np.exp(-t / decay) if decay else np.ones(n)
    return a * d


def bell(freq, dur, decay, partials=((1, 1), (2.01, 0.35), (3.02, 0.12))):
    n = int(dur * SR)
    t = np.arange(n) / SR
    y = sum(amp * np.sin(2 * np.pi * freq * m * t) for m, amp in partials)
    return y * env(n, decay=decay)


def place(total, parts):
    y = np.zeros(int(total * SR))
    for start, sig in parts:
        i = int(start * SR)
        y[i:i + len(sig)] += sig[:len(y) - i]
    return y


def save(name, y, peak=0.6):
    y = y / (np.abs(y).max() + 1e-9) * peak
    fade = int(0.01 * SR)
    y[-fade:] *= np.linspace(1, 0, fade)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((y * 32767).astype(np.int16).tobytes())


OUT.mkdir(parents=True, exist_ok=True)
# pop: tiny pitched bubble
n = int(0.12 * SR)
t = np.arange(n) / SR
f = 600 + 900 * np.exp(-t / 0.02)
save("pop", np.sin(2 * np.pi * np.cumsum(f) / SR) * env(n, 0.002, 0.03), 0.5)
# chime: two soft bells (C6, G6)
save("chime", place(1.4, [(0, bell(1046.5, 1.4, 0.35)), (0.12, bell(1568, 1.2, 0.3))]), 0.5)
# sparkle: quick rising glints
save("sparkle", place(0.9, [(i * 0.06, bell(1500 * 1.12 ** i, 0.5, 0.08)) for i in range(8)]), 0.45)
# whoosh: soft filtered noise swell
n = int(0.6 * SR)
rng = np.random.default_rng(1)
noise = rng.standard_normal(n)
k = np.ones(40) / 40
wh = np.convolve(noise, k, "same") * np.sin(np.pi * np.arange(n) / n) ** 2
save("whoosh", wh, 0.35)
# tada: gentle major arpeggio C5 E5 G5 C6
notes = [523.25, 659.25, 783.99, 1046.5]
save("tada", place(2.0, [(i * 0.13, bell(fq, 1.6, 0.45)) for i, fq in enumerate(notes)]), 0.55)
print("sfx written to", OUT)
