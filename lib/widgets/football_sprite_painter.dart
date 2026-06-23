/// FootballSpritePainter — single-sprite football player (or
/// referee) for the Selección Colombia (worldcup) theme. One
/// painter, four expressions, one animation phase `t` in [0, 1].
///
/// Expressions:
///   * `victoria`    — player celebrating a goal: arms raised,
///                     two-frame "jumping" loop. Body bounce +
///                     full-body rotation. Same animation
///                     contract as the classic victoria
///                     (1s repeat).
///   * `casi`        — player with hands on head, "uy casi"
///                     face. Static. Sweat drop above the head
///                     (1.25 Hz). `t` drives the drop's
///                     vertical position and alpha.
///   * `niPorAsomo`  — player kicking at air (the ball went
///                     wide). Looping scare cycle. t<0.1: in
///                     the kicking pose. 0.1≤t<0.4: mirrored
///                     (turn-around). 0.4≤t<0.95: scales 1→0
///                     while a big red "¡FUERA!" text overlay
///                     bounces in. t≥0.95: player not drawn;
///                     text fades out.
///   * `tePasaste`   — referee blowing the whistle + raised
///                     arm. One-shot explosion. Squares pulse
///                     outward in a cross pattern, then fly
///                     and fade.
///
/// Bitmap grid: 11 columns x 8 rows, identical dimensions to
/// the classic invader painter so the [ResultScreen] layout
/// (FittedBox + 128x176 natural size) needs no changes. Each
/// pose is hand-drawn pixel art (1 = body, 0 = cavity). The
/// pixel is rendered at `pixelSize` logical px; the painter
/// scales the 11x8 grid to fit via `pixelSize`.
///
/// The painter is intentionally stateless across paints
/// (rotation, bounce, drop position are all derived from
/// `t`). The widget only has to keep one `CustomPaint` and
/// re-render at the controller's tick rate.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The four expressions this painter understands. Values match
/// the `VerdictKind` enum in `lib/theme/kiosk_theme.dart` (without
/// the leading underscore / enum prefix) so the theme can pass
/// the kind directly.
enum FootballExpression { victoria, casi, niPorAsomo, tePasaste }

class FootballSpritePainter extends CustomPainter {
  FootballSpritePainter({
    required this.expression,
    required this.pixelSize,
    required this.t,
    required this.colors,
  });

  final FootballExpression expression;
  final double pixelSize;
  final double t;
  final List<Color> colors;

  static const int _cols = 11;
  static const int _rows = 8;

  /// VICTORIA — player celebrating, arms up. Two animation
  /// frames: arms swap between "high V" and "lower V" for a
  /// "waving" feel. `t` drives the bounce and rotation.
  static const List<List<int>> _victoriaFrame0 = <List<int>>[
    <int>[0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0], // head + raised arms
    <int>[0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0],
    <int>[0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0], // shoulders/body
    <int>[0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0],
    <int>[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1], // torso
    <int>[0, 1, 0, 1, 1, 1, 1, 1, 0, 1, 0], // shorts + legs split
    <int>[0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0], // legs
    <int>[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  ];
  static const List<List<int>> _victoriaFrame1 = <List<int>>[
    <int>[0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0],
    <int>[0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0],
    <int>[0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0],
    <int>[0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0],
    <int>[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    <int>[0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0], // legs together
    <int>[0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0], // feet
    <int>[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  ];

  /// CASI — player with hands on head, "uy casi" face. Static
  /// pose. The head and hands form a "head-in-hands" silhouette.
  /// The sweat drop is rendered separately, driven by `t`.
  static const List<List<int>> _casiPose = <List<int>>[
    <int>[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    <int>[0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0], // arms wrapping head
    <int>[0, 1, 1, 0, 1, 1, 0, 1, 1, 0, 0], // head + hands
    <int>[0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0],
    <int>[0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0], // shoulders
    <int>[0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0], // body
    <int>[0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0], // legs
    <int>[0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0],
  ];

  /// TE PASASTE — referee with raised arm + whistle. Static
  /// pose. The "explosion" animation (squares flying outward) is
  /// rendered separately, driven by `t`.
  static const List<List<int>> _tePose = <List<int>>[
    <int>[0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0], // head + raised arm
    <int>[0, 0, 0, 1, 0, 0, 0, 1, 1, 0, 0],
    <int>[0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0], // whistle
    <int>[0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0], // body
    <int>[0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0],
    <int>[0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0],
    <int>[0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0], // legs
    <int>[0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final Color body = colors[0];
    final Color cavity = colors.length > 1 ? colors[1] : const Color(0xFF000000);

    switch (expression) {
      case FootballExpression.victoria:
        _paintVictoria(canvas, size, body, cavity);
        break;
      case FootballExpression.casi:
        _paintCasi(canvas, size, body, cavity);
        break;
      case FootballExpression.niPorAsomo:
        _paintNiPorAsomo(canvas, size, body, cavity);
        break;
      case FootballExpression.tePasaste:
        _paintTePasaste(canvas, size, body, cavity);
        break;
    }
  }

  void _paintVictoria(Canvas canvas, Size size, Color body, Color cavity) {
    // Linear t: bounce + rotation are sin waves, so an
    // easeInOut curve would feel stuttery.
    final double bounceY = math.sin(t * 2 * math.pi) * 4.0;
    final double rotation = math.sin(t * 2 * math.pi * 4 / 3) * 0.10;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(rotation);
    canvas.translate(-size.width / 2, -size.height / 2);
    canvas.translate(0, bounceY);

    // 2-frame leg/arms cycle.
    final int legFrame = (t * 6).floor() % 2;
    final List<List<int>> shape =
        legFrame == 0 ? _victoriaFrame0 : _victoriaFrame1;
    _drawShape(canvas, shape, body, cavity);

    canvas.restore();
  }

  void _paintCasi(Canvas canvas, Size size, Color body, Color cavity) {
    _drawShape(canvas, _casiPose, body, cavity);

    // Sweat drop: position derived from `t`. At t=0 the drop is
    // just above the head; at t=1 it has fallen to the bottom
    // of the sprite and faded out.
    final double headY = pixelSize * 0;
    final double bottomY = size.height;
    final double y = headY + (bottomY - headY) * t;
    final double alpha = 1.0 - t;
    final double radius = pixelSize * 1.2;
    final Paint dropPaint = Paint()
      ..color = const Color(0xFF00B0FF).withValues(alpha: alpha);
    canvas.drawCircle(Offset(size.width / 2, y), radius, dropPaint);
  }

  void _paintNiPorAsomo(Canvas canvas, Size size, Color body, Color cavity) {
    // A soccer ball DEFLATING. Starts round, gradually squashes
    // vertically and shrinks, air leaks out (curved lines),
    // and eventually vanishes — replaced by a "¡DESINFLÓ!"
    // label that pulses. Loops seamlessly at t=0/1.
    //
    // Phase map (t in [0, 1]):
    //   0.00..0.10  full ball at center
    //   0.10..0.55  ball squashes + shrinks + air leaks out
    //   0.55..0.85  ball is a flat oval; "¡DESINFLÓ!" pulses in
    //   0.85..0.95  flat oval + label fades slightly
    //   0.95..1.00  quick re-inflate so t=1 == t=0 (seamless)
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double fullR = math.min(size.width, size.height) * 0.42;

    // Map t → deflate amount.
    //   0   = full ball (round, radius=fullR)
    //   0.55= flat-ish (rx=fullR*0.65, ry=fullR*0.18)
    //   1   = full ball again (re-inflate)
    double rx, ry, alpha;
    if (t < 0.10) {
      // Full ball — slight wobble.
      final double wobble = 1.0 + math.sin(t * 80) * 0.015;
      rx = fullR * wobble;
      ry = fullR * (2.0 - wobble);
      alpha = 1.0;
    } else if (t < 0.55) {
      // Deflating.
      final double dt = (t - 0.10) / 0.45; // 0..1
      rx = fullR * (1.0 - dt * 0.40);
      ry = fullR * (1.0 - dt * 0.85);
      alpha = 1.0;
    } else if (t < 0.85) {
      // Flat — held.
      rx = fullR * 0.55;
      ry = fullR * 0.14;
      alpha = 1.0;
    } else if (t < 0.95) {
      // Flat + label fading slightly.
      rx = fullR * 0.55;
      ry = fullR * 0.14;
      alpha = 1.0 - (t - 0.85) / 0.10 * 0.20;
    } else {
      // Quick re-inflate (0.95..1.0).
      final double inflateT = (t - 0.95) / 0.05; // 0..1
      rx = fullR * (0.55 + inflateT * 0.45);
      ry = fullR * (0.14 + inflateT * 0.86);
      alpha = 1.0;
    }

    // Air leak — curved lines coming out of the ball during
    // the deflation phase.
    if (t > 0.05 && t < 0.65) {
      final double leakAlpha = (math.sin((t - 0.05) * 8) + 1) / 2;
      final Paint leak = Paint()
        ..color = const Color(0xFFCE1126).withValues(alpha: 0.6 * leakAlpha)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      final double leakR = fullR * 0.3;
      // Three curved leak streams at different angles.
      for (int i = 0; i < 3; i++) {
        final double angle = -math.pi / 2 + (i - 1) * 0.5;
        final Offset start = Offset(
          center.dx + math.cos(angle) * rx * 0.4,
          center.dy + math.sin(angle) * ry * 0.4,
        );
        final Offset end = Offset(
          start.dx + math.cos(angle) * leakR * (1.0 + i * 0.3),
          start.dy + math.sin(angle) * leakR * (1.0 + i * 0.3),
        );
        final Path p = Path()
          ..moveTo(start.dx, start.dy)
          ..quadraticBezierTo(
            (start.dx + end.dx) / 2 + math.cos(angle + math.pi / 2) * 4,
            (start.dy + end.dy) / 2 + math.sin(angle + math.pi / 2) * 4,
            end.dx,
            end.dy,
          );
        canvas.drawPath(p, leak);
      }
    }

    // Draw the ball (oval that may be very flat).
    canvas.save();
    canvas.translate(center.dx, center.dy);
    final Rect ballRect = Rect.fromCenter(
      center: Offset.zero,
      width: rx * 2,
      height: ry * 2,
    );
    // Body (white).
    canvas.drawOval(
      ballRect,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            const Color(0xFFFFFFFF).withValues(alpha: alpha),
            const Color(0xFFE0E0E0).withValues(alpha: alpha),
          ],
        ).createShader(ballRect.inflate(rx * 0.3)),
    );
    // Outline.
    canvas.drawOval(
      ballRect,
      Paint()
        ..color = const Color(0xFF111111).withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // Pentagon (squashed along with the ball).
    if (rx > fullR * 0.25) {
      final double px = rx * 2 / 7;
      final Paint pentPaint = Paint()
        ..color = const Color(0xFF111111).withValues(alpha: alpha);
      for (int r = 0; r < 7; r++) {
        for (int c = 0; c < 7; c++) {
          final double dx = (c - 3) + 0.5;
          final double dy = (r - 3) + 0.5;
          final double dist = math.sqrt(dx * dx + dy * dy);
          if (dist > 3.0) continue;
          final bool isPent = (c == 3 && r == 3) ||
              (c == 3 && r == 2) ||
              (c == 2 && r == 3) ||
              (c == 4 && r == 3) ||
              (c == 3 && r == 4);
          if (isPent) {
            canvas.save();
            canvas.scale(1.0, ry / rx);
            canvas.drawRect(
              Rect.fromLTWH(
                (c - 3) * px - px / 2,
                (r - 3) * px - px / 2,
                px - 0.5,
                px - 0.5,
              ),
              pentPaint,
            );
            canvas.restore();
          }
        }
      }
    }
    canvas.restore();

    // "¡DESINFLÓ!" label appears once the ball is mostly flat
    // (after t=0.40) and pulses while held.
    if (t > 0.40) {
      double labelAlpha = 1.0;
      if (t > 0.85) {
        // Fade slightly with the ball (during the held-flat
        // pre-re-inflate phase).
        labelAlpha = 1.0 - (t - 0.85) / 0.10 * 0.20;
      }
      if (t > 0.95) {
        // Hide during the re-inflate snap-back so the loop is
        // seamless.
        labelAlpha = 0.0;
      }
      if (labelAlpha > 0) {
        final double pulse =
            1.0 + math.sin((t - 0.40) * math.pi * 4) * 0.06;
        _drawBigText(
          canvas,
          size,
          text: '¡DESINFLÓ!',
          scale: 1.1 * pulse,
          color: const Color(0xFFCE1126).withValues(alpha: labelAlpha),
        );
      }
    }
  }

  void _paintTePasaste(Canvas canvas, Size size, Color body, Color cavity) {
    _drawShape(canvas, _tePose, body, cavity);

    // Explosion: 4 colored squares pulse outward in a cross.
    // t<0.3: pulse (squares at small radius). t>=0.3: squares
    // fly outward and fade.
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final double maxR = math.min(size.width, size.height) * 0.6;
    final double r = t < 0.3 ? t * maxR * 0.4 : (0.3 + (t - 0.3) * 1.5) * maxR;
    final double alpha = t < 0.3 ? 1.0 : math.max(0.0, 1.0 - (t - 0.3) * 2.0);
    final double sqSize = pixelSize * 2.0;
    final Paint sqPaint = Paint();
    final List<Color> sqColors = <Color>[
      const Color(0xFFFFCD00), // yellow
      const Color(0xFF00B0FF), // sky blue
      const Color(0xFFCE1126), // red
      const Color(0xFF8BC34A), // lime
    ];
    final List<Offset> dirs = <Offset>[
      const Offset(1, 0),
      const Offset(-1, 0),
      const Offset(0, 1),
      const Offset(0, -1),
    ];
    for (int i = 0; i < 4; i++) {
      sqPaint.color = sqColors[i].withValues(alpha: alpha);
      final Offset pos = Offset(
        centerX + dirs[i].dx * r - sqSize / 2,
        centerY + dirs[i].dy * r - sqSize / 2,
      );
      canvas.drawRect(Rect.fromLTWH(pos.dx, pos.dy, sqSize, sqSize), sqPaint);
    }
  }

  void _drawShape(Canvas canvas, List<List<int>> shape, Color body, Color cavity) {
    final Paint bodyPaint = Paint()..color = body;
    final Paint cavityPaint = Paint()..color = cavity;
    for (int r = 0; r < _rows; r++) {
      for (int c = 0; c < _cols; c++) {
        final Rect rect = Rect.fromLTWH(
          c * pixelSize,
          r * pixelSize,
          pixelSize - 0.5,
          pixelSize - 0.5,
        );
        if (shape[r][c] != 0) {
          canvas.drawRect(rect, bodyPaint);
        } else {
          // Cavity (eyes, mouth): paint the screen-bg color so
          // the sprite reads as "carved out". Only do this for
          // the inner few rows so the silhouette doesn't
          // fragment.
          if (r > 0 && r < _rows - 1 && c > 0 && c < _cols - 1) {
            canvas.drawRect(rect, cavityPaint);
          }
        }
      }
    }
  }

  void _drawBigText(
    Canvas canvas,
    Size size, {
    required String text,
    required double scale,
    required Color color,
  }) {
    final ui.ParagraphBuilder pb = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      ),
    );
    pb.pushStyle(ui.TextStyle(
      color: color,
      fontSize: pixelSize * 2.5,
      fontWeight: ui.FontWeight.w900,
      letterSpacing: 1.5,
    ));
    pb.addText(text);
    final ui.Paragraph p = pb.build()
      ..layout(ui.ParagraphConstraints(width: size.width));
    canvas.save();
    canvas.translate(
      (size.width - p.maxIntrinsicWidth) / 2,
      (size.height - p.height) / 2,
    );
    canvas.scale(scale);
    canvas.drawParagraph(p, Offset.zero);
    canvas.restore();
  }

  @override
  bool shouldRepaint(FootballSpritePainter old) =>
      old.t != t ||
      old.expression != expression ||
      old.pixelSize != pixelSize ||
      old.colors != colors;
}
