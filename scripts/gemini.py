#!/usr/bin/env python3
"""Build-time Gemini helpers for Sound Painter: images, speech and music.

Never used at runtime. The key lives in .secrets/gemini_api_key (gitignored).

  python3 scripts/gemini.py image "<prompt>" out.png [--ref a.png ...] [--aspect 1:1]
  python3 scripts/gemini.py tts "<text>" out.wav [--voice Sulafat] [--style "..."]
  python3 scripts/gemini.py music "<prompt>" out.wav
"""
import argparse
import base64
import http.client
import json
import pathlib
import sys
import time
import urllib.error
import urllib.request
import wave

ROOT = pathlib.Path(__file__).resolve().parent.parent
KEY = (ROOT / ".secrets" / "gemini_api_key").read_text().strip()
API = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"

IMAGE_MODEL = "gemini-3-pro-image"
TTS_MODEL = "gemini-3.8-flash-tts"
MUSIC_MODEL = "lyria-3.5"


def call(model, body, retries=4):
    req = urllib.request.Request(
        API.format(model=model),
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json", "x-goog-api-key": KEY},
    )
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(req, timeout=300) as r:
                return json.load(r)
        except urllib.error.HTTPError as e:
            msg = e.read().decode()[:400]
            if e.code in (429, 500, 503) and attempt < retries - 1:
                time.sleep(10 * (attempt + 1))
                continue
            sys.exit(f"Gemini {model} HTTP {e.code}: {msg}")
        except (http.client.IncompleteRead, ConnectionError, TimeoutError, urllib.error.URLError) as e:
            if attempt < retries - 1:
                time.sleep(10 * (attempt + 1))
                continue
            sys.exit(f"Gemini {model} network error: {e}")
    sys.exit("Gemini: out of retries")


def inline_parts(resp):
    for cand in resp.get("candidates", []):
        for part in cand.get("content", {}).get("parts", []):
            if "inlineData" in part:
                yield part["inlineData"]


def image(prompt, out, refs=(), aspect="1:1"):
    parts = [{"text": prompt}]
    for ref in refs:
        parts.append({"inlineData": {"mimeType": "image/png",
                                     "data": base64.b64encode(pathlib.Path(ref).read_bytes()).decode()}})
    resp = call(IMAGE_MODEL, {
        "contents": [{"parts": parts}],
        "generationConfig": {"responseModalities": ["IMAGE"],
                             "imageConfig": {"aspectRatio": aspect, "imageSize": "2K"}},
    })
    for d in inline_parts(resp):
        pathlib.Path(out).write_bytes(base64.b64decode(d["data"]))
        return
    sys.exit(f"No image returned: {json.dumps(resp)[:400]}")


def write_pcm_wav(out, pcm, rate):
    with wave.open(str(out), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(pcm)


def tts(text, out, voice="Sulafat", style=None):
    # The style goes in a leading [bracket tag]; written as a plain sentence,
    # the model reads it aloud as part of the line.
    style = style or "slow, warm and clear, like a kind teacher talking to a four-year-old"
    resp = call(TTS_MODEL, {
        "contents": [{"parts": [{"text": f"[{style}] {text}"}]}],
        "generationConfig": {"responseModalities": ["AUDIO"],
                             "speechConfig": {"voiceConfig": {"prebuiltVoiceConfig": {"voiceName": voice}}}},
    })
    for d in inline_parts(resp):
        rate = 24000
        for tok in d.get("mimeType", "").split(";"):
            if tok.strip().startswith("rate="):
                rate = int(tok.split("=")[1])
        write_pcm_wav(out, base64.b64decode(d["data"]), rate)
        return
    sys.exit(f"No audio returned: {json.dumps(resp)[:400]}")


def music(prompt, out):
    resp = call(MUSIC_MODEL, {"contents": [{"parts": [{"text": prompt}]}]})
    for d in inline_parts(resp):
        mime = d.get("mimeType", "")
        data = base64.b64decode(d["data"])
        if "pcm" in mime or "L16" in mime:
            write_pcm_wav(out, data, 48000)
        else:
            pathlib.Path(out).write_bytes(data)
        print(mime)
        return
    sys.exit(f"No music returned: {json.dumps(resp)[:600]}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("kind", choices=["image", "tts", "music"])
    ap.add_argument("prompt")
    ap.add_argument("out")
    ap.add_argument("--ref", action="append", default=[])
    ap.add_argument("--aspect", default="1:1")
    ap.add_argument("--voice", default="Sulafat")
    ap.add_argument("--style")
    a = ap.parse_args()
    if a.kind == "image":
        image(a.prompt, a.out, a.ref, a.aspect)
    elif a.kind == "tts":
        tts(a.prompt, a.out, a.voice, a.style)
    else:
        music(a.prompt, a.out)
    print(a.out)
