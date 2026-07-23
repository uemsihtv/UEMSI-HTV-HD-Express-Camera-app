import 'dart:typed_data';
import 'dart:ui' as ui;

/// Firmware imager draws a thin blue OSD line along the bottom of the frame.
///
/// Live preview: UI-clip the contained video frame (no mpv `vf` — that broke
/// playback). Photos/recordings crop in software/FFmpeg. Same keep fraction.
const double kFirmwareBottomCropKeepTop = 0.975;

/// FFmpeg crop: full width, top [keep]% of height, origin top-left.
String firmwareBottomCropFilter({
  double keepTopFraction = kFirmwareBottomCropKeepTop,
}) {
  final keepPct = (keepTopFraction * 1000).round() / 10; // one decimal
  return 'crop=iw:ih*$keepPct/100:0:0';
}

/// Crops [keepTopFraction] of a JPEG/PNG image from the top (drops bottom strip).
Future<Uint8List> cropImageBytesBottom({
  required Uint8List bytes,
  double keepTopFraction = kFirmwareBottomCropKeepTop,
}) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final src = frame.image;
  try {
    final keepH = (src.height * keepTopFraction).floor().clamp(1, src.height);
    if (keepH >= src.height) {
      return bytes;
    }

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final srcRect = ui.Rect.fromLTWH(
      0,
      0,
      src.width.toDouble(),
      keepH.toDouble(),
    );
    final dstRect = ui.Rect.fromLTWH(
      0,
      0,
      src.width.toDouble(),
      keepH.toDouble(),
    );
    canvas.drawImageRect(src, srcRect, dstRect, ui.Paint());
    final picture = recorder.endRecording();
    final cropped = await picture.toImage(src.width, keepH);
    try {
      final out = await cropped.toByteData(format: ui.ImageByteFormat.png);
      if (out == null) return bytes;
      return out.buffer.asUint8List();
    } finally {
      cropped.dispose();
    }
  } finally {
    src.dispose();
  }
}
