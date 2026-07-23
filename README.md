# UEMSI/HTV HD Express Camera app

Flutter app to view an RTSP stream from a UEMSI/HTV HD Express Wi‑Fi transmitter (`rtsp://192.168.0.1:554/main`), with live playback, recording, snapshots, and gallery integration.

**App version (from `pubspec.yaml`):** `0.1.1+2`

## License

This repository is licensed under the **GNU General Public License v3.0** — see the [`LICENSE`](LICENSE) file in this repo.

The distributed app includes **open-source third-party software**. Notably, video recording uses **FFmpeg** via **FFmpegKit** (`ffmpeg_kit_flutter_new`, **full-gpl** build on iOS/Android). See the in-app **About** screen for links to third-party notices, the GPL text, FFmpegKit, and this source repository.

## Source code

This GitHub repository is the **complete corresponding source** for the app as distributed (subject to your checkout matching the tagged release you ship).

- **Repository:** https://github.com/uemsihtv/UEMSI-HTV-HD-Express-Camera-app

## Privacy and terms

**Authoritative privacy notice (Termly):** https://app.termly.io/document/privacy-policy/2685a75d-96c1-4d72-bccf-f664ef376019  

**Data / privacy requests (Termly DSAR):** https://app.termly.io/dsar/2685a75d-96c1-4d72-bccf-f664ef376019  

**Cookie policy (Termly, www.uemsihtv.com):** https://app.termly.io/document/cookie-policy/aff4df74-0634-4003-9b96-0bd50e367711  

**Terms and conditions (Termly):** https://app.termly.io/document/terms-of-service/2685a75d-96c1-4d72-bccf-f664ef376019  

**EULA — UEMSI/HTV Express Camera (Termly):** https://app.termly.io/document/eula/ee845345-7d7e-41a0-969e-0913ac88cdcb  

**Disclaimer — Site + mobile app (Termly):** https://app.termly.io/document/disclaimer/db304331-da22-4419-8e35-0ec122f04455  

**In the app:** URLs are in [`lib/src/config/legal_urls.dart`](lib/src/config/legal_urls.dart). Empty optional fields hide those buttons; empty `termlyPrivacyPolicy` / `termlyTermsOfUse` fall back to GitHub `docs/PRIVACY.md` / `docs/TERMS.md`.

**Store listings:** use the Termly **privacy**, **terms**, and **EULA** URLs above where each store asks for them. The short `docs/TERMS.md` in this repo is a **GPL-focused supplement**, not a substitute for your Termly legal terms.

## Prerequisites

- **Flutter** SDK (stable channel recommended), with Dart **≥ 3.7.0** (see `pubspec.yaml`).
- **Xcode** (latest compatible with your macOS) for iOS builds.
- **Android Studio** or Android SDK + **CocoaPods** (`pod`) for Android/iOS native steps.
- **Ruby CocoaPods** for iOS: `sudo gem install cocoapods` or `brew install cocoapods`.

Record toolchain versions when you cut a store release (paste into release notes or a git tag message):

```bash
flutter --version
dart --version
```

## Clone and bootstrap

```bash
git clone https://github.com/uemsihtv/UEMSI-HTV-HD-Express-Camera-app.git
cd UEMSI-HTV-HD-Express-Camera-app
flutter pub get
```

Do **not** run `flutter create .` on this clone — the project is already generated.

## Run (debug)

```bash
flutter run
```

Use a device or emulator with network access to the transmitter when testing RTSP.

## Android — release APK (for sideload / internal testing)

From the repo root:

```bash
flutter pub get
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

Install (example with `adb`):

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Release builds use **R8 minification**; ProGuard rules live in `android/app/proguard-rules.pro`.

## Android — Play App Bundle (Play Store)

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

Configure signing in `android/app/build.gradle.kts` (or your CI) for Play uploads.

## iOS — device / TestFlight / App Store

1. Install pods:

   ```bash
   cd ios
   pod install
   cd ..
   ```

2. Open **`ios/Runner.xcworkspace`** in Xcode (not `Runner.xcodeproj`).

3. Set **Signing & Capabilities** for the `Runner` target (team, bundle ID).

4. **Product → Archive** and distribute via App Store Connect.

CLI build without signing (sanity check):

```bash
flutter build ios --release --no-codesign
```

**Note:** iOS **14+** is required (see `ios/Podfile`). Some simulator configurations may be limited by native dependencies (e.g. FFmpegKit); test on a **physical device** when in doubt.

**UIScene:** the app currently uses the classic AppDelegate window path on purpose. A future migration checklist is in [`docs/UISCENE_MIGRATION.md`](docs/UISCENE_MIGRATION.md) (reference: `ios/Runner/SceneDelegate.swift`).

## Features (summary)

- Landing screen, Wi‑Fi setup flow, live RTSP video (media_kit)
- Recording to MP4 (FFmpegKit), snapshots, gallery save (photo_manager)
- About / open-source licenses / source link in-app

## Transmitter Wi‑Fi

Production SSIDs (32-character Wi‑Fi limit; `xxxxxxxx` = unique device ID):

- **2.4G:** `UEMSI/HTV HDCamera 2.4G_xxxxxxxx` (32 chars)
- **5G:** `UEMSI/HTV HDCamera 5G_xxxxxxxx` (30 chars)

Default band is **5G**. The module cannot run both bands at once; switch 2.4G/5G in the transmitter Device Settings UI. Password (as documented in-app): `12345678`.
