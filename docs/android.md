## Android setup notes

After you run `flutter create .` (which generates `android/`), verify:

- You request photo/media permissions appropriate for the Android SDK level (PhotoManager handles this).
- If you later implement Wi‑Fi join for known SSIDs, you’ll need the modern APIs:
  - Android 10+: `WifiNetworkSpecifier` (user-confirmed)

