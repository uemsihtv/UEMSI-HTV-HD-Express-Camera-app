import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

class GallerySaver {
  static const _androidChannel = MethodChannel('uemsi_gallery_saver');

  static Future<bool> ensurePermissions() async {
    if (Platform.isIOS) {
      final ps = await PhotoManager.requestPermissionExtend();
      return ps.isAuth || ps.hasAccess;
    }
    if (Platform.isAndroid) {
      final sdk = await _androidSdkInt();
      // Android 10+ saves through MediaStore with no gallery-read permission.
      if (sdk >= 29) return true;
      final status = await Permission.storage.request();
      return status.isGranted;
    }
    return true;
  }

  static Future<void> saveImageBytes({
    required Uint8List bytes,
    required String title,
  }) async {
    final ok = await ensurePermissions();
    if (!ok) {
      throw StateError('Photo library permission not granted');
    }

    final lower = title.toLowerCase();
    final filename = lower.endsWith('.jpg') ||
            lower.endsWith('.jpeg') ||
            lower.endsWith('.png')
        ? title
        : '$title.jpg';

    if (Platform.isAndroid) {
      await _androidChannel.invokeMethod<String>('saveImage', <String, dynamic>{
        'bytes': bytes,
        'filename': filename,
      });
      return;
    }

    await PhotoManager.editor.saveImage(
      bytes,
      filename: filename,
      title: title,
    );
  }

  static Future<void> saveVideoFile({
    required File file,
    required String title,
  }) async {
    final ok = await ensurePermissions();
    if (!ok) {
      throw StateError('Photo library permission not granted');
    }

    if (Platform.isAndroid) {
      await _androidChannel.invokeMethod<String>('saveVideo', <String, dynamic>{
        'path': file.path,
        'title': title,
      });
      return;
    }

    await PhotoManager.editor.saveVideo(file, title: title);
  }

  static Future<int> _androidSdkInt() async {
    final sdk = await _androidChannel.invokeMethod<int>('sdkInt');
    return sdk ?? 0;
  }
}
