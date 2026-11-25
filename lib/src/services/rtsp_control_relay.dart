import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Minimal TCP relay for the RTSP control connection (iOS only).
///
/// Why: libavformat (inside mpv/media_kit) resolves `192.168.0.1` through
/// `getaddrinfo`. When cellular is active, iOS can answer with a NAT64
/// synthesized IPv6 address (`2607:…::c0a8:1`) that routes over cellular and
/// never reaches the transmitter, so the player hangs forever on a black screen.
///
/// The player connects to `127.0.0.1:<port>` instead (nothing to translate) and
/// this relay forwards bytes to the transmitter using a plain IPv4 [Socket],
/// which is known to work. Media still flows over UDP straight from the
/// transmitter to the phone; only the small RTSP command channel passes through
/// here, and bytes are forwarded immediately with Nagle disabled.
class RtspControlRelay {
  RtspControlRelay({
    required this.upstreamHost,
    required this.upstreamPort,
    this.log,
  });

  final String upstreamHost;
  final int upstreamPort;
  final void Function(String message)? log;

  ServerSocket? _server;
  final Set<Socket> _sockets = {};

  bool get isRunning => _server != null;

  /// Valid only while [isRunning].
  int get port => _server!.port;

  Future<void> start() async {
    if (_server != null) return;
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen(
      (client) => unawaited(_onClient(server, client)),
      onError: (Object e) => log?.call('relay server error: $e'),
      onDone: () {
        if (identical(_server, server)) _server = null;
      },
    );
    log?.call('relay listening on 127.0.0.1:${server.port}');
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    final sockets = List<Socket>.from(_sockets);
    _sockets.clear();
    for (final s in sockets) {
      s.destroy();
    }
    if (server != null) {
      try {
        await server.close();
      } catch (_) {}
      log?.call('relay stopped');
    }
  }

  Future<void> _onClient(ServerSocket server, Socket client) async {
    _sockets.add(client);
    try {
      client.setOption(SocketOption.tcpNoDelay, true);
    } catch (_) {}

    Socket upstream;
    try {
      upstream = await Socket.connect(
        InternetAddress(upstreamHost, type: InternetAddressType.IPv4),
        upstreamPort,
        timeout: const Duration(seconds: 3),
      );
    } catch (e) {
      log?.call('relay upstream connect failed: $e');
      _sockets.remove(client);
      client.destroy();
      return;
    }
    _sockets.add(upstream);
    try {
      upstream.setOption(SocketOption.tcpNoDelay, true);
    } catch (_) {}
    log?.call('relay connection open (${_sockets.length ~/ 2} active)');

    final localAuthority = '127.0.0.1:${server.port}';
    final upstreamAuthority = '$upstreamHost:$upstreamPort';

    var closed = false;
    void closePair() {
      if (closed) return;
      closed = true;
      _sockets.remove(client);
      _sockets.remove(upstream);
      client.destroy();
      upstream.destroy();
    }

    client.listen(
      (data) {
        if (closed) return;
        upstream.add(_rewriteRequest(data, localAuthority, upstreamAuthority));
      },
      onDone: closePair,
      onError: (Object _) => closePair(),
      cancelOnError: true,
    );
    upstream.listen(
      (data) {
        if (closed) return;
        client.add(data);
      },
      onDone: closePair,
      onError: (Object _) => closePair(),
      cancelOnError: true,
    );
  }

  /// RTSP requests carry the URL the player was given. Present the camera with
  /// its real address so path/host matching on the camera behaves exactly as it
  /// does without the relay. Only small, text-looking chunks are touched, so
  /// interleaved binary data is never altered.
  Uint8List _rewriteRequest(Uint8List data, String from, String to) {
    if (data.isEmpty || data.length > 4096) return data;
    final first = data[0];
    final looksLikeText = first >= 0x41 && first <= 0x5a; // 'A'..'Z'
    if (!looksLikeText) return data;
    final text = latin1.decode(data);
    if (!text.contains(from)) return data;
    return Uint8List.fromList(latin1.encode(text.replaceAll(from, to)));
  }
}
