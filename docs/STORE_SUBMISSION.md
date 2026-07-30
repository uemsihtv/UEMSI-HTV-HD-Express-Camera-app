# App Store & Google Play submission prep

**App:** HD Express Camera  
**Repo:** https://github.com/uemsihtv/UEMSI-HTV-HD-Express-Camera-app  
**Team (iOS):** `42U77LXQML`  
**Current version:** `1.0.0+1` in `pubspec.yaml`

---

## Status snapshot

| Item | Status |
|------|--------|
| Device QA (iPhone, iPad, P90, Fold 5) | Pass (per team) |
| Source on GitHub | Yes |
| Termly privacy / terms / EULA | Wired in About + README |
| GPL / FFmpeg disclosure | About + public repo |
| Android `applicationId` | `com.uemsihtv.hdexpress` |
| Android release signing | Upload keystore wired (`android/upload-keystore.jks` + `key.properties`, both gitignored) |
| iOS bundle ID | `uemsihtvHdExpressApp` (App Store Connect must match) |
| Live: UDP both platforms, 4 MB buffer | Shipped |
| Footage: system browser both platforms | Shipped |
| Video settings UI | Hidden (intentional) |

---

## Legal URLs (paste into store consoles)

- **Privacy:** https://app.termly.io/document/privacy-policy/2685a75d-96c1-4d72-bccf-f664ef376019  
- **Terms:** https://app.termly.io/document/terms-of-service/2685a75d-96c1-4d72-bccf-f664ef376019  
- **EULA:** https://app.termly.io/document/eula/ee845345-7d7e-41a0-969e-0913ac88cdcb  
- **Source (GPL):** https://github.com/uemsihtv/UEMSI-HTV-HD-Express-Camera-app  

---

## Remaining blockers before upload

### 1. Android upload keystore (local)

Keystore exists locally (not in git):

- `android/upload-keystore.jks`
- `android/key.properties`
- Template: `android/key.properties.example`

Back up both files securely before any machine wipe. Enable **Play App Signing** when creating the Play app; upload the first AAB signed with this upload key.

### 2. Build artifacts

```bash
# Google Play (AAB required)
flutter build appbundle --release

# App Store
flutter build ipa --release
# or Archive from Xcode (ios/Runner.xcworkspace)
```

---

## App Store Connect checklist

- [ ] Create app with matching bundle ID  
- [ ] Screenshots: iPhone 6.7" / 6.5" (+ iPad if tablet supported)  
- [ ] Description, keywords, support URL, marketing URL  
- [ ] Privacy policy URL (Termly)  
- [ ] Age rating questionnaire  
- [ ] Export compliance (encryption) answers  
- [ ] **Review notes** (critical): hardware Wi‑Fi transmitter required; SSID pattern; password `12345678`; Footage opens Safari to `http://192.168.0.1` (admin/123456); attach demo video if reviewer cannot join AP  
- [ ] Upload build via Xcode Organizer or Transporter  
- [ ] Submit for review  

**Suggested App Review notes (draft):**

> This app is a companion for the UEMSI/HTV HD Express camera Wi‑Fi transmitter. It does not use the public internet for video.  
> To test: join the transmitter Wi‑Fi (SSID like `UEMSI/HTV HDCamera 5G_xxxxxxxx` or `…2.4G_…`, password `12345678`), open the app, tap View Live Video.  
> Footage opens Safari to the device settings page at `http://192.168.0.1` (default login admin / 123456).  
> Photo/Record save to the device Photos library.  
> We can provide a demo video / loaner hardware on request.

---

## Google Play Console checklist

- [ ] Create app; set application ID to final value before first upload  
- [ ] Upload **AAB** from `build/app/outputs/bundle/release/`  
- [ ] Store listing: title, short/full description, screenshots, feature graphic  
- [ ] Privacy policy URL  
- [ ] **Data safety:** local network video; photos/videos saved on device; no account login; no sale of data  
- [ ] Content rating questionnaire  
- [ ] Target audience / news apps declarations as applicable  
- [ ] **Review notes** same hardware story as Apple  
- [ ] Internal / closed testing track first, then production  

---

## Permissions to declare accurately

- Local network / nearby Wi‑Fi (reach transmitter)  
- Photos (save snapshots and recordings)  
- Location (Android older join-Wi‑Fi flows only — confirm if still required at runtime)  

---

## Order of work (engineering)

1. ~~Confirm Android + iOS IDs~~ — Android `com.uemsihtv.hdexpress`, iOS `uemsihtvHdExpressApp`  
2. ~~Bump version to `1.0.0+1`~~  
3. ~~Create keystore + release signing~~ (local only; gitignored)  
4. Fresh install QA on all devices with store IDs  
5. Build AAB + IPA / Archive  
6. Fill consoles + submit
