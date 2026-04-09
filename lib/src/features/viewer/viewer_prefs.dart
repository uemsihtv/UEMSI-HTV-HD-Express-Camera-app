import 'package:shared_preferences/shared_preferences.dart';

class ViewerPrefs {
  ViewerPrefs(this._sp);

  final SharedPreferences _sp;

  // Legacy key (previously used to toggle Reliable vs Low latency).
  // Kept only so reset removes it and old installs don't retain stale values.
  static const _kRtspProfileLegacy = 'rtsp_profile';
  static const _kLowLatencyTuningTcp = 'low_latency_tuning_tcp';
  static const _kKnownSsid = 'known_ssid';
  static const _kKnownPassword = 'known_password';
  static const _kWifiSetupPopupDismissed = 'wifi_setup_popup_dismissed';

  static Future<ViewerPrefs> load() async {
    final sp = await SharedPreferences.getInstance();
    return ViewerPrefs(sp);
  }

  bool get lowLatencyTuningTcp => _sp.getBool(_kLowLatencyTuningTcp) ?? false;

  Future<void> setLowLatencyTuningTcp(bool enabled) async {
    await _sp.setBool(_kLowLatencyTuningTcp, enabled);
  }

  /// After the user opens Wi‑Fi / Settings from the setup card, hide that card on return.
  bool get wifiSetupPopupDismissed =>
      _sp.getBool(_kWifiSetupPopupDismissed) ?? false;

  Future<void> setWifiSetupPopupDismissed(bool dismissed) async {
    await _sp.setBool(_kWifiSetupPopupDismissed, dismissed);
  }

  Future<void> resetPlaybackSettings() async {
    await _sp.remove(_kRtspProfileLegacy);
    await _sp.remove(_kLowLatencyTuningTcp);
  }

  String? get knownSsid => _sp.getString(_kKnownSsid);
  String? get knownPassword => _sp.getString(_kKnownPassword);

  Future<void> setKnownNetwork({
    required String ssid,
    required String password,
  }) async {
    await _sp.setString(_kKnownSsid, ssid);
    await _sp.setString(_kKnownPassword, password);
  }
}

