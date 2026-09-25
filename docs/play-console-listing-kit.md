# Play Console listing kit: Sound Painter

Copy-paste material for creating the app in Play Console. Everything here reflects what the v1.0.0 build actually does.

## Upload

| Item | File |
|---|---|
| App bundle (signed with the upload key) | `releases/v1.0.0-1/sound-painter-1.0.0-1.aab` |
| App icon 512×512 | `store-assets/icon-512.png` |
| Feature graphic 1024×500 | `store-assets/feature-graphic-1024x500.png` |
| Phone screenshots (8, 16:9) | `store-assets/screenshots/phone/` |
| 7-inch tablet screenshots (4, 16:10) | `store-assets/screenshots/tablet-7in/` |
| 10-inch tablet screenshots (4, 16:10) | `store-assets/screenshots/tablet-10in/` |
| Privacy policy | https://soundpainter.homilabs.org/privacy-policy.html (upload the `website/` folder first; see the end of this file) |

Package: `com.homilabs.soundpainter` · version 1.0.0 (versionCode 1) · targetSdk 36 · minSdk 24.
Use **Play App Signing** (the default): Google keeps the app-signing key, and this project's `.secrets/sound-painter-upload.keystore` is the upload key.

## Main store listing

**App name** (30 max): `Sound Painter: Color My Voice` (29)

**Short description** (80 max):
`Paint with your voice! A gentle voice and phonics game for children aged 3–6.` (77)

**Full description**:

```
Sound Painter turns a child's voice into colour. Sing, hum or say "aaah" and watch glowing paint flow across the screen: loud sounds make big brush strokes, high sounds paint warm reds and low sounds cool purples.

Made for children aged 3 to 6, including children who learn at their own pace.

• FREE CANVAS: Pip the penguin and Ollie the owl react to your child's voice while they paint. Little fingers can paint too.
• PHONICS SAFARI: Aria the turtle models a vowel sound (a, e, i, o, u). Hold the sound and the apple, egg, igloo, octopus or umbrella colours itself in.
• MY PAINTINGS: every picture is saved to your child's own gallery automatically.

Gentle by design
• No failing, no timers, no scores. Every sound makes art.
• Pip's one-minute warm-up learns each child's own voice range, so even a narrow range paints the whole rainbow.
• Explore and Practise levels, chosen by you, not by age.
• Calm mode: fewer sparkles and softer motion for children who are easily overwhelmed.
• Friendly spoken prompts, with no reading needed.
• Optional session time limit that ends with a gentle goodbye.

For grown-ups
• A simple dashboard: minutes played, voice time, vowel sounds practised and voice range over time.
• Several children on one device, each with their own animal friend.
• A microphone sound check for your device.

Private and free
• No ads, no in-app purchases, no accounts, no tracking.
• The app has no internet access. The microphone is analysed on the device in real time: nothing is ever recorded or sent anywhere.

Sound Painter is an educational game. It is not a therapy or medical tool.
```

**App category**: Education
**Tags** (pick from Play's list): Educational · Kids · Music (or Art & Design)
**Contact email**: homilabs.smc@gmail.com
**Website**: https://soundpainter.homilabs.org

## App content

| Section | Answer |
|---|---|
| Privacy policy | https://soundpainter.homilabs.org/privacy-policy.html |
| Ads | **No**, the app contains no ads |
| App access | **All functionality is available without special access** (no login) |
| Content rating (IARC questionnaire) | Category: *Reference, news or educational* (or *Game, All other*); answer **No** to violence, sexuality, language, controlled substances, gambling, user interaction/sharing, location sharing, purchases. Expected result: Everyone / PEGI 3 / all ages |
| Target audience and content | Age groups **Ages 5 and under** and **Ages 6–8** (the app's audience is 3–6). This places the app in the **Families program**: agree to the Families Policy requirements |
| Appeal to children (if asked) | Yes, designed for children |
| News app | No |
| COVID-19 tracing | No |
| Data safety | See below |
| Government app | No |
| Financial features | None |
| Health | Not a health or medical app (do **not** list it under health; the store text says "not a therapy or medical tool") |
| Permissions | Only `RECORD_AUDIO`, used for the core feature. No special declaration form is needed for the microphone |

### Families Policy checklist (all satisfied by v1.0.0)
- No ads SDKs or analytics SDKs. Third-party packages: Flutter plus `record`, `just_audio`, `permission_handler`, `path_provider`, `wakelock_plus` (all on-device utilities, none send data).
- Settings, dashboard and anything adult-facing sit behind a parent gate (a multiplication question).
- No links out of the app in children's areas, and no purchases.
- The microphone permission is requested during the parent's setup, with an explanation.
- No personal information collected (the nickname is optional, stays on the device, and the setup asks for a nickname, not a name).

## Data safety form

- **Does your app collect or share any of the required user data types?** → **No.**
  Rationale, which matches Google's definitions: audio is processed on the device only, is ephemeral and never leaves the device ("processed only on device" is not "collected"). Profiles, progress and paintings are stored only locally and are never transmitted. The app has no internet permission.
- **Is all of the user data collected by your app encrypted in transit?** → Not applicable (no data transmitted).
- **Do you provide a way for users to request that their data is deleted?** → The app stores nothing off-device. In-app, a parent can remove a child's data, and uninstalling deletes everything.

## Before submitting: pre-launch report

1. Create an **Internal testing** release and upload the AAB. Play then runs its automatic **pre-launch report** on real devices (usually within about an hour). Check the report for crashes, accessibility warnings and screenshots.
2. The pre-launch robot will reach the parent setup screens and can tap through them. The microphone parts will be silent on its devices, which the app handles (the warm-up skips gently and finger painting still works).
3. Promote to Closed or Production when you're happy. Note: if the Play developer account is a *personal* account created after November 2023, Google requires a closed test with at least 12 opted-in testers for 14 consecutive days before production access. Organisation accounts are exempt. Your tester pool fits this step well.

## Hosting the website (do this before submitting)

Upload the **contents** of the `website/` folder to the root of `soundpainter.homilabs.org`:

| File | Purpose |
|---|---|
| `index.html` | Landing page (the listing's Website field) |
| `privacy-policy.html` | The privacy policy URL Play requires |
| `icon-512.png`, `feature.jpg`, `shot-*.jpg` | Images used by the two pages |

Then check that https://soundpainter.homilabs.org/privacy-policy.html opens in a browser before pasting it into Play Console.

Once the app is live, change the landing page badge "Coming soon to Google Play" (in `index.html`) to a link:
`https://play.google.com/store/apps/details?id=com.homilabs.soundpainter`
