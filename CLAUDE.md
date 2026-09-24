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

## Android build
- JDK 21 lives at `~/jdks/jdk-21.0.12.1+1`; system Java is 17.
- Emulator AVD `pixel6_api35`, at `ANDROID_AVD_HOME=/mnt/storage/projects/android-avd`.
