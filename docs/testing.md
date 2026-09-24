# Testing Sound Painter

## What runs automatically (no microphone needed)

| Suite | Command | What it proves |
|---|---|---|
| Host unit and widget tests (51) | `flutter test` | Pitch detection (YIN) on tones and synthetic child voices, no octave errors; vowel recognition for all 5 vowels at child and adult pitch; calibration maths; warm-up noise floor can't make the app deaf; storage survives restarts, corrupt files and rapid saves; gallery limits; parent gate; first-run screens |
| Real-voice regression | part of `flutter test` (`test/real_voice_test.dart`) | /a/, /i/ and /u/ are the top-heard vowel in Aria's recorded lines (real speech, not synthetic) |
| End-to-end on a device or emulator | `flutter test integration_test/app_flow_test.dart -d <device>` | A synthetic child voice completes Pip's warm-up, paints in Free Canvas (auto-saved), colours the apple with /a/ recognised, finds the painting in the gallery; a parent answers the gate and sees progress |
| Stress ("monkey") | `adb shell monkey -p com.homilabs.soundpainter --throttle 120 -v 3000` | Thousands of random taps and swipes, like a small child mashing the screen: no crash, no freeze |

### Results for v1.0.0 (24 Sep 2026, Android 15 emulator)
- `flutter analyze`: no issues. `flutter test`: 51/51 passed.
- End-to-end: passed (about 3.5 minutes).
- Monkey: 3,000 events on the release build: no crashes, no ANRs.
- Release APK permissions: `RECORD_AUDIO` only (no internet permission).

Emulator notes for this NAS (4 CPU cores, no GPU): start the emulator with
`-gpu swangle_indirect -cores 4 -memory 3072`. The default SwiftShader GL mode
crashes the emulator ("Failed to find ColorBuffer"), and heavy load can trip its
hang watchdog. These are emulator limitations, not app faults. Integration-test
screenshots (`--dart-define=SP_SHOTS=true`) also crash the emulator; take store
screenshots with `adb exec-out screencap` instead.

## With a real device attached

Enable Developer options and USB debugging (or Wireless debugging) on the phone or tablet, connect it, and check that `adb devices` lists it. Then:

1. **Automated, on the device** (no talking needed):
   `flutter test integration_test/app_flow_test.dart -d <device-id>`
   This runs the same synthetic-voice journey on the real hardware and GPU.
2. **Release build on the device**: `adb install releases/v1.0.0-1/sound-painter-1.0.0-1.apk`

## Manual real-voice check (about 10 minutes, needs a person)

Synthetic voices can't test the device's actual microphone, echo cancellation or a real child's voice, so a human needs to do this part. Use the **Sound check** screen (grown-ups area → *Sound check*), then play normally.

| # | Do this | Expect |
|---|---|---|
| 1 | Sound check: stay quiet | "Quiet (below the noise gate)"; loudness bar empty |
| 2 | Speak normally, then loudly | Bar rises; loud reaches the top |
| 3 | Hum low, then sing high | Hz follows (for example 200 → 450); colour goes violet → red |
| 4 | Hold "aaa", "eh", "ih", "o", "uh" | "Sounds like" shows the vowel most of the time (/e/ and /o/ are the weakest; see below) |
| 5 | Free Canvas: sing a long "aaah" | Brush sweeps across the page; pitch sets height and colour, loudness sets size |
| 6 | While Pip is talking, stay silent | Pip's own voice does **not** paint (echo cancellation plus muting) |
| 7 | Clap, blow or hum | Something paints (no pitch = rainbow colours) |
| 8 | Paint with a finger, with and without singing | Finger strokes; singing changes their colour and size |
| 9 | Phonics Safari (Explore): any sound | Picture colours in within about 10 s of sound, then the celebration |
| 10 | Grown-ups → level **Practise**, hold the right vowel vs a wrong one | Right vowel colours noticeably faster; the letter bubble glows |
| 11 | Grown-ups → Session length 5 min, keep playing | Pip says goodbye and the mic turns off; the lock unlocks more time |
| 12 | Background the app mid-painting, come back | Mic indicator off while away; painting continues on return |
| 13 | Deny the microphone in setup | Everything still works with finger painting; grown-ups area offers "Allow" |

Record the device model, Android version and anything odd in a GitHub issue or a note.

## Tester pool: what to collect

The vowel recogniser is tuned on textbook children's formant values. Before v1.1, gather **consented, supervised** feedback from the tester pool:
- Does Free Canvas react to each child (including very quiet or low-verbal children)? Would the sensitivity slider fix it?
- In Practise level, does the right vowel usually glow the letter? Note which vowels fail.
- Is the warm-up too long or confusing for any child?

The app itself records no audio. If recordings are wanted for tuning, collect them separately with parental consent and outside the app.

## Google Play pre-launch report

Upload the AAB to an **Internal testing** track in Play Console; Google then runs the app on a range of real devices and reports crashes, performance and accessibility issues. See `docs/play-console-listing-kit.md`.
