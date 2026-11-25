# Encryption note (App Store export compliance)

Prepared 2026-11-25 for whoever handles export compliance. This is a factual
inventory of what the iOS app contains and uses. It is **not** a legal
determination.

## Current declaration

- `ios/Runner/Info.plist` sets `ITSAppUsesNonExemptEncryption` = `false`
  (added for 1.0.1, build 5).
- No encryption documentation has been uploaded in App Store Connect.

## Why this needs a decision

App Store Connect requires documentation when an app contains "standard
encryption algorithms instead of, or in addition to, using or accessing the
encryption within Apple's operating system".

The shipped app **bundles its own TLS / crypto code** (see below), even though
the app's own features do not use it. Whether that makes `false` the correct
answer is the open question for compliance review.

## What the app bundles

Frameworks present in `Runner.app/Frameworks` (1.0.1 build):

- `Mbedtls.framework`, `Mbedcrypto.framework`, `Mbedx509.framework`
  (Mbed TLS, shipped with the media_kit / libmpv video libraries).
- FFmpeg libraries (`Avformat`, `Avcodec`, `Avutil`, `Swresample`, `Swscale`,
  etc.) from `media_kit_libs_ios_video` and from `ffmpeg_kit_flutter_new`
  (https package variant). The TLS backend of the `ffmpeg_kit` libraries was
  **not** confirmed from the project files. Its package documentation lists
  `gnutls` among its components.
- The media player's protocol whitelist in
  `lib/src/features/viewer/viewer_screen.dart` includes `tls`, `https` and
  `crypto`. This enables those protocols in the player; the app does not point
  the player at any `https` address.

## What the app actually does on the network

| Traffic | Where | Encrypted by the app? |
|---|---|---|
| Live video: RTSP control + RTP over UDP | Camera, `192.168.0.1:554` (local Wi-Fi) | No (plain RTSP/RTP) |
| iOS RTSP control relay (`rtsp_control_relay.dart`) | `127.0.0.1` on the phone, forwarded to the camera | No (plain TCP) |
| Recording (FFmpeg, RTSP over TCP) | Camera, `192.168.0.1:554` | No |
| Camera settings / meter reset (`http://192.168.0.1/...`) | Camera | No (plain HTTP, ATS exception scoped to the camera) |
| Legal / privacy / terms / source links | Opened with `url_launcher` in the system browser | Handled by iOS (Safari), not by the app's bundled libraries |

The app has no accounts, no cloud backend and no analytics of its own. No data
is sent to any server by the app's code.

## Questions for compliance

1. Does bundling Mbed TLS (and possibly the ffmpeg_kit TLS backend), unused by
   the app's own features, count as containing standard encryption in addition
   to the OS?
2. If yes: is the app eligible for the usual exemption / self-classification
   path for mass-market software using standard algorithms, and are any
   annual self-classification reports required?
3. Does the answer change the `ITSAppUsesNonExemptEncryption` value? If so,
   a new build is needed (next version after 1.0.1+5; use at least 1.0.2+6).

## Related

- GPL / FFmpeg notice and public source: `docs/STORE_REVIEW_NOTES.md`,
  About screen.
- Store submission checklist: `docs/STORE_SUBMISSION.md`.
