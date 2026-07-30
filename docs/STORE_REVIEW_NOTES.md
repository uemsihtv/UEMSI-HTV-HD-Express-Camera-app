# Store review notes (App Store / Google Play)

Companion app for the UEMSI/HTV HD Express transmitter. Local network only
(`192.168.0.1`); not a general cloud/social product.

See also: [STORE_SUBMISSION.md](./STORE_SUBMISSION.md) for console upload checklists.

## Why this approach is store-reasonable

- Cleartext HTTP is scoped to the transmitter AP (`192.168.0.1`), not the public internet.
- Default device login (`admin` / `123456`) and Wi‑Fi password (`12345678`) are
  manufacturer local defaults, same class as typical IoT companion apps.
- **Footage** opens the **system browser** on both iOS and Android (in-app WebView
  failed: blank on iOS, `ERR_TOO_MANY_RETRIES` on Android).
- Meter reset uses the documented local HTTP API on the AP.
- Live blue-line hide uses a UI mask over the contained frame (no mpv `vf`);
  photos/recordings still crop in software/FFmpeg. Do not resize/rebuild the
  media_kit `Video` widget from size streams on iOS (prior SIGBUS crash).
- Live RTSP uses **UDP** on both platforms; demuxer buffer balanced at **4 MB**.
- Privacy / terms / EULA: use Termly URLs in README and in-app About.
- GPL / FFmpeg: About screen + public corresponding source repo.

## Reviewer demo tip

Physical transmitter Wi‑Fi is required for live video / Footage / meter reset.
Provide a review note + short video if Apple/Google cannot join the AP.

## Follow-ups before submit

- [x] Android `applicationId` / namespace: `com.uemsihtv.hdexpress`
- [x] iOS bundle ID: `uemsihtvHdExpressApp` (confirm matches App Store Connect)
- [x] Version `1.0.0+1` for first store release
- [x] Configure Android **upload keystore** (local `key.properties` + `upload-keystore.jks`, gitignored).
- [ ] Ship **release** AAB / Archive (not debug).
- [ ] Confirm Data safety / privacy answers match local-only video + photo save.
- [ ] Plan UIScene migration before Apple makes it mandatory (see `docs/UISCENE_MIGRATION.md`).
- [ ] Keep Local Network / photo usage strings accurate.
