#!/usr/bin/env python3
"""Encode art/voice/*.wav (Gemini TTS masters) to assets/audio/voice/*.mp3.

48 kbps mono MP3 is ~8x smaller than the WAV masters and plenty for speech.
Needs the `lameenc` package (pip install lameenc, e.g. in a venv).
"""
import pathlib
import wave

import lameenc

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "art" / "voice"
OUT = ROOT / "assets" / "audio" / "voice"

OUT.mkdir(parents=True, exist_ok=True)
for f in sorted(SRC.glob("*.wav")):
    with wave.open(str(f)) as w:
        assert w.getnchannels() == 1 and w.getsampwidth() == 2
        rate, pcm = w.getframerate(), w.readframes(w.getnframes())
    enc = lameenc.Encoder()
    enc.set_bit_rate(48)
    enc.set_in_sample_rate(rate)
    enc.set_channels(1)
    enc.set_quality(2)
    (OUT / f"{f.stem}.mp3").write_bytes(enc.encode(pcm) + enc.flush())
print("encoded", len(list(OUT.glob("*.mp3"))), "voice lines")
