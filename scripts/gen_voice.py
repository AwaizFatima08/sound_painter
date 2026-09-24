#!/usr/bin/env python3
"""Generate every spoken prompt with Gemini TTS into art/voice/*.wav (masters).

Then run scripts/encode_voice.py to make the MP3s the app ships. Skips files
that already exist. Line ids are passed to SoundPlayer.say() across lib/, so
keep them in sync.

  python3 scripts/gen_voice.py [id ...]
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent))
import gemini  # noqa: E402

OUT = gemini.ROOT / "art" / "voice"

PIP = "Leda"      # youthful, bright
OLLIE = "Achird"  # friendly, gentle
ARIA = "Sulafat"  # warm

KID = "slow, warm, clear and happy, like a kind friend talking to a four-year-old"
CALM = "slow, soft and warm, like a gentle teacher talking to a four-year-old"
PHONICS = ("slow and warm, for a four-year-old; isolated letter sounds are short phonics sounds as heard at "
           "the start of the word, never letter names, and are stretched out")

LINES = {
    # Pip: warm-up, hub, canvas
    "pip_hello": (PIP, KID, "Hi! I'm Pip! Let's paint with our voices!"),
    "warm_loud": (PIP, KID, "Can you make a big, loud sound? Like a lion! Roooar!"),
    "warm_quiet": (PIP, KID, "Now a tiny, quiet sound. Like a little mouse. Squeak."),
    "warm_high": (PIP, KID, "Can you sing up high, like a little bird? Eeee!"),
    "warm_low": (PIP, KID, "Now sing down low, like a big sleepy bear. Ohhhh."),
    "warm_skip": (PIP, KID, "That's okay! Let's try the next one."),
    "warm_done": (PIP, KID, "Wonderful! You're ready to paint!"),
    "choose_friend": (PIP, KID, "Tap your animal friend!"),
    "home_hello": (PIP, KID, "Tap a picture to play!"),
    "canvas_intro": (PIP, KID, "Sing, hum, or say aaah, and watch the colours!"),
    "canvas_finger": (PIP, KID, "You can paint with your finger too!"),
    "canvas_high": (PIP, KID, "So high! Wheee!"),
    "canvas_low": (PIP, KID, "Low and cozy!"),
    "canvas_praise1": (PIP, KID, "Beautiful colours!"),
    "canvas_praise2": (PIP, KID, "Wow! Look what you made!"),
    "canvas_praise3": (PIP, KID, "Keep going, you're doing great!"),
    "canvas_saved": (PIP, KID, "Your painting is saved in your gallery!"),
    "canvas_cleared": (PIP, KID, "A fresh new page!"),
    "gallery_intro": (PIP, KID, "Look at all your beautiful paintings!"),
    "session_end": (PIP, CALM, "Great work today! Time for a little rest. Bye bye!"),
    # Ollie: volume
    "ollie_loud": (OLLIE, KID, "Big and bright!"),
    "ollie_quiet": (OLLIE, CALM, "Soft and gentle. Lovely."),
    # Aria: phonics
    "aria_hello": (ARIA, CALM, "Hello, I'm Aria. Let's colour pictures with sounds!"),
    "aria_pick": (ARIA, CALM, "Tap a picture to colour it in."),
    "aria_a": (ARIA, PHONICS, "Apple! Listen. aaa. aaa. apple. Now you say aaa, and hold it long."),
    "aria_e": (ARIA, PHONICS, "Egg! Listen. ehh. ehh. egg. Now you say ehh, and hold it long."),
    "aria_i": (ARIA, PHONICS, "Igloo! Listen. ihh. ihh. igloo. Now you say ihh, and hold it long."),
    "aria_o": (ARIA, PHONICS, "Octopus! Listen. o. o. octopus, like in hot. Now you say o, and hold it long."),
    "aria_u": (ARIA, PHONICS, "Umbrella! Listen. uhh. uhh. umbrella. Now you say uhh, and hold it long."),
    "aria_keep": (ARIA, CALM, "Keep going!"),
    "aria_almost": (ARIA, CALM, "Almost there!"),
    "aria_again": (ARIA, CALM, "Listen, and try with me."),
    "aria_yay": (ARIA, KID, "You did it! What a beautiful picture!"),
}


def main(ids):
    OUT.mkdir(parents=True, exist_ok=True)
    for lid in ids or LINES:
        out = OUT / f"{lid}.wav"
        if out.exists():
            continue
        voice, style, text = LINES[lid]
        print("speaking", lid, flush=True)
        gemini.tts(text, out, voice, style)


if __name__ == "__main__":
    main(sys.argv[1:])
