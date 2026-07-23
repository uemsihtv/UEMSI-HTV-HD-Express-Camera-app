# Store review notes (App Store / Google Play)

Companion app for the UEMSI/HTV HD Express transmitter. Local network only
(`192.168.0.1`); not a general cloud/social product.

## Why today’s approach is store-reasonable

- Cleartext HTTP is scoped to the transmitter AP (`192.168.0.1`), not the public internet.
- Default device login (`admin` / `123456`) and Wi‑Fi password (`12345678`) are
  manufacturer local defaults, same class as typical IoT companion apps.
- iOS Footage opens Safari (WKWebView was blank for the device HTTP UI); optional
  Keychain preauth seeds those local defaults for HTTP Basic Auth.
- Android Footage stays in-app WebView with the same local defaults.
- Meter reset uses the documented local HTTP API on the AP.
- Live blue-line hide uses a UI mask over the contained frame (no mpv `vf`);
  photos/recordings still crop in software/FFmpeg. Do not resize/rebuild the
  media_kit `Video` widget from size streams on iOS (prior SIGBUS crash).
- Privacy / terms / EULA: use Termly URLs in README and in-app About.
- GPL / FFmpeg: About screen + public corresponding source repo.

## Reviewer demo tip

Physical transmitter Wi‑Fi is required for live video / Footage / meter reset.
Provide a review note + short video if Apple/Google cannot join the AP.

## Follow-ups before submit

- [ ] Ship **release** builds (iOS 26 debug home-screen launches are unreliable).
- [ ] Confirm Data safety / privacy answers match local-only video + photo save.
- [ ] Plan UIScene migration before Apple makes it mandatory (see `docs/UISCENE_MIGRATION.md`).
- [ ] Keep Local Network / photo usage strings accurate.
