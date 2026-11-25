import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

import 'src/app.dart';

void main() {
  // Binding, MediaKit, and runApp stay in the same zone (see runZonedGuarded).
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    MediaKit.ensureInitialized();
    // Draw behind the Duo status bar so the picture reaches the screen edge.
    // Buttons stay in SafeArea.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      if (kDebugMode) {
        debugPrint('FlutterError: ${details.exceptionAsString()}');
      }
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      if (kDebugMode) {
        debugPrint('PlatformDispatcher.onError: $error\n$stack');
      }
      return true;
    };

    runApp(const UemsiHtvApp());
  }, (error, stack) {
    if (kDebugMode) {
      debugPrint('runZonedGuarded: $error\n$stack');
    }
  });
}
