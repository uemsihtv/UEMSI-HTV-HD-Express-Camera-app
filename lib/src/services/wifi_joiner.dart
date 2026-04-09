import 'dart:async';

import 'package:flutter/services.dart';

class WifiJoiner {
  static const _ch = MethodChannel('uemsi_wifi_joiner');

  static Future<bool> joinWpa({
    required String ssid,
    required String password,
  }) async {
    final ok = await _ch.invokeMethod<bool>('joinWpa', {
      'ssid': ssid,
      'password': password,
    });
    return ok ?? false;
  }
}

