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

  /// NI POR ASOMO — player kicking at air. The pose is static;
  /// the scare cycle (mirrored turn-around, shrink, "¡FUERA!"
  /// overlay) is driven entirely by `t`.
  static const List<List<int>> _niFrame0 = <List<int>>[
    <int>[0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0], // head
    <int>[0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0],
    <int>[0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0], // body leaning back
    <int>[1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0],
    <int>[1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0], // arm back
    <int>[0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0], // hips
    <int>[0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0], // standing leg
    <int>[0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0],
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
    // 4-phase drama: kick → turn-around (mirrored) → red card
    // brandished with the player shrinking → card slides out +
    // text fades. Loops seamlessly at t=0/1.
    if (t < 0.10) {
      // Phase 1 — pre-kick pose.
      _drawShape(canvas, _niFrame0, body, cavity);
      return;
    }
    if (t < 0.30) {
      // Phase 2 — mirrored turn-around, looking where the
      // ball went.
      _drawShapeMirrored(canvas, _niFrame0, body, cavity);
      // Crowd boo zigzags fade in.
      _drawBooZigzags(canvas, size, (t - 0.10) / 0.20);
      return;
    }
    if (t < 0.45) {
      // Phase 3a — player faces forward, hands on head. The
      // pose is the same body silhouette but with a darker
      // shade of body (sadder) and the cavity color "sweat"
      // dots appearing.
      _drawHandsOnHead(canvas, body, cavity);
      _drawBooZigzags(canvas, size, 1.0);
      return;
    }
    if (t < 0.85) {
      // Phase 3b — RED CARD brandished. Player shrinks, card
      // slides in from the right and is held up while
      // pulsing slightly.
      final double cardT = (t - 0.45) / 0.40; // 0..1
      final double shrinkT = (t - 0.45) / 0.40; // 0..1
      final double scale = 1.0 - shrinkT * 0.5;
      canvas.save();
      canvas.translate(size.width / 2, size.height * 0.65);
      canvas.scale(scale);
      canvas.translate(-size.width / 2, -size.height * 0.65);
      _drawHandsOnHead(canvas, body, cavity);
      canvas.restore();

      _drawRedCard(canvas, size, cardT);
      // Big red ¡FUERA! pulsing text.
      final double pulse =
          1.0 + math.sin(cardT * math.pi * 4) * 0.08;
      _drawBigText(
        canvas,
        size,
        text: '¡FUERA!',
        scale: 1.4 * pulse,
        color: const Color(0xFFCE1126),
      );
      _drawBooZigzags(canvas, size, 1.0);
      return;
    }
    if (t < 0.95) {
      // Phase 4 — card slides out, text stays.
      final double cardT = 1.0 - (t - 0.85) / 0.10; // 1..0
      _drawRedCard(canvas, size, cardT);
      _drawBigText(
        canvas,
        size,
        text: '¡FUERA!',
        scale: 1.4,
        color: const Color(0xFFCE1126),
      );
      return;
    }
    // Phase 5 — text fades out.
    final double fadeT = (t - 0.95) / 0.05; // 0..1
    _drawBigText(
      canvas,
      size,
      text: '¡FUERA!',
      scale: 1.4,
      color: const Color(0xFFCE1126).withValues(alpha: 1.0 - fadeT),
    );
  }

  /// Player silhouette with hands on head — sad / "what did I
  /// do?" pose. Same 11x8 grid; arms wrap the head, body
  /// slumps forward.
  void _drawHandsOnHead(Canvas canvas, Color body, Color cavity) {
    final List<List<int>> sadPose = <List<int>>[
      <int>[0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0], // arms wrapping head
      <int>[1, 1, 0, 1, 1, 1, 0, 1, 1, 0, 0],
      <int>[1, 0, 1, 1, 1, 1, 1, 0, 1, 0, 0], // head + hands
      <int>[1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0], // head outline
      <int>[0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0], // shoulders slumped
      <int>[0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0], // body
      <int>[0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0], // legs
      <int>[0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0],
    ];
    _drawShape(canvas, sadPose, body, cavity);
  }

  /// Crowd boo zigzags — short "M" / "W" shapes around the
  /// sprite that fade in to amplify the "miss" feeling.
  void _drawBooZigzags(Canvas canvas, Size size, double alpha) {
    final Paint paint = Paint()
      ..color = const Color(0xFFFF5252).withValues(alpha: alpha * 0.75)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    final Path p1 = Path()
      ..moveTo(size.width * 0.08, size.height * 0.25)
      ..lineTo(size.width * 0.13, size.height * 0.15)
      ..lineTo(size.width * 0.18, size.height * 0.25)
      ..lineTo(size.width * 0.23, size.height * 0.15);
    final Path p2 = Path()
      ..moveTo(size.width * 0.82, size.height * 0.25)
      ..lineTo(size.width * 0.87, size.height * 0.15)
      ..lineTo(size.width * 0.92, size.height * 0.25)
      ..lineTo(size.width * 0.97, size.height * 0.15);
    final Path p3 = Path()
      ..moveTo(size.width * 0.05, size.height * 0.55)
      ..lineTo(size.width * 0.10, size.height * 0.45)
      ..lineTo(size.width * 0.15, size.height * 0.55)
      ..lineTo(size.width * 0.20, size.height * 0.45);
    final Path p4 = Path()
      ..moveTo(size.width * 0.80, size.height * 0.55)
      ..lineTo(size.width * 0.85, size.height * 0.45)
      ..lineTo(size.width * 0.90, size.height * 0.55)
      ..lineTo(size.width * 0.95, size.height * 0.45);
    canvas.drawPath(p1, paint);
    canvas.drawPath(p2, paint);
    canvas.drawPath(p3, paint);
    canvas.drawPath(p4, paint);
  }

  /// Draws a red card (referé brandishes it) at a position
  /// driven by `cardT`:
  ///   * cardT < 0.3: card slides in from the right edge.
  ///   * 0.3 ≤ cardT < 0.85: card is held up, slight wobble.
  ///   * cardT ≥ 0.85: card slides back out to the right.
  void _drawRedCard(Canvas canvas, Size size, double cardT) {
    final double cardW = size.width * 0.18;
    final double cardH = cardW * 1.5;
    // X position: slides in from right edge to ~78% of width.
    final double restingX = size.width * 0.78 - cardW / 2;
    double x;
    if (cardT < 0.3) {
      x = size.width + cardW * (1 - cardT / 0.3);
    } else if (cardT < 0.85) {
      // Held position with a tiny wobble.
      final double wobble = math.sin((cardT - 0.3) * math.pi * 6) *
          cardW *
          0.02;
      x = restingX + wobble;
    } else {
      x = restingX + cardW * ((cardT - 0.85) / 0.15);
    }
    final double y = size.height * 0.18;
    final Rect cardRect = Rect.fromLTWH(x, y, cardW, cardH);

    // Shadow.
    canvas.drawRect(
      cardRect.shift(const Offset(4, 4)),
      Paint()..color = const Color(0x66000000),
    );
    // Red body.
    canvas.drawRect(
      cardRect,
      Paint()..color = const Color(0xFFCE1126),
    );
    // Black border.
    canvas.drawRect(
      cardRect,
      Paint()
        ..color = const Color(0xFF111111)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0,
    );
    // "ROJA" label in white, centered on the card.
    final TextPainter tp = TextPainter(
      text: const TextSpan(
        text: 'ROJA',
        style: TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 28,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(
        cardRect.left + (cardW - tp.width) / 2,
        cardRect.top + (cardH - tp.height) / 2,
      ),
    );
    // Tiny diagonal stripe top-left for "shine".
    canvas.drawLine(
      Offset(cardRect.left + 6, cardRect.top + 6),
      Offset(cardRect.left + 24, cardRect.top + 6),
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.5)
        ..strokeWidth = 2.0,
    );
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

  void _drawShapeMirrored(
      Canvas canvas, List<List<int>> shape, Color body, Color cavity) {
    canvas.save();
    canvas.translate(_cols * pixelSize, 0);
    canvas.scale(-1, 1);
    _drawShape(canvas, shape, body, cavity);
    canvas.restore();
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
