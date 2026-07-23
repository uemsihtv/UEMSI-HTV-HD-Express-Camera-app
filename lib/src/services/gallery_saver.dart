import 'dart:typed_data';
import 'dart:io';

import 'package:photo_manager/photo_manager.dart';

class GallerySaver {
  static Future<bool> ensurePermissions() async {
    final ps = await PhotoManager.requestPermissionExtend();
    return ps.isAuth || ps.hasAccess;
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
    await PhotoManager.editor.saveVideo(file, title: title);
  }
}

