import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/legal_urls.dart';
import '../../services/gallery_saver.dart';
import '../../services/ffmpeg_recorder.dart';
import '../../services/system_gallery.dart';
import '../../widgets/landing_background.dart';
import 'viewer_prefs.dart';

class ViewerScreen extends StatefulWidget {
  const ViewerScreen({super.key});

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> with WidgetsBindingObserver {
  static const _rtspHostPath = 'rtsp://192.168.0.1:554/main';
  static const _landingAsset = 'assets/images/hd_express_background.png';
  static const _txSsidPrefixUemsi = 'uemsi/htv hd express camera';
  static const _txSsidPrefixAvto = 'avtowifi_';
  static const _txSsidExactHostAp5g = 'host_ap_5g';

  /// Default [PlayerConfiguration.protocolWhitelist] omits `rtsp`; FFmpeg then cannot open RTSP.
  static const _protocolWhitelist = <String>[
    'udp',
    'rtp',
    'tcp',
    'tls',
    'data',
    'file',
    'http',
    'https',
    'crypto',
    'rtsp',
  ];

  ViewerPrefs? _prefs;

  Player? _player;
  VideoController? _videoController;
  bool _playerStarting = false;
  Timer? _healthTimer;
  Timer? _retryTimer;
  int _retryCount = 0;
  bool _healthTickInFlight = false;
  bool _resumeReachabilityBurstInFlight = false;
  Future<bool>? _probeRtspHostInFlight;

  final List<StreamSubscription<dynamic>> _playerSubs = [];
  bool _inForeground = true;
  String? _lastPlayerError;

  bool _isRecording = false;
  String? _recordingPath;
  DateTime? _recordingStartedAt;
  int? _recordingSessionId;
  Timer? _recordingUiTimer;
  Duration _recordingElapsed = Duration.zero;
  /// Ignore spurious [Player.stream.error] right after [Player.stop] / reconnect (avoids retry flicker).
  DateTime? _ignorePlaybackErrorsUntil;

  int _playerGeneration = 0;

  bool _reachable = false;
  bool _onTransmitterWifi = false;
  String _status = 'Idle';
  bool _showLiveVideo = false;

  static const _neonGreen = Color(0xFF39FF14);

  /// Set to `false` to restore the neon [CircularProgressIndicator] loaders.
  static const bool _usePooLoadingSpinner = true;
  static const _neonFg = Colors.black;

  String _formatElapsed(Duration d) {
    final total = d.inSeconds.clamp(0, 24 * 60 * 60);
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _neonLoadingSpinner({double size = 64}) {
    if (!_usePooLoadingSpinner) {
      return SizedBox.square(
        dimension: size,
        child: const CircularProgressIndicator(
          strokeWidth: 3,
          color: _neonGreen,
        ),
      );
    }
    return _SpinningPooSpinner(size: size);
  }

  Future<void> _openAboutDialog() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final neonButtonStyle = FilledButton.styleFrom(
          backgroundColor: _neonGreen,
          foregroundColor: Colors.black,
          textStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        );

        return AlertDialog(
          title: null,
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'UEMSI/HTV HD Express Camera app',
                    textAlign: TextAlign.center,
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Privacy, terms, and other legal policies open in your browser when linked below. This app uses open-source software — open third-party notices and licences when needed.',
                    textAlign: TextAlign.center,
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => _launchLegalUrl(LegalUrls.privacyPolicyUrl),
                    style: neonButtonStyle,
                    child: const Text('Privacy policy'),
                  ),
                  if (LegalUrls.dataSubjectRequestUrl != null) ...[
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: () => _launchLegalUrl(
                        LegalUrls.dataSubjectRequestUrl!,
                      ),
                      style: neonButtonStyle,
                      child: const Text('Privacy rights & data requests'),
                    ),
                  ],
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: () => _launchLegalUrl(LegalUrls.termsOfUseUrl),
                    style: neonButtonStyle,
                    child: const Text('Terms of use'),
                  ),
                  if (LegalUrls.cookiePolicyUrl != null) ...[
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: () =>
                          _launchLegalUrl(LegalUrls.cookiePolicyUrl!),
                      style: neonButtonStyle,
                      child: const Text('Cookie policy'),
                    ),
                  ],
                  if (LegalUrls.eulaUrl != null) ...[
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: () => _launchLegalUrl(LegalUrls.eulaUrl!),
                      style: neonButtonStyle,
                      child: const Text('EULA'),
                    ),
                  ],
                  if (LegalUrls.disclaimerUrl != null) ...[
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: () =>
                          _launchLegalUrl(LegalUrls.disclaimerUrl!),
                      style: neonButtonStyle,
                      child: const Text('Disclaimer'),
                    ),
                  ],
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      if (!context.mounted) return;
                      showLicensePage(
                        context: context,
                        applicationName: 'UEMSI/HTV HD Express Camera',
                      );
                    },
                    style: neonButtonStyle,
                    child: const Text('Open-source licenses'),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: () async {
                      final uri = Uri.parse('https://www.gnu.org/licenses/gpl-3.0.txt');
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                    style: neonButtonStyle,
                    child: const Text('GPLv3 text'),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: () async {
                      final uri = Uri.parse('https://github.com/arthenica/ffmpeg-kit');
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                    style: neonButtonStyle,
                    child: const Text('FFmpegKit'),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: () => _launchLegalUrl(
                      LegalUrls.sourceCodeRepositoryUrl,
                    ),
                    style: neonButtonStyle,
                    child: const Text('Source code'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: neonButtonStyle,
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _launchLegalUrl(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  ButtonStyle _neonFilledStyle() {
    return FilledButton.styleFrom(
      backgroundColor: _neonGreen,
      foregroundColor: _neonFg,
      disabledBackgroundColor: _neonGreen.withValues(alpha: 0.35),
      disabledForegroundColor: _neonFg.withValues(alpha: 0.55),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      minimumSize: const Size(0, 40),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      elevation: 4,
      shadowColor: _neonGreen.withValues(alpha: 0.5),
    );
  }

  ButtonStyle _neonFilledCompactStyle() {
    return FilledButton.styleFrom(
      backgroundColor: _neonGreen,
      foregroundColor: _neonFg,
      disabledBackgroundColor: _neonGreen.withValues(alpha: 0.35),
      disabledForegroundColor: _neonFg.withValues(alpha: 0.55),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      minimumSize: const Size(0, 36),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      elevation: 4,
      shadowColor: _neonGreen.withValues(alpha: 0.5),
    );
  }

  Future<void> _openSettingsSheet() async {
    final prefs = _prefs;
    if (prefs == null || !mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final tuningTcp = prefs.lowLatencyTuningTcp;

            final maxH = MediaQuery.sizeOf(ctx).height * 0.92;

            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(ctx).bottom,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxH),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Video settings',
                          style: Theme.of(ctx).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Low-latency tuning'),
                          subtitle: const Text(
                            'Reduces buffering to lower latency. '
                            'If video stutters, turn this off. '
                            'Reset restores the default playback settings.',
                          ),
                          value: tuningTcp,
                          onChanged: (v) async {
                            await _toggleLowLatencyTuningTcp(v);
                            setSheetState(() {});
                          },
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          style: _neonFilledStyle(),
                          onPressed: () async {
                            await _resetPlaybackSettings();
                            setSheetState(() {});
                          },
                          icon: const Icon(Icons.restart_alt),
                          label: const Text('Reset playback settings'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ViewerPrefs.load().then((p) async {
      if (!mounted) return;
      setState(() => _prefs = p);
      if (_showLiveVideo) {
        await _refreshReachabilityAndStartIfNeeded();
      }
    });
    _startHealthLoop();
    WidgetsBinding.instance.addPostFrameCallback((_) => _precacheLandingArt());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _inForeground = false;
        _healthTimer?.cancel();
        _healthTimer = null;
        unawaited(_tearDownPlayerForBackground());
        break;
      case AppLifecycleState.resumed:
        _inForeground = true;
        _startHealthLoop();
        // Coming back from Wi‑Fi settings, reachability may take a moment to flip:
        // DHCP + routing + RTSP port can lag behind the moment the app resumes.
        // Probe in a short burst so the setup card disappears promptly.
        _probeReachabilityAfterResume();
        if (_reachable && _prefs != null && _showLiveVideo && _player == null && !_playerStarting) {
          _startPlayer();
        }
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _probeReachabilityAfterResume() {
    if (_resumeReachabilityBurstInFlight) return;
    _resumeReachabilityBurstInFlight = true;
    unawaited(() async {
      try {
        await _refreshReachabilityAndStartIfNeeded();
        if (!mounted || !_inForeground || _reachable) return;
        // On Android, Wi‑Fi association may be reported before DHCP/routing is
        // usable. Probe for a bit longer (up to ~10s) so the setup card drops.
        final deadline = DateTime.now().add(const Duration(seconds: 10));
        while (mounted && _inForeground && !_reachable && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 850));
          if (!mounted || !_inForeground) return;
          await _refreshReachabilityAndStartIfNeeded();
        }
      } finally {
        _resumeReachabilityBurstInFlight = false;
      }
    }());
  }

  Future<void> _precacheLandingArt() async {
    if (!mounted) return;
    try {
      await precacheImage(
        const AssetImage(_landingAsset),
        context,
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _healthTimer?.cancel();
    _retryTimer?.cancel();
    _recordingUiTimer?.cancel();
    if (Platform.isIOS) {
      try {
        _player?.pause();
      } catch (_) {}
      try {
        _player?.stop();
      } catch (_) {}
    }
    unawaited(_stopRecording(saveToGallery: false));
    final p = _player;
    _player = null;
    _videoController = null;
    final subs = List<StreamSubscription<dynamic>>.from(_playerSubs);
    _playerSubs.clear();
    unawaited(() async {
      for (final s in subs) {
        try {
          await s.cancel();
        } catch (_) {}
      }
      await _disposePlayer(p);
    }());
    super.dispose();
  }

  Future<void> _tearDownPlayerForBackground() async {
    _retryTimer?.cancel();
    // Stop mpv event loop ASAP on iOS to reduce chance of FFI callbacks
    // firing after the Dart isolate is torn down during app termination.
    if (Platform.isIOS) {
      try {
        _player?.pause();
      } catch (_) {}
      try {
        _player?.stop();
      } catch (_) {}
    }
    await _stopRecording(saveToGallery: true);
    _playerGeneration++;
    final p = _player;
    if (p == null && !_playerStarting) return;
    await _cancelPlayerSubsAsync();
    if (mounted) {
      setState(() {
        _player = null;
        _videoController = null;
        _playerStarting = false;
      });
    }
    await _disposePlayer(p);
  }

  Future<void> _cancelPlayerSubsAsync() async {
    if (_playerSubs.isEmpty) return;
    final subs = List<StreamSubscription<dynamic>>.from(_playerSubs);
    _playerSubs.clear();
    for (final s in subs) {
      try {
        await s.cancel();
      } catch (_) {}
    }
  }

  Future<void> _disposePlayer(Player? p) async {
    if (p == null) return;
    try {
      await p.dispose();
    } catch (_) {}
  }

  String _rtspUriLowLatency() {
    // iOS: use RTSP/TCP for compatibility & stability.
    // Android: use RTSP/UDP for lowest latency.
    if (!Platform.isIOS) return _rtspHostPath;
    return '$_rtspHostPath?rtsp_transport=tcp';
  }

  PlayerConfiguration _playerConfigurationLowLatency() {
    final tuningEnabled = _prefs?.lowLatencyTuningTcp ?? false;
    return PlayerConfiguration(
      protocolWhitelist: _protocolWhitelist,
      // Low-latency buffer targets:
      // - tuning ON: very small cache (lowest latency; may stutter on weak links)
      // - tuning OFF: still low, but more forgiving
      bufferSize: tuningEnabled ? 256 * 1024 : 1 * 1024 * 1024,
    );
  }

  Future<String> _nextRecordingPath() async {
    final dir = await getApplicationDocumentsDirectory();
    final outDir = Directory('${dir.path}/Recordings');
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }
    final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
    return '${outDir.path}/UEMSI_$ts.mp4';
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;
    if (_prefs == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot record yet — try again in a moment')),
        );
      }
      return;
    }
    if (!_showLiveVideo) return;

    // Show REC immediately so Android users get feedback before path_provider / FFmpeg.
    setState(() {
      _isRecording = true;
      _recordingPath = null;
      _recordingStartedAt = DateTime.now();
      _recordingElapsed = Duration.zero;
      _status = 'Preparing recording…';
    });
    _recordingUiTimer?.cancel();
    _recordingUiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final startedAt = _recordingStartedAt;
      if (!mounted || !_isRecording || startedAt == null) return;
      setState(() => _recordingElapsed = DateTime.now().difference(startedAt));
    });

    late final String outPath;
    try {
      outPath = await _nextRecordingPath();
    } catch (e) {
      if (!mounted) return;
      _recordingUiTimer?.cancel();
      _recordingUiTimer = null;
      setState(() {
        _isRecording = false;
        _recordingPath = null;
        _recordingStartedAt = null;
        _recordingElapsed = Duration.zero;
        _status = 'Live';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create recording file: $e')),
      );
      return;
    }
    if (!mounted) return;

    setState(() {
      _recordingPath = outPath;
      _status = 'Recording…';
    });

    final uri = _rtspUriLowLatency();

    try {
      // Keep media_kit playing — do not call player.stop() here. Stopping playback
      // freed RTSP for FFmpeg but blacked out the live preview; FFmpeg runs as a second client.

      final file = File(outPath);
      await file.parent.create(recursive: true);
      if (await file.exists()) {
        // Ensure FFmpeg can overwrite an earlier failed/empty file.
        try {
          await file.delete();
        } catch (_) {}
      }

      final ffLogLines = <String>[];

      // Direct import — deferred loading was blocking / failing silently on some Android builds.
      final result = await FfmpegRecorder.startRtspToMp4VideoOnly(
        uri: uri,
        outPath: outPath,
        onLogLine: (line) {
          ffLogLines.add(line);
          if (ffLogLines.length > 60) ffLogLines.removeAt(0);
        },
      );
      _recordingSessionId = result.sessionId;

      final deadline = DateTime.now().add(const Duration(seconds: 8));
      while (DateTime.now().isBefore(deadline)) {
        final exists = await file.exists();
        final len = exists ? await file.length() : 0;
        if (len > 8 * 1024) break;
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }

      final exists = await file.exists();
      final len = exists ? await file.length() : 0;
      if (len == 0) {
        if (ffLogLines.isNotEmpty) {
          throw StateError('Recorder did not start. FFmpeg: ${ffLogLines.last}');
        }
        throw StateError('Recorder did not start');
      }
    } catch (e) {
      if (!mounted) return;
      _recordingUiTimer?.cancel();
      _recordingUiTimer = null;
      setState(() {
        _isRecording = false;
        _recordingPath = null;
        _recordingSessionId = null;
        _recordingStartedAt = null;
        _recordingElapsed = Duration.zero;
        _lastPlayerError = 'Recording error: $e';
        _status = _lastPlayerError!;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recording failed to start: $e')),
      );
    }
  }

  Future<void> _stopRecording({required bool saveToGallery}) async {
    if (!_isRecording) return;
    final path = _recordingPath;
    final sessionId = _recordingSessionId;
    _recordingUiTimer?.cancel();
    _recordingUiTimer = null;
    setState(() {
      _isRecording = false;
      _recordingStartedAt = null;
      _recordingElapsed = Duration.zero;
      _recordingSessionId = null;
    });

    try {
      await FfmpegRecorder.stop(sessionId: sessionId);
    } catch (_) {}

    // Give the recorder a moment to flush the file headers/index.
    if (path != null) {
      final file = File(path);
      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while (DateTime.now().isBefore(deadline)) {
        if (await file.exists()) {
          final len = await file.length();
          if (len > 1024) break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
    }

    if (!saveToGallery || path == null) {
      if (mounted) _syncPlayerStatus();
      return;
    }

    final permOk = await GallerySaver.ensurePermissions();
    if (!permOk) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Allow Photos / Gallery access in Settings to save this recording. '
              'The file remains in the app folder until then.',
            ),
          ),
        );
      }
      if (mounted) _syncPlayerStatus();
      return;
    }

    try {
      final f = File(path);
      if (!await f.exists()) {
        throw StateError('Recording file not found');
      }
      final len = await f.length();
      if (len == 0) {
        throw StateError('Recording file is empty');
      }
      final title = path.split('/').last;
      await GallerySaver.saveVideoFile(file: f, title: title);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved recording to Photos / Gallery')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save recording: $e')),
      );
    } finally {
      if (mounted) _syncPlayerStatus();
    }
  }

  void _bindPlayerStreams(Player player) {
    unawaited(_cancelPlayerSubsAsync());
    _playerSubs.add(player.stream.playing.listen((_) => _syncPlayerStatus()));
    _playerSubs.add(player.stream.buffering.listen((_) => _syncPlayerStatus()));
    _playerSubs.add(player.stream.error.listen(_onPlayerStreamError));
  }

  void _onPlayerStreamError(String message) {
    final ignoreUntil = _ignorePlaybackErrorsUntil;
    if (ignoreUntil != null && DateTime.now().isBefore(ignoreUntil)) {
      return;
    }
    _lastPlayerError = message;
    if (!mounted) return;
    _syncPlayerStatus();
    _scheduleRetry(reason: 'Playback error');
  }

  void _syncPlayerStatus() {
    final p = _player;
    if (p == null || !mounted) return;

    final playing = p.state.playing;
    final buffering = p.state.buffering;
    if (playing && !buffering && _lastPlayerError != null) {
      _lastPlayerError = null;
    }
    final err = _lastPlayerError;

    String next;
    if (err != null && err.isNotEmpty) {
      final clipped = err.length > 140 ? '${err.substring(0, 137)}…' : err;
      next = clipped.startsWith('Error') ? clipped : 'Error: $clipped';
    } else if (playing && !buffering) {
      next = 'Live';
    } else if (buffering) {
      next = 'Buffering…';
    } else if (_reachable) {
      next = 'Connecting…';
    } else {
      next = 'Not connected to transmitter Wi‑Fi';
    }

    if (next != _status) {
      setState(() => _status = next);
    }
  }

  void _startHealthLoop() {
    _healthTimer?.cancel();
    unawaited(_runHealthTick());
    _healthTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_runHealthTick());
    });
  }

  Future<void> _runHealthTick() async {
    if (!_inForeground) return;
    if (_healthTickInFlight) return;
    _healthTickInFlight = true;
    try {
      await _refreshWifiAssociation();
      await _refreshReachabilityAndStartIfNeeded();
    } finally {
      _healthTickInFlight = false;
    }
  }

  Future<void> _refreshWifiAssociation() async {
    // Best-effort: on iOS this requires the "Access WiFi Information" entitlement,
    // otherwise this returns null. When unavailable, we fall back to `_reachable`.
    String? ssid;
    try {
      ssid = await NetworkInfo().getWifiName();
    } catch (_) {
      ssid = null;
    }
    if (!mounted || ssid == null || ssid.isEmpty) return;
    final cleaned = ssid.replaceAll('"', '').trim();
    final onTx = _isTransmitterSsid(cleaned);
    if (onTx != _onTransmitterWifi) {
      setState(() => _onTransmitterWifi = onTx);
    }
  }

  bool _isTransmitterSsid(String ssid) {
    final s = ssid.trim().toLowerCase();
    if (s.isEmpty) return false;
    if (s == _txSsidExactHostAp5g) return true;
    if (s.startsWith(_txSsidPrefixAvto)) return true;
    if (s.startsWith(_txSsidPrefixUemsi)) return true;
    return false;
  }

  /// Single place that probes the transmitter and starts playback when appropriate.
  Future<void> _refreshReachabilityAndStartIfNeeded() async {
    final reachable = await _probeRtspHost();
    if (!mounted) return;
    if (reachable != _reachable) {
      setState(() => _reachable = reachable);
    }
    if (!reachable) {
      const msg = 'Not connected to transmitter Wi‑Fi';
      if (_status != msg) {
        setState(() => _status = msg);
      }
      return;
    }
    if (_showLiveVideo &&
        _player == null &&
        _prefs != null &&
        !_playerStarting) {
      _startPlayer();
    }
  }

  Future<bool> _probeRtspHost() async {
    final existing = _probeRtspHostInFlight;
    if (existing != null) return existing;
    final f = () async {
      try {
        final socket = await Socket.connect(
          '192.168.0.1',
          554,
          // Local AP RTSP port; keep this tight so we don’t wait seconds before
          // each retry when the user is not on the transmitter Wi‑Fi.
          timeout: const Duration(milliseconds: 1200),
        );
        socket.destroy();
        return true;
      } catch (_) {
        return false;
      } finally {
        _probeRtspHostInFlight = null;
      }
    }();
    _probeRtspHostInFlight = f;
    return f;
  }

  void _startPlayer() {
    unawaited(_startPlayerAsync());
  }

  Future<void> _startPlayerAsync() async {
    if (_playerStarting || !mounted || _prefs == null) return;
    _playerStarting = true;
    _lastPlayerError = null;
    final gen = ++_playerGeneration;
    try {
      _retryTimer?.cancel();
      _retryCount = 0;

      final previous = _player;
      if (previous != null) {
        await _cancelPlayerSubsAsync();
        _ignorePlaybackErrorsUntil =
            DateTime.now().add(const Duration(seconds: 3));
        // Do not stop/dispose `previous` until the new player is in state and the
        // Video widget is bound to the new controller. Stopping here leaves the old
        // surface on-screen but blank (e.g. low-latency toggle / settings restart).
      }
      if (!mounted) return;
      if (_prefs == null) {
        if (mounted && previous != null) {
          _bindPlayerStreams(previous);
          _syncPlayerStatus();
        }
        return;
      }
      if (gen != _playerGeneration) {
        if (mounted && previous != null) {
          _bindPlayerStreams(previous);
          _syncPlayerStatus();
        }
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      if (_prefs == null) {
        if (mounted && previous != null) {
          _bindPlayerStreams(previous);
          _syncPlayerStatus();
        }
        return;
      }
      if (gen != _playerGeneration) {
        if (mounted && previous != null) {
          _bindPlayerStreams(previous);
          _syncPlayerStatus();
        }
        return;
      }

      final uri = _rtspUriLowLatency();

      final player = Player(configuration: _playerConfigurationLowLatency());
      final videoController = VideoController(player);
      _bindPlayerStreams(player);

      if (!mounted) {
        await _disposePlayer(player);
        return;
      }

      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) {
        await _disposePlayer(player);
        return;
      }
      if (gen != _playerGeneration) {
        await _disposePlayer(player);
        if (previous != null) {
          _bindPlayerStreams(previous);
          _syncPlayerStatus();
        }
        return;
      }
      try {
        await videoController.platform.future;
      } catch (_) {
        if (!mounted) return;
        setState(() => _lastPlayerError = 'Video output failed to start');
        await _disposePlayer(player);
        if (previous != null) {
          _bindPlayerStreams(previous);
        } else if (mounted) {
          setState(() {
            _player = null;
            _videoController = null;
          });
        }
        if (mounted) _syncPlayerStatus();
        return;
      }

      if (!mounted) {
        await _disposePlayer(player);
        return;
      }
      if (gen != _playerGeneration) {
        await _disposePlayer(player);
        if (previous != null) {
          _bindPlayerStreams(previous);
          _syncPlayerStatus();
        }
        return;
      }

      _ignorePlaybackErrorsUntil =
          DateTime.now().add(const Duration(seconds: 3));
      await player.open(Media(uri));

      if (!mounted) {
        await _disposePlayer(player);
        return;
      }
      if (gen != _playerGeneration) {
        await _disposePlayer(player);
        if (previous != null) {
          _bindPlayerStreams(previous);
          _syncPlayerStatus();
        }
        return;
      }

      setState(() {
        _player = player;
        _videoController = videoController;
        _status = 'Connecting…';
      });

      if (previous != null) {
        await _disposePlayer(previous);
      }

      _syncPlayerStatus();
    } finally {
      _playerStarting = false;
    }
  }

  void _scheduleRetry({required String reason}) {
    if (_retryTimer?.isActive ?? false) return;
    if (_player == null && !_reachable) return;

    final attempt = _retryCount++;
    // Longer first delay avoids thrashing on brief RTSP hiccups (common on Android Wi‑Fi).
    final delayMs = min(8000, 2500 + 450 * pow(2, attempt).toInt());
    setState(() => _status = 'Reconnecting… ($reason)');

    _retryTimer = Timer(Duration(milliseconds: delayMs), () {
      unawaited(_retryPlayerAfterDelay());
    });
  }

  Future<void> _retryPlayerAfterDelay() async {
    if (!mounted) return;
    final p = _player;
    await _cancelPlayerSubsAsync();
    if (mounted) {
      setState(() {
        _player = null;
        _videoController = null;
      });
    }
    await _disposePlayer(p);
    if (!mounted) return;
    _lastPlayerError = null;
    if (_reachable && _prefs != null && _showLiveVideo) {
      _startPlayer();
    }
  }

  Future<void> _openLiveVideo() async {
    if (!mounted) return;
    setState(() => _showLiveVideo = true);
    if (_prefs == null) return;
    // Don’t wait for the 2s health timer: probe now so Android/iOS start RTSP promptly.
    await _refreshReachabilityAndStartIfNeeded();
  }

  Future<void> _goBackFromLive() async {
    _retryTimer?.cancel();
    if (Platform.isIOS) {
      try {
        _player?.pause();
      } catch (_) {}
      try {
        _player?.stop();
      } catch (_) {}
    }
    await _cancelPlayerSubsAsync();
    await _stopRecording(saveToGallery: true);
    final p = _player;
    if (mounted) {
      setState(() {
        _showLiveVideo = false;
        _player = null;
        _videoController = null;
        _status = 'Idle';
      });
    }
    _lastPlayerError = null;
    await _disposePlayer(p);
  }

  Future<void> _openGallery() async {
    final ok = await openSystemGallery();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Photos / gallery')),
      );
    }
  }

  Future<void> _toggleLowLatencyTuningTcp(bool enabled) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setLowLatencyTuningTcp(enabled);
    setState(() {});
    if (_reachable && _showLiveVideo) {
      await _startPlayerAsync();
    }
  }

  Future<void> _resetPlaybackSettings() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.resetPlaybackSettings();
    setState(() {});
    if (_reachable && _showLiveVideo) {
      await _startPlayerAsync();
    }
  }

  Future<void> _takeSnapshot() async {
    final p = _player;
    if (p == null) return;

    Uint8List? bytes;
    try {
      bytes = await p.screenshot(format: 'image/jpeg');
    } catch (_) {
      bytes = null;
    }

    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Snapshot failed')),
      );
      return;
    }

    final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
    await GallerySaver.saveImageBytes(bytes: bytes, title: 'UEMSI_$ts.jpg');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved to Photos')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_prefs == null) {
      return Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            const LandingBackground(assetPath: _landingAsset),
            Center(child: _neonLoadingSpinner()),
          ],
        ),
      );
    }

    if (!_showLiveVideo) {
      // Show the Wi‑Fi setup card until we're actually reachable on the transmitter network.
      // This avoids one-time dismissal causing confusion on subsequent launches.
      final showWifiPopup = !(_onTransmitterWifi || _reachable);

      Future<void> openWifiFromPopup() async {
        if (!mounted) return;
        if (Platform.isAndroid) {
          await const AndroidIntent(action: 'android.settings.WIFI_SETTINGS').launch();
        } else {
          await openAppSettings();
        }
      }

      return Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            const LandingBackground(assetPath: _landingAsset),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 280),
                            child: showWifiPopup
                                ? _DisconnectedPanel(
                                    onOpenWifi: () =>
                                        unawaited(openWifiFromPopup()),
                                  )
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      FilledButton(
                                        onPressed: () =>
                                            unawaited(_openLiveVideo()),
                                        style: _neonFilledStyle(),
                                        child: const Text(
                                          'View Live Video',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      FilledButton(
                                        onPressed: _openGallery,
                                        style: _neonFilledStyle(),
                                        child: const Text(
                                          'Gallery',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: FilledButton(
                    onPressed: _openAboutDialog,
                    style: FilledButton.styleFrom(
                      backgroundColor: _neonGreen,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      minimumSize: const Size(0, 34),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    child: const Text('About'),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final vc = _videoController;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: null,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const LandingBackground(assetPath: _landingAsset),
          // Fullscreen video (fits portrait/landscape) with controls overlaid.
          Positioned.fill(
            child: (_player == null || vc == null)
                ? (_showLiveVideo
                    ? IgnorePointer(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _neonLoadingSpinner(size: 88),
                              const SizedBox(height: 14),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 12,
                                  ),
                                  child: Text(
                                    'Loading Video...Please Wait',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _neonGreen,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _DisconnectedPanel(
                        onOpenWifi: () {
                          if (Platform.isAndroid) {
                            // Android: open Wi‑Fi settings.
                            unawaited(
                              const AndroidIntent(action: 'android.settings.WIFI_SETTINGS')
                                  .launch(),
                            );
                            return;
                          }
                          // iOS: Apple doesn't allow deep-linking to Wi‑Fi settings.
                          // Best we can do is open this app's settings page.
                          unawaited(openAppSettings());
                        },
                      ))
                : ColoredBox(
                    color: Colors.black,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Video(
                          controller: vc,
                          fit: BoxFit.contain,
                          controls: NoVideoControls,
                        ),
                        ListenableBuilder(
                          listenable: vc.notifier,
                          builder: (context, _) {
                            final ready =
                                vc.notifier.value != null && vc.id.value != null;
                            if (ready) return const SizedBox.shrink();
                            return IgnorePointer(
                              child: Center(child: _neonLoadingSpinner()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
          ),

          // Overlay controls (only buttons + gear while viewing fullscreen video).
          if (_player != null && vc != null)
            Positioned.fill(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.35),
                          shape: const CircleBorder(),
                          child: IconButton(
                            onPressed: _goBackFromLive,
                            icon: const Icon(Icons.arrow_back),
                            color: _neonGreen,
                            tooltip: 'Back',
                          ),
                        ),
                      ),
                      if (_isRecording)
                        Align(
                          alignment: Alignment.topCenter,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 12,
                              ),
                              child: Text(
                                'REC ${_formatElapsed(_recordingElapsed)}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: _neonGreen,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ),
                        ),
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: FilledButton.icon(
                          style: _neonFilledCompactStyle(),
                          onPressed: _takeSnapshot,
                          icon: const Icon(Icons.photo_camera),
                          label: const Text('Photo'),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.35),
                          shape: const CircleBorder(),
                          child: IconButton(
                            onPressed: _openSettingsSheet,
                            icon: const Icon(Icons.settings),
                            color: Colors.white,
                            tooltip: 'Settings',
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: FilledButton.icon(
                          style: _neonFilledCompactStyle(),
                          onPressed: () async {
                            if (_isRecording) {
                              await _stopRecording(saveToGallery: true);
                            } else {
                              await _startRecording();
                            }
                          },
                          icon: Icon(
                            _isRecording ? Icons.stop : Icons.fiber_manual_record,
                          ),
                          label: Text(_isRecording ? 'Stop' : 'Record'),
                        ),
                      ),
                      // (Intentionally no extra settings UI here; only buttons + gear.)
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Spinning 💩 loader for [ViewerScreen] (see `_usePooLoadingSpinner` in state class).
class _SpinningPooSpinner extends StatefulWidget {
  const _SpinningPooSpinner({required this.size});

  final double size;

  @override
  State<_SpinningPooSpinner> createState() => _SpinningPooSpinnerState();
}

class _SpinningPooSpinnerState extends State<_SpinningPooSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emojiSize = widget.size * 0.72;
    // Android: (1) Decoder/Surface often shows solid green before the first frame;
    // if our loader has no opaque backing, that reads as a "green spinner". (2) Roboto
    // emoji glyphs are often dark monochrome — tint so they stay visible on dark UI.
    final TextStyle emojiStyle = TextStyle(
      fontSize: emojiSize,
      height: 1.15,
      // Prefer color emoji on Android; gold tint helps if we fall back to Roboto mono.
      color: Platform.isAndroid ? const Color(0xFFE8C547) : null,
      fontFamily: Platform.isAndroid ? 'Noto Color Emoji' : null,
      shadows: const [
        Shadow(
          color: Color(0xA6000000),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
        Shadow(
          color: Color(0x55FFFFFF),
          blurRadius: 4,
          offset: Offset.zero,
        ),
      ],
    );
    final pad = widget.size * 0.12;
    return SizedBox.square(
      dimension: widget.size,
      child: Center(
        child: Container(
          padding: EdgeInsets.all(pad),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.82),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: widget.size * 0.15,
              ),
            ],
          ),
          child: RotationTransition(
            turns: _rotation,
            child: Text(
              '\u{1F4A9}',
              textAlign: TextAlign.center,
              style: emojiStyle,
            ),
          ),
        ),
      ),
    );
  }
}

class _DisconnectedPanel extends StatelessWidget {
  const _DisconnectedPanel({
    required this.onOpenWifi,
  });

  final VoidCallback onOpenWifi;

  static const _wifiBody =
      'Connect to the UEMSI/HTV HD Express Camera System via the Wi‑Fi '
      'settings on your mobile device. The network SSID is '
      '"UEMSI/HTV HD Express Camera 2.4/5 Ghz_xxxxxxxx" '
      '(xxxxxxxx=unique device ID). The password to connect is 12345678.\n\n'
      'Then return to this app to view live video.';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mq = MediaQuery.sizeOf(context);
    // Scroll area fits inside the card; avoids overflow when the parent gave
    // the old layout a ~90px max height (two buttons).
    final textAreaHeight = (mq.height * 0.34).clamp(140.0, 260.0);

    return Material(
      color: scheme.surface.withValues(alpha: 0.94),
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.router, size: 28, color: Color(0xFF39FF14)),
            const SizedBox(height: 8),
            SizedBox(
              height: textAreaHeight,
              child: Scrollbar(
                thumbVisibility: mq.height < 700,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Text(
                    _wifiBody,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          height: 1.35,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onOpenWifi,
              icon: const Icon(Icons.wifi, size: 20),
              label: Text(
                Platform.isAndroid ? 'Open Wi‑Fi settings' : 'Open Settings',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF39FF14),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 10,
                ),
                elevation: 4,
                shadowColor: const Color(0xFF39FF14),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
