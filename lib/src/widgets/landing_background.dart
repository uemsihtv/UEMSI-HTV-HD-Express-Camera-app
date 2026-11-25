import 'dart:ui';

import 'package:flutter/material.dart';

/// Edge-to-edge landing art that never crops the artwork.
///
/// - Bottom: a blurred [BoxFit.cover] copy fills the whole display, including
///   behind the status bar, so no black bands show on the iPhone Duo's outer
///   (portrait) or inner (squarer) screens.
/// - Top: the sharp artwork uses [BoxFit.contain] inside the safe area, so the
///   title and the UEMSI/HTV logo are always fully visible.
class LandingBackground extends StatelessWidget {
  const LandingBackground({
    super.key,
    required this.assetPath,
    this.blurSigma = 24,
  });

  final String assetPath;
  final double blurSigma;

  static Widget _error(String assetPath) {
    return ColoredBox(
      color: const Color(0xFF1A1A1A),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Missing asset:\n$assetPath\n\nRun: flutter pub get\nThen: flutter clean && flutter run',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF0B0B0B)),
        ClipRect(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: blurSigma,
              sigmaY: blurSigma,
              tileMode: TileMode.mirror,
            ),
            child: Opacity(
              opacity: 0.9,
              child: Image.asset(
                assetPath,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
                errorBuilder: (context, error, stackTrace) => _error(assetPath),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(pad.left, pad.top, pad.right, pad.bottom),
          child: Image.asset(
            assetPath,
            fit: BoxFit.contain,
            alignment: Alignment.center,
            gaplessPlayback: true,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}
