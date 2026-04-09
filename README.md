## UEMSI/HTV HD Express App

Flutter app to view an RTSP stream from a Wi‑Fi video transmitter (no internet), with:

- RTSP playback (`rtsp://192.168.0.1:554/main`)
- Low latency (UDP) vs Reliable (TCP) toggle
- Auto-retry + clear connection status
- Photo snapshots saved to the native Photos/Gallery apps
- “Connect to transmitter Wi‑Fi” flow:
  - One-tap join for known SSIDs (e.g. dev unit)
  - Fallback to opening system Wi‑Fi settings for unique production SSIDs

### Prereqs (your machine)

- Install Flutter SDK (includes Dart)
- Xcode (for iOS) and/or Android Studio (for Android)

### Bootstrap this repo (after Flutter is installed)

From this folder:

```bash
flutter create .
flutter pub get
flutter run
```

### Notes

- Production SSIDs are expected to look like:
  - `UEMSI/HTV HD Express Camera 2.4Ghz_XXXXXXXX`
  - `UEMSI/HTV HD Express Camera 5Ghz_XXXXXXXX`
  - Password: `12345678`

