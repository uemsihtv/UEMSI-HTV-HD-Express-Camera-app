import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Loads the transmitter's local web UI (`http://192.168.0.1`) over the AP only
/// (not the public internet).
///
/// Default login (`admin` / `123456`) is the manufacturer’s documented local
/// device credential — same class as the AP Wi‑Fi password. Autofill is limited
/// to host `192.168.0.1` (HTTP basic auth header + login-form fill).
class DeviceSettingsScreen extends StatefulWidget {
  const DeviceSettingsScreen({super.key});

  static const uri = 'http://192.168.0.1/';
  static const _deviceHost = '192.168.0.1';
  static const _deviceUser = 'admin';
  static const _devicePassword = '123456';
  static const _neonGreen = Color(0xFF39FF14);

  @override
  State<DeviceSettingsScreen> createState() => _DeviceSettingsScreenState();
}

class _DeviceSettingsScreenState extends State<DeviceSettingsScreen> {
  late final WebViewController _controller;
  var _loading = true;
  String? _error;

  /// Avoid re-submitting the login form on every in-page navigation.
  var _didAttemptFormAutofill = false;

  Map<String, String> get _authHeaders {
    final token = base64Encode(
      utf8.encode(
        '${DeviceSettingsScreen._deviceUser}:${DeviceSettingsScreen._devicePassword}',
      ),
    );
    return {'Authorization': 'Basic $token'};
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _error = null;
            });
          },
          onPageFinished: (url) {
            if (!mounted) return;
            setState(() => _loading = false);
            unawaited(_autofillLoginFormIfNeeded(url));
          },
          onHttpAuthRequest: (request) {
            if (request.host == DeviceSettingsScreen._deviceHost) {
              request.onProceed(
                const WebViewCredential(
                  user: DeviceSettingsScreen._deviceUser,
                  password: DeviceSettingsScreen._devicePassword,
                ),
              );
            } else {
              request.onCancel();
            }
          },
          onWebResourceError: (error) {
            if (!mounted) return;
            if (error.isForMainFrame ?? true) {
              final detail = error.description.trim();
              setState(() {
                _loading = false;
                _error =
                    'Could not reach the transmitter settings page.\n'
                    'Stay on the transmitter Wi‑Fi and try again.'
                    '${detail.isEmpty ? '' : '\n\n($detail)'}';
              });
            }
          },
        ),
      );
    unawaited(_loadDeviceSettings());
  }

  Future<void> _loadDeviceSettings() async {
    try {
      await _controller.loadRequest(
        Uri.parse(DeviceSettingsScreen.uri),
        headers: _authHeaders,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'Could not reach the transmitter settings page.\n'
            'Stay on the transmitter Wi‑Fi and try again.'
            '${kDebugMode ? '\n\n($e)' : ''}';
      });
    }
  }

  Future<void> _autofillLoginFormIfNeeded(String url) async {
    final host = Uri.tryParse(url)?.host;
    if (host != DeviceSettingsScreen._deviceHost) return;
    if (_didAttemptFormAutofill) return;

    // Fill only when the page looks like a single-password login form.
    // Does not touch password-change / multi-field settings pages.
    const js = '''
(function() {
  try {
    if (location.hostname !== '192.168.0.1') return 'skip-host';
    var passwords = document.querySelectorAll('input[type="password"]');
    if (passwords.length !== 1) return 'skip-not-login';
    var pass = passwords[0];
    var user =
      document.querySelector('input[name="username"], input[name="user"], input[name="login"], input[name="account"], input#username, input#user, input#login') ||
      document.querySelector('input[type="text"], input[type="email"]');
    if (!user) return 'skip-no-user';
    function setValue(el, value) {
      el.focus();
      el.value = value;
      el.dispatchEvent(new Event('input', { bubbles: true }));
      el.dispatchEvent(new Event('change', { bubbles: true }));
    }
    setValue(user, 'admin');
    setValue(pass, '123456');
    var btn =
      document.querySelector('button[type="submit"], input[type="submit"]') ||
      document.querySelector('button.login, #login, input[value="Login"], input[value="login"], input[value="LOGIN"]');
    if (btn) btn.click();
    return 'ok';
  } catch (e) {
    return 'error';
  }
})();
''';

    try {
      final result = await _controller.runJavaScriptReturningResult(js);
      final s = result.toString();
      // Mark attempted once we ran on the device host (success or not-login).
      if (s.contains('ok') || s.contains('skip-not-login')) {
        _didAttemptFormAutofill = true;
      }
    } catch (_) {
      // Page may not support JS eval; user can log in manually.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: DeviceSettingsScreen._neonGreen,
        title: const Text(
          'Device Settings',
          style: TextStyle(
            color: DeviceSettingsScreen._neonGreen,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Reload',
            onPressed: () {
              setState(() {
                _error = null;
                _loading = true;
                _didAttemptFormAutofill = false;
              });
              unawaited(_loadDeviceSettings());
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_error == null) WebViewWidget(controller: _controller),
          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: DeviceSettingsScreen._neonGreen,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () {
                        setState(() {
                          _error = null;
                          _loading = true;
                          _didAttemptFormAutofill = false;
                        });
                        unawaited(_loadDeviceSettings());
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          if (_loading && _error == null)
            const Center(
              child: CircularProgressIndicator(
                color: DeviceSettingsScreen._neonGreen,
              ),
            ),
        ],
      ),
    );
  }
}
