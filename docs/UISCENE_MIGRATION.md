# UIScene migration checklist (iOS)

**Status:** Migrated. The window is owned by `SceneDelegate` and attached to the connecting `UIWindowScene`.  
**Current runtime path:** `AppDelegate` (process only) + explicit `FlutterEngine` + `UIWindow(windowScene:)` + `UIApplicationSceneManifest` (multiple scenes off).  
**Compiled:** [`ios/Runner/SceneDelegate.swift`](../ios/Runner/SceneDelegate.swift)

## Why the engine stays explicit

- An implicit `FlutterViewController` crashed in `viewDidLoad` on iOS 26 (ProMotion / touch-rate vsync client). The scene manifest therefore has **no** `UISceneStoryboardFile`.
- `UIScreen.main` is not used. On iPhone Duo that screen is ambiguous, and a window sized from it does not follow a fold.

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

- [x] Add `UIApplicationSceneManifest` with:
  - Application supports multiple scenes = `NO` (single-window camera app).
  - Scene configuration name (e.g. `Default Configuration`).
  - Delegate class name = `$(PRODUCT_MODULE_NAME).SceneDelegate` (or `SceneDelegate` as appropriate).
- [x] Keep existing keys (`NSLocalNetworkUsageDescription`, ATS local networking, photo usage, etc.).

### 2. Compile `SceneDelegate.swift`

- [x] Xcode → Runner target → **Build Phases** → **Compile Sources** → add `SceneDelegate.swift`.
- [x] Confirm the file still matches the intended pattern: **explicit** `FlutterEngine`, `GeneratedPluginRegistrant.register(with:)`, then `FlutterViewController(engine:)`.

### 3. Reconcile `AppDelegate` (critical)

Goal: **one** engine, **one** window owner, **no duplicate** method channels.

- [x] Stop creating `UIWindow` / `FlutterViewController` / running a second engine in `application(_:didFinishLaunchingWithOptions:)` once scenes own the UI.
- [x] Move or keep plugin registration in **one** place only (prefer the Flutter-recommended scene/AppDelegate split for your Flutter version).
- [x] Ensure channels are registered once:
  - `uemsi_device_info`
  - `uemsi_device_web`
  - (`uemsi_wifi_joiner` was removed on iOS; it was never called from the UI)
- [x] Decide where `@main` / `UIApplicationDelegate` lifecycle stays (AppDelegate remains the process delegate; SceneDelegate owns the window scene).

### 4. Align `SceneDelegate` with current `AppDelegate` behavior

Match the production AppDelegate behaviors that SceneDelegate already sketches:

- [x] Explicit engine: `FlutterEngine(name: "main_engine")` → `run()` → register plugins → attach `FlutterViewController`.
- [x] Create `UIWindow(windowScene:)` (not `UIScreen.main.bounds` alone).
- [x] Install device-info and device-web channels synchronously; defer Wi‑Fi join channel one main-queue turn.
- [x] Do **not** use implicit `FlutterViewController()` without an engine (that was part of the crash/race surface).

### 5. Clean up

- [x] Remove dead `AppDelegate.window` setup if unused after migration.
- [x] Update the header comments in `SceneDelegate.swift` / `AppDelegate.swift` so they no longer say “reference only.”
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

On iPhone Duo, also:

- [ ] Cold launch folded (outer display) and unfolded (inner display). Controls stay clear of the side status bar.
- [ ] Fold and unfold while live video is playing. The picture resizes and the stream keeps playing.
- [ ] Half-folded pose. Back, Photo, and Record stay off the crease.

---

## Rollback

If launch is unstable:

1. Remove `UIApplicationSceneManifest` from `Info.plist`.
2. Remove `SceneDelegate.swift` from **Compile Sources** (keep the file in the repo).
3. Restore AppDelegate window + explicit engine setup.
4. Clean build folder / reinstall on device.

---

## Decision rule

Migrated so the window follows the active iPhone Duo display. If launch is unstable on device, use the rollback section above. A build with the iOS 27.1 SDK or later is what extends the app to the screen edge; the iOS 27 SDK still leaves a margin beside the status bar.
