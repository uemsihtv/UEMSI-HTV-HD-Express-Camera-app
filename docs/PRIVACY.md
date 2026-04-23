# Privacy Policy — UEMSI/HTV HD Express Camera app

**Effective date:** April 9, 2026  
**App:** HD Express Camera (UEMSI/HTV HD Express Camera)

The **authoritative** privacy notice for this app is the **Termly** hosted policy: https://app.termly.io/document/privacy-policy/2685a75d-96c1-4d72-bccf-f664ef376019 — use that URL in **App Store / Play** listings and in-app **About** (see `lib/src/config/legal_urls.dart`). This file remains a **summary / source-repo copy** for transparency and GPL/source distribution.

This policy describes how the app handles information when you use it on your device. The publisher is **UEMSI** (referred to below as “we”, “us”). If you have questions, use the **support contact** shown on this app’s listing in the **App Store** or **Google Play**, or open an issue on our public source repository (see link in the app’s **About** screen).

## Summary

- The app is built to work with a **local Wi‑Fi video transmitter**. It does **not** require an account and does **not** send your video, audio, or files to **our** servers—we **do not operate** application servers for this app.
- We **do not** use in-app analytics, crash reporting, or advertising SDKs in the version described by this policy.
- Some data is stored **only on your device** to make the app work (see below). **Apple** and **Google** may process data according to their own policies when you use their stores, devices, and platform services.

## Information the app uses

### Local network and video stream

- The app connects over **your local network** (typically to the transmitter’s address, e.g. `rtsp://192.168.0.1:554/...`) to display live video.
- That traffic stays between **your device** and **equipment on your network** (or the transmitter). We do not receive a copy of your stream.

### Photos, videos, and files

- If you **save a snapshot or recording**, the app writes media to your device using the **system photo library / gallery** APIs. Where those files are stored and how they are backed up is controlled by **your device** and **your platform account** (e.g. iCloud / Google Photos), not by us.

### Preferences stored on your device

The app may store the following **locally** using on-device storage (e.g. `SharedPreferences` on Android / iOS):

- **Wi‑Fi network name (SSID) and password** you choose to save for quicker connection to a known transmitter network (optional; you provide these values).
- **Playback / transport preference** (e.g. reliable vs low-latency style tuning).
- **UI state**, such as whether an onboarding or setup hint was dismissed.

This data is **not** transmitted to us. It remains on the device unless you uninstall the app, clear app data, or the OS migrates backups according to your platform settings.

### Permissions

Depending on platform and version, the app may request permissions such as:

- **Local network** access — to discover and connect to the transmitter on Wi‑Fi.
- **Photo library / media** access — to save snapshots and recordings you create.
- **Location** or **nearby Wi‑Fi** related permissions on **Android** — used **only** to support joining or managing Wi‑Fi as required by the operating system; the app does not use this to track your location for our purposes.

Permission prompts are explained in the system dialog text and in the app’s platform metadata (e.g. `Info.plist` / Play listing).

### When you open external links

If you tap links in **About** (for example open-source licence text, project pages, or source code on GitHub), your browser or system viewer opens those **third-party** sites. Their privacy practices are governed by **their** policies, not this one.

## No sale of personal information

We do **not** sell your personal information.

## Children

The app is not directed at children. If you believe we have inadvertently collected information that should not be processed, contact us through the store listing support channel.

## Security

No method of electronic storage is perfectly secure. You should protect your device with a passcode or biometrics and keep your Wi‑Fi credentials confidential.

## Open source

This app is distributed under the **GNU General Public License v3.0**. Source code and licence text are available through the repository linked from the in-app **About** screen.

## Changes to this policy

We may update this policy by posting a revised version in the same location (this file in the public repository). The **effective date** at the top will change when we do. Continued use of the app after changes means you accept the updated policy.

## Contact

- **Store support:** use the developer support URL or contact option on the **App Store** or **Google Play** product page for this app.  
- **Technical / open source:** issues may be opened on the GitHub repository linked from **About → Source code**.
