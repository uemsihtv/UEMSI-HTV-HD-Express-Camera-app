## iOS setup notes

After you run `flutter create .` (which generates `ios/`), add these to `ios/Runner/Info.plist`:

- `NSLocalNetworkUsageDescription` (required to reach `192.168.0.1`)
- `NSPhotoLibraryAddUsageDescription` (to save snapshots to Photos)

Example values:

- `NSLocalNetworkUsageDescription`: "Connect to the camera transmitter over local Wi‑Fi to show live video."
- `NSPhotoLibraryAddUsageDescription`: "Save captured photos to your library."

### Wi‑Fi “join network” prompt

If you later implement one-tap join for a known SSID (e.g. `host_ap_5g`), you’ll use `NEHotspotConfiguration` on iOS via a small Flutter platform channel/plugin.

