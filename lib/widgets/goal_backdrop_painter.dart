/// GoalBackdropPainter — full-screen goal scene used as the
/// PLAYING / RESULT screen background for the worldcup theme.
/// The ENTIRE kiosk screen IS the penalty scene — no corner box.
///
/// Layout (fractions of viewport):
///   * Yellow goal posts on left + right edges.
///   * Yellow crossbar near the top.
///   * Black interlaced net filling the goal area (subtle alpha
///     so the chronograph digits on top stay readable).
///   * Goalkeeper sprite (pixel-art, 6-colour) centered in
///     the goal, with subtle sway/bob.
///   * Ball at the penalty spot, with a gentle idle orbit
///     during PLAYING and a verdict-driven trajectory during
///     RESULT (goal / post / wide / over).
///   * CRT scanlines over everything.
///   * Grass patch at the bottom.
///
/// The chronograph numbers (fontSize 1800, dark digits) are
/// rendered ON TOP of this backdrop by the screen widget. The
/// net uses alpha 0.20 so the digits are fully readable while
/// the goal scene is visible behind them.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Ball trajectory modes for the backdrop.
enum BackdropMode {
  /// PLAYING — ball orbits gently near the penalty spot.
  idle,

  /// VICTORIA — ball flies into the net.
  goal,

  /// CASI — ball hits the post and bounces back.
  post,

  /// NI POR ASOMO — ball flies wide off-screen.
  wide,

  /// TE PASASTE — ball sails over the crossbar.
  over,
}

class GoalBackdropPainter extends CustomPainter {
  GoalBackdropPainter({
    required this.mode,
    required this.t,
    this.showField = true,
    this.seed = 1337,
  });

  final BackdropMode mode;
  final double t;

  /// When false (RESULT screen), only draw the net + ball
  /// trajectory. Skip grass, goal frame, and goalkeeper —
  /// the result screen's tinted background handles the mood.
  final bool showField;

  final int seed;

  // -- Colours ------------------------------------------------------------
  static const Color _kAmarilloBandera = Color(0xFFFFCD00);
  static const Color _kAmarilloOscuro = Color(0xFFE8B400);
  static const Color _kSkinTone = Color(0xFFE0AC77);
  static const Color _kAzulBandera = Color(0xFF0E1A4A);
  static const Color _kBallBlack = Color(0xFF111111);
  static const Color _kGloveRed = Color(0xFFE04040);

  // -- Goalkeeper sprite (10×12, tall athletic proportions) ------
  //    Head 2/12 rows (17%), body 4/12 (33%), shorts 2/12 (17%),
  //    legs 3/12 (25%), boots 1/12 (8%). Clean athletic figure.
  static const List<List<int>> _sprite = <List<int>>[
    <int>[0, 0, 0, 7, 7, 7, 7, 0, 0, 0], // 0: hair (4 wide)
    <int>[0, 0, 1, 1, 1, 1, 1, 0, 0, 0], // 1: head (6 wide)
    <int>[0, 0, 1, 1, 1, 1, 1, 0, 0, 0], // 2: head
    <int>[3, 0, 2, 2, 2, 2, 2, 0, 3, 0], // 3: gloves out + shoulders (body 5 wide)
    <int>[3, 0, 2, 2, 2, 2, 2, 0, 3, 0], // 4: arms + jersey
    <int>[0, 0, 2, 2, 2, 2, 2, 0, 0, 0], // 5: chest
    <int>[0, 0, 2, 2, 2, 2, 2, 0, 0, 0], // 6: lower chest
    <int>[0, 0, 4, 4, 4, 4, 4, 0, 0, 0], // 7: shorts (5 wide)
    <int>[0, 0, 4, 4, 4, 4, 4, 0, 0, 0], // 8: shorts
    <int>[0, 0, 5, 0, 0, 0, 5, 0, 0, 0], // 9: legs (3 columns!)
    <int>[0, 0, 5, 0, 0, 0, 5, 0, 0, 0], // 10: legs
    <int>[0, 0, 6, 0, 0, 0, 6, 0, 0, 0], // 11: boots
  ];

  static const List<Color> _palette = <Color>[
    Color(0x00000000), // 0: transparent
    _kSkinTone, // 1: skin
    _kAmarilloBandera, // 2: jersey
    _kGloveRed, // 3: gloves (red, like real keeper gloves)
    _kAzulBandera, // 4: shorts
    Color(0xFF222222), // 5: legs
    Color(0xFF111111), // 6: boots
    Color(0xFF1A1A1A), // 7: hair
  ];

  // -- Layout fractions ------------------------------------------------
  static const double _postWidth = 0.035;
  static const double _postLeft = 0.06;
  static const double _postRight = 0.91;
  static const double _crossbarTop = 0.06;
  static const double _crossbarThickness = 0.022;
  static const double _postBottom = 0.72;

  static const double _keeperY = 0.55;

  static const double _ballRestY = 0.45;
  static const double _penaltySpotX = 0.45;
  static const double _grassTop = 0.92;
  static const double _netAlpha = 0.15;
  static const double _netCell = 20.0;
  static const double _ballRadius = 35.0;

  // =====================================================================

  @override
  void paint(Canvas canvas, Size size) {
    // Net — always shown (subtle backdrop).
    _drawNet(canvas, size);

    if (showField) {
      _drawGrass(canvas, size);
      _drawGoalFrame(canvas, size);
      _drawGoalkeeper(canvas, size);
    }

    _drawBall(canvas, size);
  }

  // --- Helpers ----------------------------------------------------------

  void _drawGrass(Canvas canvas, Size size) {
    final double y = size.height * _grassTop;
    final Rect grass = Rect.fromLTRB(0, y, size.width, size.height);
    canvas.drawRect(
      grass,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFFA8D572),
            Color(0xFF5B9931),
          ],
        ).createShader(grass),
    );
    // Mowed stripes.
    final Paint stripe = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.05);
    final double startY = y + ((t * 400) % 8);
    for (double dy = -8; dy < size.height; dy += 8) {
      canvas.drawRect(
        Rect.fromLTWH(0, startY + dy, size.width, 4),
        stripe,
      );
    }
  }

  void _drawNet(Canvas canvas, Size size) {
    final double left = size.width * (_postLeft + _postWidth);
    final double right = size.width * _postRight;
    final double top = size.height * (_crossbarTop + _crossbarThickness);
    final double bottom = size.height * _postBottom;
    final Rect area = Rect.fromLTRB(left, top, right, bottom);
    final double cell = _netCell;

    final Paint strand = Paint()
      ..color = const Color(0xFF111111).withValues(alpha: _netAlpha)
      ..strokeWidth = 1.0;
    final Paint knot = Paint()
      ..color = const Color(0xFF000000).withValues(alpha: _netAlpha * 1.3);

    // Two sets of diagonals for a woven look.
    _drawInterlaced(canvas, strand, knot, area, cell);
  }

  void _drawInterlaced(
    Canvas canvas,
    Paint strand,
    Paint knot,
    Rect bounds,
    double cell,
  ) {
    canvas.save();
    canvas.clipRect(bounds);

    final double w = bounds.width;
    final double h = bounds.height;

    // Diagonals down-right.
    for (double x = bounds.left - h; x <= bounds.right; x += cell) {
      canvas.drawLine(
        Offset(math.max(bounds.left, x), bounds.top),
        Offset(math.min(bounds.right, x + h), bounds.bottom),
        strand,
      );
    }
    // Diagonals down-left.
    for (double x = bounds.left; x <= bounds.right + h; x += cell) {
      canvas.drawLine(
        Offset(math.min(bounds.right, x), bounds.top),
        Offset(math.max(bounds.left, x - h), bounds.bottom),
        strand,
      );
    }
    // Knot dots.
    final int nx = (w / cell).round();
    final int ny = (h / cell).round();
    for (int i = 0; i <= nx; i++) {
      for (int j = 0; j <= ny; j++) {
        final double px = bounds.left + (i * w / nx);
        final double py = bounds.top + (j * h / ny);
        canvas.drawRect(
          Rect.fromCenter(center: Offset(px, py), width: 1.2, height: 1.2),
          knot,
        );
      }
    }
    canvas.restore();
  }

  void _drawGoalFrame(Canvas canvas, Size size) {
    final double l = size.width * _postLeft;
    final double r = size.width * _postRight;
    final double t = size.height * _crossbarTop;
    final double b = size.height * _postBottom;
    final double postW = size.width * _postWidth;
    final double crossH = size.height * _crossbarThickness;

    final Paint postPaint = Paint()..color = _kAmarilloBandera;
    final Paint postShadow = Paint()..color = _kAmarilloOscuro;

    // Left post.
    canvas.drawRect(Rect.fromLTRB(l, t, l + postW, b), postPaint);
    canvas.drawRect(Rect.fromLTRB(l + postW * 0.55, t + crossH * 0.55,
            l + postW, b),
        postShadow);

    // Right post.
    canvas.drawRect(Rect.fromLTRB(r, t, r + postW, b), postPaint);
    canvas.drawRect(Rect.fromLTRB(r, t + crossH * 0.55,
            r + postW * 0.45, b),
        postShadow);

    // Crossbar.
    canvas.drawRect(Rect.fromLTRB(l, t, r + postW, t + crossH), postPaint);
    canvas.drawRect(Rect.fromLTRB(l + postW * 0.55, t + crossH * 0.55,
            r + postW, t + crossH),
        postShadow);

    // Thin black outline on the inner edges.
    final Paint inner = Paint()
      ..color = const Color(0xFF111111)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final Rect innerRect =
        Rect.fromLTRB(l + postW - 1, t + crossH - 1, r + 1, b + 1);
    canvas.drawRect(innerRect, inner);
  }

  void _drawGoalkeeper(Canvas canvas, Size size) {
    final double cx = size.width * 0.5;
    final double cy = size.height * _keeperY;
    // 12 rows filling ~45% of the goal height so the feet
    // are near the bottom of the goal, not floating.
    final double pixelSize = size.height * 0.034;
    final int rows = _sprite.length;
    final int cols = _sprite[0].length;

    // Horizontal sway only — wider amplitude.
    final double swayX =
        math.sin(t * 2 * math.pi) * pixelSize * 1.5;

    canvas.save();
    canvas.translate(cx + swayX, cy);

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final int idx = _sprite[r][c];
        if (idx == 0) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            (c - cols / 2) * pixelSize,
            (r - rows / 2) * pixelSize,
            pixelSize - 1.0,
            pixelSize - 1.0,
          ),
          Paint()..color = _palette[idx],
        );
      }
    }
    canvas.restore();
  }

  void _drawHeartbeatBall(
      Canvas canvas, Offset pos, double r, double scale) {
    // Scaled ball body + pentagon. The scale breathes 0.7-1.25
    // so the ball visibly 'thumps'. At peak expansion the ball
    // is 25% larger — reads as "now is the moment".
    canvas.save();
    canvas.translate(pos.dx, pos.dy);

    final double sr = r * scale;
    final Rect ballRect = Rect.fromCenter(
      center: Offset.zero,
      width: sr * 2,
      height: sr * 2,
    );
    // Body — gradient.
    canvas.drawOval(
      ballRect,
      Paint()
        ..shader = RadialGradient(
          colors: const <Color>[
            Color(0xFFFFFFFF),
            Color(0xFFE0E0E0),
          ],
        ).createShader(ballRect.inflate(sr * 0.3)),
    );
    // Outline — thicker.
    canvas.drawOval(
      ballRect,
      Paint()
        ..color = const Color(0xFF222222)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    // Pentagon (drawn as a real pentagon path).
    final double pentR = sr * 0.42;
    final Path pent = Path();
    pent.moveTo(0, -pentR);
    for (int i = 0; i < 5; i++) {
      final double a = (i * 2 + 1) * math.pi / 5 - math.pi / 2;
      pent.lineTo(math.cos(a) * pentR, math.sin(a) * pentR);
    }
    pent.close();
    canvas.drawPath(pent, Paint()..color = _kBallBlack);
    // Seam lines radiating from pentagon vertices.
    final Paint seam = Paint()
      ..color = const Color(0xFFAAAAAA).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 5; i++) {
      final double a = (i * 2 + 1) * math.pi / 5 - math.pi / 2;
      final Offset v =
          Offset(math.cos(a) * (pentR + 0.5), math.sin(a) * (pentR + 0.5));
      final Offset out =
          Offset(math.cos(a) * (sr * 0.65), math.sin(a) * (sr * 0.65));
      canvas.drawLine(v, out, seam);
    }
    // 12-oclock highlight.
    canvas.drawArc(
      ballRect.deflate(4),
      -math.pi * 0.55,
      math.pi * 0.55,
      false,
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  void _drawSonarRings(Canvas canvas, Offset pos, double r, double beat) {
    // Expanding sonar rings — like a radar or EKG. 3 rings
    // at phases 0, 0.33, 0.66 of the beat cycle. Each ring
    // grows outward and fades. Creates a "heartbeat" visual.
    for (int i = 0; i < 3; i++) {
      final double phase = (beat + i / 3.0) % 1.0; // 0..1
      final double expand = 1.2 + phase * 4.0; // ring radius in ball-radii
      final double alpha = (1.0 - phase) * 0.55;
      canvas.drawCircle(
        pos,
        r * expand,
        Paint()
          ..color = _kAmarilloBandera.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
    // Ball glow ring — pulses with beat.
    canvas.drawCircle(
      pos,
      r * (1.5 + beat * 1.2),
      Paint()
        ..color = _kAmarilloBandera.withValues(alpha: 0.20 + beat * 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  void _drawBallTrailSimple(Canvas canvas, Offset pos, double r) {
    // Subtle horizontal streak behind the ball — like motion
    // blur from the tiny drift.
    for (int i = 1; i <= 3; i++) {
      final double alpha = (4 - i) / 4.0 * 0.30;
      canvas.drawCircle(
        Offset(pos.dx - i * r * 0.5, pos.dy),
        r * 0.3 * (4 - i) / 4,
        Paint()
          ..color =
              _kAmarilloBandera.withValues(alpha: alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  void _drawBall(Canvas canvas, Size size) {
    final double r = _ballRadius;
    double x = size.width * _penaltySpotX;
    double y = size.height * _ballRestY - r;
    double rotation = 0;
    double alpha = 1.0;

    switch (mode) {
      case BackdropMode.idle: {
        // Smooth sinusoidal wave — no flicker at loop reset
        // because ALL frequencies are INTEGERS (2π·freq·t
        // always returns to sin(0)=cos(1) at t=1).
        final double goalW =
            size.width * (_postRight - _postLeft - _postWidth);
        final double goalH = size.height *
            (_postBottom - _crossbarTop - _crossbarThickness);

        // Heartbeat pulse (2 Hz, integer → seamless).
        final double beat =
            (math.sin(t * 2 * math.pi * 2) + 1) / 2;
        final double scale = 0.65 + beat * 0.55;

        // Undulating horizontal wave (1 Hz) — smooth,
        // visible sweep from post to post.
        final double waveX =
            math.sin(t * 2 * math.pi * 1) * goalW * 0.501;

        // Gentle vertical bob (3 Hz) — keeps the ball
        // 'alive' without distracting.
        final double bobY =
            math.cos(t * 2 * math.pi * 3) * goalH * 0.175;

        x += waveX;
        y += bobY;
        rotation = t * 2 * math.pi * 0.5;

        _drawHeartbeatBall(canvas, Offset(x, y), r, scale);
        _drawSonarRings(canvas, Offset(x, y), r, beat);
        _drawBallTrailSimple(canvas, Offset(x, y), r);

        break;
      }

      case BackdropMode.goal:
        final Offset end = Offset(
          size.width * 0.5,
          size.height * (_crossbarTop + _crossbarThickness + 0.06),
        );
        if (t < 0.5) {
          final double tt = t / 0.5;
          x = x + (end.dx - x) * tt;
          y = y + (end.dy - y) * tt;
        } else {
          x = end.dx;
          y = end.dy;
          alpha = 1.0 - (t - 0.5) / 0.5 * 0.3;
        }
        rotation = t * 6 * math.pi;
        break;

      case BackdropMode.post:
        final double postX = size.width * (_postLeft + _postWidth);
        if (t < 0.4) {
          final double tt = t / 0.4;
          x = x + (postX - x) * tt;
          y = y - 40 * tt;
        } else {
          final double tt = (t - 0.4) / 0.6;
          x = postX - 30 * tt;
          y = y - 40 + 30 * tt;
        }
        rotation = t * 8 * math.pi;
        break;

      case BackdropMode.wide:
        final double dir = seed.isEven ? -1 : 1;
        final double postX =
            size.width * (dir < 0 ? _postLeft : _postRight + _postWidth);
        x = x + (postX - x + dir * 60) * t;
        y = y - 30 * t;
        rotation = t * 10 * math.pi;
        alpha = 1.0 - (t > 0.7 ? (t - 0.7) / 0.3 * 0.6 : 0.0);
        break;

      case BackdropMode.over:
        final double crossY = size.height * _crossbarTop - r;
        y = y + (crossY - y) * t;
        rotation = t * 7 * math.pi;
        alpha = 1.0 - (t > 0.8 ? (t - 0.8) / 0.2 * 0.5 : 0.0);
        break;
    }

    final Offset pos = Offset(x, y);
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(rotation);

    // Ball body — gradient for 3D.
    final Rect ballRect = Rect.fromCenter(
      center: Offset.zero,
      width: r * 2,
      height: r * 2,
    );
    canvas.drawOval(
      ballRect,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            const Color(0xFFFFFFFF).withValues(alpha: alpha),
            const Color(0xFFE0E0E0).withValues(alpha: alpha),
          ],
        ).createShader(ballRect.inflate(r * 0.3)),
    );
    // Outline — thicker, reads better at distance.
    canvas.drawOval(
      ballRect,
      Paint()
        ..color = const Color(0xFF222222).withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Pentagon — drawn as a real pentagon path (5 sides),
    // much more recognizable than the old 5-cell grid-cross.
    // The pentagon is centered and sized at ~40% of the
    // ball radius so the white hexagons around it are
    // implied by the white ball body.
    final double pentR = r * 0.42;
    final Path pent = Path();
    pent.moveTo(0, -pentR);
    for (int i = 0; i < 5; i++) {
      final double a = (i * 2 + 1) * math.pi / 5 - math.pi / 2;
      pent.lineTo(math.cos(a) * pentR, math.sin(a) * pentR);
    }
    pent.close();
    final Paint pentFill = Paint()
      ..color = _kBallBlack.withValues(alpha: alpha);
    canvas.drawPath(pent, pentFill);
    // Thin dark outline on the pentagon for definition.
    canvas.drawPath(
      pent,
      Paint()
        ..color = const Color(0xFF333333).withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Seam lines — 5 short white-ish curved lines radiating
    // from each vertex of the pentagon. These are the seams
    // where the white hexagons and black pentagon meet —
    // classic soccer-ball detail.
    final Paint seam = Paint()
      ..color = const Color(0xFFAAAAAA).withValues(alpha: alpha * 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 5; i++) {
      final double a = (i * 2 + 1) * math.pi / 5 - math.pi / 2;
      final Offset v = Offset(math.cos(a) * (pentR + 0.5), math.sin(a) * (pentR + 0.5));
      final Offset out = Offset(math.cos(a) * (r * 0.65), math.sin(a) * (r * 0.65));
      canvas.drawLine(v, out, seam);
    }

    // 12-oclock highlight arc on the ball body — subtle 3D.
    canvas.drawArc(
      ballRect.deflate(4),
      -math.pi * 0.55,
      math.pi * 0.55,
      false,
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: alpha * 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(GoalBackdropPainter old) =>
      old.mode != mode || old.t != t || old.showField != showField;
}
