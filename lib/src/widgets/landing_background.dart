import 'dart:ui';

import 'package:flutter/material.dart';

/// Full-screen background: one asset decoded once (shared [Image] cache), two paints.
///
/// - Bottom: [BoxFit.cover] + blur → fills the screen; visible in letterboxed gutters.
/// - Top: [BoxFit.contain] → sharp artwork with no cropping.
class LandingBackground extends StatelessWidget {
  const LandingBackground({
    super.key,
    required this.assetPath,
    this.blurSigma = 28,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        // Some landscape tablets (e.g. P90) draw system nav over the bottom of a
        // full-bleed contain image and clip the logo. Fit sharp art in the safe area;
        // keep the blurred fill edge-to-edge.
        final pad = MediaQuery.paddingOf(context);
        final sharpW = (w - pad.horizontal).clamp(0.0, w);
        final sharpH = (h - pad.vertical).clamp(0.0, h);

        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFF0B0B0B)),
            ClipRect(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: blurSigma,
                  sigmaY: blurSigma,
                ),
                child: Opacity(
                  // Keep the fill, but make it read as ambient color/texture
                  // instead of a “zoomed” version of the artwork.
                  opacity: 0.35,
                  child: Image.asset(
                    assetPath,
                    fit: BoxFit.cover,
                    width: w,
                    height: h,
                    alignment: Alignment.center,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (context, error, stackTrace) =>
                        _error(assetPath),
                  ),
                ),
              ),
            ),
            // Darken the blurred layer slightly for better text contrast and to
            // further reduce perceived “stretching”.
            const ColoredBox(color: Color(0x66000000)),
            Padding(
              padding: EdgeInsets.only(
                top: pad.top,
                bottom: pad.bottom,
                left: pad.left,
                right: pad.right,
              ),
              child: Center(
                child: Image.asset(
                  assetPath,
                  fit: BoxFit.contain,
                  width: sharpW,
                  height: sharpH,
                  alignment: Alignment.center,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
