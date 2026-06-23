/// CrtScanlinesPainter — thin horizontal scanlines overlay
/// drawn on top of every screen for the Selección Colombia
/// theme. Gives the kiosk a retro-arcade CRT-monitor feel
/// without compromising legibility (alpha 0.06).
///
/// The overlay is intentionally subtle:
///   * 1 px horizontal lines every 3 px at alpha 0.06.
///   * Slight vignette at the corners.
///   * Faint cyan tint on alternating rows (every 6 px) for
///     a subtle "phosphor" warmth.
///
/// Classic theme does NOT use this overlay (it would change
/// the v0.1.0-arcade look). The overlay is applied per-screen
/// via the worldcup theme's accent flag, NOT by the theme
/// itself — the screen decides whether to render it.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

class CrtScanlinesPainter extends CustomPainter {
  const CrtScanlinesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // 1) Horizontal scanlines — every 3 px.
    final Paint scanPaint = Paint()
      ..color = const Color(0xFF000000).withValues(alpha: 0.06)
      ..strokeWidth = 1.0;
    for (double y = 0; y < size.height; y += 3.0) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scanPaint);
    }

    // 2) Subtle cyan "phosphor" tint on every 6th row.
    final Paint phosphorPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.025)
      ..strokeWidth = 1.0;
    for (double y = 0; y < size.height; y += 6.0) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), phosphorPaint);
    }

    // 3) Vignette — dark corners.
    final Rect vignetteRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
      vignetteRect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: const <Color>[
            Color(0x00000000),
            Color(0x33000000),
          ],
          stops: const <double>[0.5, 1.0],
        ).createShader(vignetteRect),
    );

    // 4) Faint vertical "tracking" line on the left edge —
    //    single-pixel, low alpha. Mimics CRT roll.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, 1.0, size.height),
      Paint()..color = const Color(0xFF000000).withValues(alpha: 0.10),
    );

    // 5) Rolling bar — a brighter horizontal band that moves
    //    very slowly down the screen. Updates each repaint;
    //    the parent screen feeds a ticker so the band slides.
    //    Skipped here (the painter is static) — the rolling
    //    bar is added by the host screen as a separate layer
    //    that reads the scene ticker.
    //    Implemented below as a deterministic position from
    //    size only — no ticker required.
    final double barY = (math.sin(size.width * 0.013) * 0.5 + 0.5) *
        size.height;
    canvas.drawRect(
      Rect.fromLTWH(0, barY - 4, size.width, 8),
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.04)
        ..blendMode = BlendMode.plus,
    );
  }

  @override
  bool shouldRepaint(CrtScanlinesPainter old) => false;
}
