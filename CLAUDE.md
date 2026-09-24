# Sound Painter: Color My Voice

A voice-to-paint educational game for children aged 3–6 who learn at their own pace. It is a community-welfare project: free, no ads, no tracking, no backend. This project is separate from Urdu Safar; don't carry Safar decisions over.

## Source of truth
- `docs/game-design-document-v0.md`: the owner's original design (the starting point).
- `docs/proposal-v1.md`: tools, refinements and **locked decisions (§0)**. §0 wins wherever the two conflict.

## Locked
- Flutter (SDK at `/mnt/storage/projects/flutter/bin`), **Android only**, English only.
- Package `com.homilabs.soundpainter`: never change it after the first Play upload.
- No backend, Firebase, accounts, analytics or ads. Mic audio is processed on-device and never stored.
- Art and voice-over come from Gemini at build time (key in `.secrets/gemini_api_key`, gitignored). Never embed the key in the app.
- Errorless design: no fail states, timers or scores.

## Workflow
- Build one milestone at a time (proposal §6) and verify it before starting the next.
- Get scope and design decisions confirmed in writing before coding them.
- This machine has no microphone. Test audio logic with WAV fixtures; live-mic testing happens on the owner's real device.

## Locations
- Local backup: `/mnt/storage/project_backups/sound_painter_backup/`
- Google Drive: folder `1uz99ENUU_2KR-6NEprncKg9Kd2idoNN5` (rclone remote `gdrive`)
- GitHub (**public**): `git@github.com:AwaizFatima08/sound_painter.git`
- Backup: `bash scripts/backup.sh`. Commit first; the GitHub layer refuses to push with untracked or uncommitted files.

## Status (2026-09-24)
v1.0.0 (versionCode 1) is built, signed with the upload key and tested; it is ready for the owner to upload to Play Console.
- `releases/v1.0.0-1/` holds the AAB and APK (gitignored; in the local and Drive backups).
- `store-assets/` holds the icon, feature graphic, screenshots and privacy policy. The policy still needs hosting and a contact email.
- `docs/play-console-listing-kit.md` has the listing text and form answers. `docs/testing.md` covers the test suites and the manual real-voice checklist.

## Code map
- `lib/core/audio/`: `dsp.dart` (YIN pitch, harmonic-fit vowel recognition), `voice_analyzer.dart` (calibration, streaming frames), `voice_engine.dart` (mic lifecycle; mutes while prompts speak), `audio_input.dart` (mic + `SynthInput`), `sound_player.dart` (voice lines, SFX, music), `synth_voice.dart` (test voice).
- `lib/views/`: onboarding (parent setup, Pip's warm-up), home (+ profile picker), canvas (paint engine), safari (map + level), gallery, dashboard (parent zone, sound check).
- `lib/widgets/listening.dart`: base for every screen that uses the mic (wakelock, lifecycle, rest screen).
- `lib/services/`: `store.dart` (JSON + gallery PNGs on device), `session.dart` (time, voice, pitch range, time limit).

## Commands
- Tests: `flutter test` (host, 51) and `flutter test integration_test/app_flow_test.dart -d <device>` (end-to-end, synthetic voice).
- Emulator or demo without a mic: build with `--dart-define=SP_SYNTH_VOICE=true`.
- Release: `flutter build appbundle --release` (signs via `android/key.properties` → `.secrets/sound-painter-upload.keystore`).
- Assets: `scripts/gen_art.py` then `scripts/process_art.py` (images); `scripts/gen_voice.py` then `scripts/encode_voice.py` (voice; needs `lameenc`); `scripts/make_sfx.py`; `scripts/make_icon.py`; `scripts/make_store_assets.py`.
- **Gemini prepaid credits ran out on 2026-09-24.** Top up in AI Studio before generating more art or voice.

## Android build
- JDK 21 lives at `~/jdks/jdk-21.0.12.1+1`; system Java is 17.
- Emulator AVD `pixel6_api35`, at `ANDROID_AVD_HOME=/mnt/storage/projects/android-avd`. Start it with `-gpu swangle_indirect -cores 4 -memory 3072`: the default SwiftShader GL mode crashes it. Don't use `pkill -f` with a pattern that also appears in your own command line.
