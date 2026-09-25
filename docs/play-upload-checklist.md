# Sound Painter v1.0.0: Play Console upload checklist

Everything is in this package folder. Work through it top to bottom; details and copy-paste text are in `4-listing-text.md`.

## Before you open Play Console

1. **Host the website.** Upload the contents of `3-website-upload/` to the root of `soundpainter.homilabs.org`.
2. Open **https://soundpainter.homilabs.org/privacy-policy.html** in a browser and confirm it loads.

## In Play Console (homilabs account)

3. **Create app**
   - Name: `Sound Painter: Color My Voice`
   - Language: English (United States) or English (United Kingdom)
   - App (not game)
   - Free
   - Accept the declarations.
4. **App content** (left menu → Policy → App content). Answers are in `4-listing-text.md`:
   - Privacy policy URL
   - Ads: No
   - App access: all functionality available
   - Content rating questionnaire
   - Target audience: Ages 5 & under and 6–8 (joins the Families program)
   - Data safety: no data collected or shared
   - Government app: No
   - Financial features: None
   - Health: none
5. **Main store listing**
   - Short and full description: copy from `4-listing-text.md`.
   - App icon: `2-store-graphics/icon-512.png`
   - Feature graphic: `2-store-graphics/feature-graphic-1024x500.png`
   - Phone screenshots: all 8 in `2-store-graphics/screenshots/phone/`
   - 7-inch tablet screenshots: `2-store-graphics/screenshots/tablet-7in/`
   - 10-inch tablet screenshots: `2-store-graphics/screenshots/tablet-10in/`
   - Category: Education
   - Contact email: homilabs.smc@gmail.com
   - Website: https://soundpainter.homilabs.org
6. **Internal testing** (Testing → Internal testing → Create release)
   - Keep **Play App Signing** on (default).
   - Upload `1-app-bundle/sound-painter-1.0.0-1.aab`.
   - Release name: `1.0.0 (1)`. Release notes: "First release."
   - Roll out, then add yourself as a tester.
7. **Pre-launch report**: appears under *Testing → Pre-launch report* about an hour after the upload. Check it for crashes and accessibility warnings. Send me the report if anything shows up.
8. **Closed testing with your tester pool**, then **Production**. If the Play account is a personal account created after Nov 2023, Google requires at least 12 testers opted in for 14 days before it allows Production. An organisation account skips this.

## After it's live
- In `index.html`, change the "Coming soon to Google Play" badge to a link to
  `https://play.google.com/store/apps/details?id=com.homilabs.soundpainter`.

## Facts you may be asked
- Package name: `com.homilabs.soundpainter` (permanent once uploaded)
- Version: 1.0.0, versionCode 1; targetSdk 36; minSdk 24
- Permissions: microphone only (`RECORD_AUDIO`), with no internet permission
- Upload key certificate SHA-256: `57:51:CC:B7:3B:69:41:71:96:DB:D4:AB:49:C7:AD:96:AD:9C:72:46:76:F9:D9:27:6F:28:35:DF:06:1E:78:A3`
  (keystore and password in `.secrets/`, backed up locally and on Google Drive, never in GitHub)
- For the next upload, versionCode must increase: bump `version:` in `pubspec.yaml` (e.g. `1.0.1+2`).
