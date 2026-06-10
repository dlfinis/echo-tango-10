/// Deterministic confetti effect rendered as a [CustomPainter].
///
/// The painter is given an `Animation<double>` value in `0..1` and
/// reconstructs the particle positions/colors at that point. The
/// particles themselves are computed from a fixed seed so the same
/// `value` always yields the same frame — important for tests and for
/// `repaint` to be cheap (Flutter only repaints when `value` changes).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Renders a falling-confetti field across the full canvas.
///
/// * [value] is expected to be the current animation value in `0..1`.
/// * [seed] seeds the deterministic particle distribution.
/// * [intensity] scales the number of particles (1.0 ≈ 80; the easter
///   egg passes 2.0 to double the field).
class ConfettiPainter extends CustomPainter {
  ConfettiPainter({
    required this.value,
    required this.seed,
    this.intensity = 1.0,
    this.palette = const <Color>[
      Color(0xFF00FF00), // accent
      Color(0xFFFFC107),
      Color(0xFF03A9F4),
      Color(0xFFE91E63),
      Color(0xFFFFFFFF),
    ],
  })  : assert(value >= 0.0 && value <= 1.0, 'value must be in [0, 1]'),
        assert(intensity > 0.0, 'intensity must be > 0');

  final double value;
  final int seed;
  final double intensity;
  final List<Color> palette;

  static const int _baseCount = 80;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final int count = (_baseCount * intensity).round();
    final math.Random rng = math.Random(seed);

    // Confetti lives for a few "loops" so the celebration can be longer
    // than a single second without a frame-perfect timer.
    final double t = (value * 2.5) % 1.0;

    for (int i = 0; i < count; i++) {
      // Pre-compute deterministic particle params.
      final double startX = rng.nextDouble();
      final double speed = 0.4 + rng.nextDouble() * 0.6;
      final double sway = (rng.nextDouble() - 0.5) * 0.2;
      final double sizePx = 6.0 + rng.nextDouble() * 8.0;
      final double rotation = rng.nextDouble() * math.pi * 2.0;
      final Color color = palette[i % palette.length];

      final double x = (startX + sway * t) * size.width;
      final double y = -sizePx + t * speed * size.height;

      final Paint paint = Paint()..color = color;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation + t * math.pi * 2.0);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: sizePx,
          height: sizePx * 0.6,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ConfettiPainter old) =>
      old.value != value || old.seed != seed || old.intensity != intensity;
}
