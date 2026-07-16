# UIScene migration checklist (iOS)

**Status:** Hold off until Flutter + iOS scene lifecycle is proven stable for this app.  
**Current runtime path:** classic `AppDelegate` + explicit `FlutterEngine` + `UIWindow` (no scene manifest).  
**Reference (not compiled):** [`ios/Runner/SceneDelegate.swift`](../ios/Runner/SceneDelegate.swift)

## Why we are not on UIScene today

- An earlier AppDelegate + explicit-engine setup was adopted to avoid **UIScene + implicit Flutter engine races** (notably around iOS 26 / `FlutterViewController` startup).
- `SceneDelegate.swift` is kept in the Xcode project for a future flip, but it is **not** in the Runner **Compile Sources** build phase, and `Info.plist` has **no** `UIApplicationSceneManifest`.

Official Flutter guide (check for updates when migrating):  
https://flutter.dev/to/uiscene-migration

---

## Pre-flight

- [ ] Note current Flutter / Xcode / iOS versions (`flutter --version`, Xcode About).
- [ ] Create a dedicated branch (do not mix with feature work).
- [ ] Confirm cold launch, live video, record, snapshot, Device Settings WebView, and Wi‑Fi return-from-Settings all work on the **AppDelegate** path before changing anything.
- [ ] Re-read the Flutter UIScene migration doc for your exact Flutter version.

---

## Minimal migration steps

### 1. Info.plist — enable scenes

- [ ] Add `UIApplicationSceneManifest` with:
  - Application supports multiple scenes = `NO` (single-window camera app).
  - Scene configuration name (e.g. `Default Configuration`).
  - Delegate class name = `$(PRODUCT_MODULE_NAME).SceneDelegate` (or `SceneDelegate` as appropriate).
- [ ] Keep existing keys (`NSLocalNetworkUsageDescription`, ATS local networking, photo usage, etc.).

### 2. Compile `SceneDelegate.swift`

- [ ] Xcode → Runner target → **Build Phases** → **Compile Sources** → add `SceneDelegate.swift`.
- [ ] Confirm the file still matches the intended pattern: **explicit** `FlutterEngine`, then `FlutterViewController(engine:)`, then `GeneratedPluginRegistrant.register(with:)`.

### 3. Reconcile `AppDelegate` (critical)

Goal: **one** engine, **one** window owner, **no duplicate** method channels.

- [ ] Stop creating `UIWindow` / `FlutterViewController` / running a second engine in `application(_:didFinishLaunchingWithOptions:)` once scenes own the UI.
- [ ] Move or keep plugin registration in **one** place only (prefer the Flutter-recommended scene/AppDelegate split for your Flutter version).
- [ ] Ensure channels are registered once:
  - `uemsi_device_info`
  - `uemsi_wifi_joiner` (currently deferred one main-queue turn in both files)
- [ ] Decide where `@main` / `UIApplicationDelegate` lifecycle stays (AppDelegate remains the process delegate; SceneDelegate owns the window scene).

### 4. Align `SceneDelegate` with current `AppDelegate` behavior

Match the production AppDelegate behaviors that SceneDelegate already sketches:

- [ ] Explicit engine: `FlutterEngine(name: "main_engine")` → `run()` → register plugins → attach `FlutterViewController`.
- [ ] Create `UIWindow(windowScene:)` (not `UIScreen.main.bounds` alone).
- [ ] Install device-info channel synchronously; defer Wi‑Fi join channel one main-queue turn (same as AppDelegate).
- [ ] Do **not** use implicit `FlutterViewController()` without an engine (that was part of the crash/race surface).

### 5. Clean up

- [ ] Remove dead `AppDelegate.window` setup if unused after migration.
- [ ] Update the header comments in `SceneDelegate.swift` / `AppDelegate.swift` so they no longer say “reference only.”
- [ ] `cd ios && pod install` after any embedding/plugin changes.
- [ ] Build from **`ios/Runner.xcworkspace`** (not `.xcodeproj`).

---

## Regression test plan (required before merge)

Test on a **physical** iPhone and iPad (simulator is not enough for RTSP / local network / FFmpeg).

- [ ] Cold launch (kill app → open) — no crash, no long black screen.
- [ ] Warm launch from background.
- [ ] Connect to transmitter Wi‑Fi → setup card hides → **View Live Video**.
- [ ] Live video portrait + landscape.
- [ ] **Footage** (Device Settings WebView → `http://192.168.0.1`).
- [ ] **Video** settings sheet (low-latency toggle) — video must not go black permanently.
- [ ] Photo snapshot + Record (+ stop / save to gallery).
- [ ] Leave app to Settings / Wi‑Fi and return — player / UI recover.
- [ ] About dialog + legal links.
- [ ] Repeat after device reboot once.

---

## Rollback

If launch is unstable:

1. Remove `UIApplicationSceneManifest` from `Info.plist`.
2. Remove `SceneDelegate.swift` from **Compile Sources** (keep the file in the repo).
3. Restore AppDelegate window + explicit engine setup.
4. Clean build folder / reinstall on device.

---

## Decision rule

Migrate when **all** are true:

1. Flutter’s UIScene docs match your Flutter channel/version.
2. A dedicated branch passes the regression list above on real hardware.
3. You are ready to treat launch crashes as a release blocker for that branch.

Until then, keep the current AppDelegate path and treat console UIScene warnings as informational.
