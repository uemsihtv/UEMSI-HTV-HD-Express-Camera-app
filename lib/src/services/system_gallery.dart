import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the system Photos (iOS) / gallery (Android) app if possible.
Future<bool> openSystemGallery() async {
  if (Platform.isIOS) {
    for (final scheme in ['photos-redirect://', 'photos://']) {
      final uri = Uri.parse(scheme);
      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  if (Platform.isAndroid) {
    // Opening content://media/external/images/media only targets the image table, so
    // videos (including saved recordings) often do not appear — especially on Samsung.
    // Prefer launching the gallery app the same way the launcher does.

    Future<bool> launchGalleryIntent(AndroidIntent intent) async {
      try {
        await intent.launch();
        return true;
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('openSystemGallery Android: $e\n$st');
        }
        return false;
      }
    }

    // 1) Prefer OEM/native gallery apps (so users land in device gallery, not Google Photos).
    //
    // Note: package names vary by OS version & region. This list covers common devices; if a
    // specific OEM build resolves differently we can add its package.
    const preferredGalleryPackages = <String>[
      // Samsung
      'com.sec.android.gallery3d',
      // Motorola
      'com.motorola.gallery',
      'com.motorola.motogallery2',
      // Xiaomi / Redmi / Poco
      'com.miui.gallery',
      // OnePlus / Oppo / Realme (varies)
      'com.oneplus.gallery',
      'com.coloros.gallery3d',
      'com.heytap.gallery',
      // Huawei
      'com.huawei.photos',
    ];

    for (final pkg in preferredGalleryPackages) {
      if (await launchGalleryIntent(
        AndroidIntent(
          action: 'android.intent.action.MAIN',
          flags: const <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
          package: pkg,
        ),
      )) {
        return true;
      }
    }

    // 2) Generic “Gallery” app home (photos + videos).
    // Some devices resolve this to Google Photos, so keep it after OEM packages.
    if (await launchGalleryIntent(
          const AndroidIntent(
            action: 'android.intent.action.MAIN',
            category: 'android.intent.category.APP_GALLERY',
            flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
          ),
        )) {
      return true;
    }

    // 3) Google Photos (common if installed).
    if (await launchGalleryIntent(
          const AndroidIntent(
            action: 'android.intent.action.MAIN',
            flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
            package: 'com.google.android.apps.photos',
          ),
        )) {
      return true;
    }

    // 4) Last resort: broad MediaStore (still not ideal on all API levels).
    return launchGalleryIntent(
      const AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: 'content://media/external/',
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      ),
    );
  }

  return false;
}
