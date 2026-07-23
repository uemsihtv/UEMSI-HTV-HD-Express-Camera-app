import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

import 'firmware_frame_crop.dart';

class FfmpegRecordResult {
  const FfmpegRecordResult({
    required this.sessionId,
    required this.recentLogs,
  });

  final int sessionId;
  final List<String> recentLogs;
}

class FfmpegRecorder {
  static Future<FfmpegRecordResult> startRtspToMp4VideoOnly({
    required String uri,
    required String outPath,
    required void Function(String line) onLogLine,
  }) async {
    final recent = <String>[];

    // TCP is more reliable for FFmpeg→MP4 mux; live preview may still use UDP in media_kit.
    // After releasing the player connection on Android, TCP works well for the recorder.
    const rtspTransport = 'tcp';

    // Must re-encode to apply crop (stream copy cannot filter). Crop bottom strip
    // to hide firmware blue OSD line; keep top [kFirmwareBottomCropKeepTop].
    final cropFilter = firmwareBottomCropFilter();

    final args = <String>[
      '-y',
      '-hide_banner',
      '-loglevel',
      'info',
      // Do not use -stimeout here: mobile FFmpeg Kit builds often report "Option not found"
      // (it is not a global flag in those builds). RTSP timeout is handled by demuxer defaults.
      '-rtsp_transport',
      rtspTransport,
      '-i',
      uri,
      // Stream contains A-law audio; MP4 cannot store it. Record video-only.
      '-map',
      '0:v:0',
      '-an',
      '-sn',
      '-dn',
      '-vf',
      cropFilter,
      '-c:v',
      'libx264',
      '-preset',
      'ultrafast',
      '-crf',
      '23',
      '-pix_fmt',
      'yuv420p',
      '-f',
      'mp4',
      '-movflags',
      '+frag_keyframe+empty_moov+default_base_moof',
      outPath,
    ];

    final cmd = args.map((s) => s.contains(' ') ? '"$s"' : s).join(' ');

    dynamic session;
    session = await FFmpegKit.executeAsync(
      cmd,
      (s) async {
        final rc = await s.getReturnCode();
        if (ReturnCode.isSuccess(rc) || ReturnCode.isCancel(rc)) return;
        // leave handling to caller by logs
      },
      (log) {
        final msg = log.getMessage().trim();
        if (msg.isEmpty) return;
        recent.add(msg);
        if (recent.length > 60) recent.removeAt(0);
        onLogLine(msg);
      },
    );

    return FfmpegRecordResult(
      sessionId: session.getSessionId(),
      recentLogs: List<String>.unmodifiable(recent),
    );
  }

  static Future<void> stop({int? sessionId}) async {
    if (sessionId != null) {
      await FFmpegKit.cancel(sessionId);
    } else {
      await FFmpegKit.cancel();
    }
  }
}
