# Sound Painter: Color My Voice — Tools & Refinements Proposal (v1)

*Proposal against the submitted Game Design Document.*
*Date: 2026-09-24*

---

## 0. Locked decisions (2026-09-24)

These are the owner's answers to §7. They override anything below that conflicts with them.

| Topic | Decision |
|---|---|
| Language | **English only** for v1 |
| Art | **Generated with Gemini** (image model), key at `.secrets/gemini_api_key` |
| Voice-over | **Generated with Gemini text-to-speech** instead of a human recording |
| Platform | **Android only** for v1 |
| Test device | Owner connects a real Android device when a milestone needs a live mic |
| Testers | Owner is engaging a pool of testers |
| GitHub | `AwaizFatima08/sound_painter` stays **public** |
| Backend | **None.** No Firebase, no server, no accounts. Everything stays on the device |
| Purpose | Community welfare: free, no ads, no in-app purchases |
| Package name | `com.homilabs.soundpainter` (from the GDD). **Unchangeable after the first Play upload** |

**Knock-on change:** Gemini makes still images, not Rive animation files. The characters will therefore be Gemini-drawn pose images (e.g. Pip idle, low and high), animated in Flutter code (bounce, squash, glow, cross-fade between poses). Rive is dropped from the tool list. Gemini also can't reliably draw letters, so every image is prompted text-free, which fits the zero-text UI anyway.

**Built (2026-09-24):** v1.0.0 covers M0–M7 in one pass, at the owner's request. Deviations from the tool table below, all simplifications with the same behaviour:
- **State:** plain services passed through an `InheritedWidget` instead of Riverpod.
- **Storage:** one JSON file plus PNGs instead of drift/SQLite (the data is small).
- **Audio analysis:** on the main isolate. It runs smoothly on the emulator; still to be confirmed on a budget real device.
- **Vowel recognition:** harmonic-fit matching instead of LPC, because LPC failed at children's pitch in tests.
- **Characters:** Gemini pose images animated in code instead of Rive (see §0).
- **Phonics vowels:** short phonics vowels (a/e/i/o/u as in apple, egg, igloo, octopus, umbrella), stretched, instead of the "aaah/eee" set in §4.1, to match the GDD's pictures.
- **Clear button:** the canvas's clear is a hold-to-clear "new page", and the old page is auto-saved first.
- **Not in v1:** Aria's animated mouth-position diagram (§3.4). She models each sound by voice, and a "hear it again" button repeats it. Also deferred: Pip's pitch game (§4.2) and per-child vowel calibration (§4.3); vowel matching uses fixed child reference values with an adult/child pitch adjustment.

---

## 1. What stays as you designed it

Your core idea is strong and I'd keep all of it:

- **Voice turns into paint:** volume sets the brush size and pitch sets the colour.
- **Three guide characters:** Pip, Ollie and Aria.
- **Three areas:** Free Canvas, Phonics Safari, and a gated Parent/Educator zone.
- **Privacy:** on-device processing only, no ads, no tracking.
- **Store:** built for Google Play's rules for children's apps.

The refinements below are about making the design work for **children aged 3–6 with slower learning**, and making the engineering hold up on real, inexpensive devices.

---

## 2. Proposed tools

| Area | Your GDD | Proposal | Why |
|---|---|---|---|
| Framework | Flutter | **Flutter 3.41 / Dart 3.11** (already installed at `/mnt/storage/projects/flutter`) | Keep it. It's a good fit for continuous drawing and audio. |
| Mic capture | `flutter_audio_capture` | **`record`** package (PCM16 stream) + **`permission_handler`** | `flutter_audio_capture` is barely maintained. `record` is actively maintained, streams raw PCM on Android and iOS, and lets us set the sample rate. |
| Audio analysis | Autocorrelation in the UI thread | **Pure Dart, in a background isolate**: RMS, **YIN pitch detection**, **`fftea`** for FFT, LPC for vowel formants | Keeps drawing smooth. YIN avoids the octave errors that raw autocorrelation makes. |
| Drawing | `CustomPainter` + blur per particle | `CustomPainter` driven by a `Ticker`, with glow drawn from a **pre-rendered sprite via `drawAtlas`** | A blur filter per particle is too slow on budget tablets. The sprite approach draws thousands of particles at 60 fps. |
| Character animation | Not specified | ~~Rive~~ → **Gemini pose images + Flutter implicit/explicit animations** (see §0) | Pip, Ollie and Aria still react to live pitch, volume and success, driven directly by the audio values. |
| App state | Not specified | **Riverpod** | Small, testable, well documented. |
| Local database | SQLite | **`drift`** (typed SQLite) | Same SQLite, but typed queries and safe schema migrations for the dashboard data. |
| Voice prompts & sound effects | Not specified | **`just_audio`**, playing prompts **pre-generated with Gemini TTS** and bundled as audio files | Generated once at build time, so no network is needed at runtime. Pick a warm, slow voice; the pace suits slower learners. |
| Quality | Not specified | `flutter_lints`, unit tests with **recorded WAV fixtures**, `integration_test` on the emulator | See §5: this machine has no microphone, so audio logic must be testable from files. |
| Crash reporting / analytics | Zero tracking | **None in v1** | Keeps the Play children's-app review and the data-safety form simple and honest. |

---

## 3. Refinements for children with slower learning

### 3.1 Errorless by design
- **No fail states, timers, lives or scores.** Every sound paints something, so the child always sees a result.
- **Phonics Safari always progresses.** Any vocalising fills the picture slowly; a close match to the target vowel fills it faster. The child is never blocked or told "wrong".
- **Rewards are the child's own picture.** Pictures go to a gallery ("My Paintings") instead of stars or grades that imply failure.

### 3.2 Per-child calibration (the most important change)
The GDD maps a fixed 100–700 Hz range to colour and a fixed volume ceiling to brush size. That won't hold up:
- young children speak around 250–450 Hz and squeal above 1000 Hz;
- many children with delays have a **narrow pitch or volume range**, so a fixed mapping would paint everything in one colour and one thickness.

**Proposal:** a 30-second **"Warm-up with Pip"** that measures room noise and the child's own quiet/loud and low/high range. Colour and brush size are then stretched across *that child's* range. Parents can rerun it any time, and the dashboard's mic-sensitivity slider fine-tunes it.

### 3.3 Voice-optional access
Some children in this group are minimally verbal or very shy. To include them:
- **Any sound counts** in Free Canvas: humming, "mmm", blowing, clapping, tapping the table.
- **A touch-paint fallback:** the finger draws and the voice colours it, or the finger alone paints if there is no voice.

### 3.4 Pacing and routine
- **One idea per screen**, and the same guide always leads the same activity.
- **Model, then imitate:** Aria demonstrates the sound (animated mouth plus recorded voice) before the child tries.
- **Short sessions of about 3–5 minutes** with a gentle ending ritual (the picture goes to the gallery, Pip waves goodbye). A parent can set the session length.
- **Levels are chosen by the parent, not by age:** "Explore" (like your 3–4 tier) and "Practise" (like your 5–6 tier). A 6-year-old with delays may need Explore.

### 3.5 Sensory safety
- A **calm mode** with fewer particles, softer colours and slower motion.
- A **volume cap** and no sudden loud effects.
- **No flashing faster than 3 times a second**, for photosensitivity.

### 3.6 Parent-first setup
The OS microphone-permission dialog is text, so a child can't answer it. The **first run is the parent's**: create a child profile, grant the mic, run the warm-up. After that the app opens straight into the child's zero-text world.

### 3.7 Educator-friendly dashboard
- Wording is **"practised" and "tried"**, not "mastered".
- It shows how often the child practised, their vocal range growing over time, and which vowels they attempted.
- **Multiple child profiles**, for a teacher or therapist with a class.
- **Parent gate:** a multiplication question ("What is 7 × 3?") or press-and-hold. "Tap the number 14" is too easy for 5–6 year olds who know numbers.

---

## 4. Design corrections

1. **Sustained vowels vs phonics vowels.** Short phonics vowels (/æ/ in *apple*, /ɪ/ in *igloo*) can't be held for several seconds, but Phonics Safari asks the child to *sustain* the sound. **Proposal:** use holdable vowels ("aaah", "eee", "ooo", "ohh", "ehh") and pair each with a picture whose name starts with that sound.
2. **Pip has no mode of their own.** Pip is the "pitch expert", but the screen map has no pitch activity. **Proposal:** Pip lives in Free Canvas (the scarf follows the child's pitch). A later "Pip's Ice Hill" pitch game could go on the roadmap.
3. **Vowel recognition in children's voices is hard.** Generic formant thresholds are unreliable for high, breathy child voices. **Proposal:** during the warm-up, the child copies Aria on each vowel. The app stores the child's own *acoustic fingerprint* per vowel (numbers only, never audio) and matches against that. This fits the privacy promise and suits atypical speech. It gets its own test spike before Phonics Safari is built.

## 5. Engineering corrections to the GDD code

| Issue | Fix |
|---|---|
| `byteBuffer.buffer.asInt16List()` reads the whole underlying buffer and ignores the view's offset and length, which can produce garbage samples | `asInt16List(offsetInBytes, lengthInBytes ~/ 2)` |
| Autocorrelation isn't normalised, so the `maxCorr > 0.15` threshold is meaningless; also prone to octave errors | YIN with parabolic interpolation, a short median filter and hysteresis |
| 2048-sample chunks = 128 ms per update, which feels laggy for cause-and-effect play | 1024-sample window with 50% overlap, about 32 ms per update |
| Fixed 100–700 Hz range, fixed volume ceiling (`rms / 0.4`) | Per-child calibration (§3.2) |
| `_estimateVowelFormant` always returns `/a/` | Replace with the vowel-fingerprint approach (§4.3) |
| `MaskFilter.blur` on every particle | Sprite glow via `drawAtlas`, capped particle count |
| `withOpacity` is deprecated in current Flutter | `withValues(alpha: …)` |
| `targetSdkVersion 34` | **Google Play requires 35+ now; target 36** (SDK 36 is installed here) |
| `package=` in `AndroidManifest.xml`, hardcoded `compileSdkVersion` | Use the current Flutter template (`namespace` in Gradle, `flutter.compileSdkVersion`) |
| `MODIFY_AUDIO_SETTINGS` permission | Drop it unless actually needed. Fewer permissions means an easier children's-app review |
| iOS: no `NSMicrophoneUsageDescription` | Add it when iOS work starts |

**Store wording:** describe the app as *educational* and *designed for children who learn at their own pace*. Avoid words like *therapy*, *treatment* or *improves speech disorders*. Health claims trigger stricter Play review and may need evidence.

**Package name:** `com.homilabs.soundpainter` is good. Please confirm it, because it can't be changed after the first Play upload.

---

## 6. Proposed build order

Build one milestone at a time and verify it before starting the next.

| # | Milestone | Done when |
|---|---|---|
| M0 | Setup: Flutter scaffold, git + GitHub, 3-layer backup script, lints | App runs on the emulator; the backup reaches all three locations |
| M1 | **Audio core:** capture, RMS, YIN in an isolate, with a live debug screen | Unit tests pass on WAV fixtures; Hz and volume read correctly on a real phone |
| M2 | **Free Canvas:** voice → particles, Home and Clear buttons, audio HUD | Smooth 60 fps drawing driven by voice on a real device |
| M3 | Parent-first setup, child profiles, warm-up calibration, parent gate | A new child can be set up and calibrated in under 2 minutes |
| M4 | Characters (Gemini art, code-animated; Pip first), Gemini TTS voice prompts | Pip reacts live to pitch in Free Canvas |
| M5 | **Vowel spike**, then Phonics Safari (Aria) | Vowel fingerprints tested on a few real child voices before the Safari screens are built |
| M6 | Parent/Educator dashboard (drift), gallery | Practice history and range growth display correctly |
| M7 | Play Store prep: icon, feature graphic, screenshots, privacy policy, data safety, children's-app declarations, signed AAB | Submitted |

---

## 7. Questions for you (answered: see §0)

1. **Language:** will voice prompts and vowel targets be **English, Urdu, or both**? The vowel sets differ, and so does the voice-over.
2. **Art and voice:** who makes the character art (Rive files) and records the voice prompts: you, a hired artist or voice artist, or should I produce placeholder art first?
3. **Test device:** this machine has no microphone, so the emulator can't hear a real voice. Can you connect a **real Android phone or tablet** (USB or wireless debugging) for M1 onward? Audio logic will also be tested from recorded WAV files.
4. **iOS:** building for iOS needs a Mac, and this machine runs Linux. Is **Android-only for v1** acceptable?
5. **Access to real children:** is there a teacher, therapist or parent group who could try builds (supervised, no recording kept) at M2 and M5?
6. **GitHub visibility:** the repo `AwaizFatima08/sound_painter` is public. OK, or would you prefer to make it private?
