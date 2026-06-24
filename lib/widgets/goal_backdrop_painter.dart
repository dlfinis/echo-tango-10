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
    this.seed = 1337,
  });

  final BackdropMode mode;
  final double t;
  final int seed;

  // -- Colours ------------------------------------------------------------
  static const Color _kAmarilloBandera = Color(0xFFFFCD00);
  static const Color _kAmarilloOscuro = Color(0xFFE8B400);
  static const Color _kSkinTone = Color(0xFFE0AC77);
  static const Color _kAzulBandera = Color(0xFF0E1A4A);
  static const Color _kBallBlack = Color(0xFF111111);

  // -- Goalkeeper sprite (10×9, slim athletic proportions) ----------
  static const List<List<int>> _sprite = <List<int>>[
    <int>[0, 0, 7, 7, 7, 7, 0, 0, 0, 0], // 0: hair (4 wide)
    <int>[0, 1, 1, 1, 1, 1, 1, 0, 0, 0], // 1: head + face (6 wide)
    <int>[0, 1, 1, 1, 1, 1, 1, 0, 0, 0], // 2: head
    <int>[3, 0, 2, 2, 2, 2, 0, 3, 0, 0], // 3: gloves out + jersey (4 wide)
    <int>[3, 0, 2, 2, 2, 2, 0, 3, 0, 0], // 4: arms + slim jersey
    <int>[0, 0, 2, 2, 2, 2, 0, 0, 0, 0], // 5: chest (4 wide)
    <int>[0, 0, 4, 4, 4, 4, 0, 0, 0, 0], // 6: shorts (4 wide)
    <int>[0, 0, 5, 0, 0, 5, 0, 0, 0, 0], // 7: legs
    <int>[0, 0, 6, 0, 0, 6, 0, 0, 0, 0], // 8: boots
  ];

  static const List<Color> _palette = <Color>[
    Color(0x00000000), // 0: transparent
    _kSkinTone, // 1: skin
    _kAmarilloBandera, // 2: jersey
    Color(0xFFFFFFFF), // 3: gloves
    _kAzulBandera, // 4: shorts
    Color(0xFF222222), // 5: legs
    Color(0xFF111111), // 6: boots
    Color(0xFF1A1A1A), // 7: hair
  ];

  // -- Layout fractions (proportions of the viewport) --------------------
  static const double _postWidth = 0.035;
  static const double _postLeft = 0.06;
  static const double _postRight = 0.91;
  static const double _crossbarTop = 0.06;
  static const double _crossbarThickness = 0.022;
  static const double _postBottom = 0.72;

  // Keeper sits inside the goal, centered.
  static const double _keeperY = 0.28;

  // Ball orbits through the goal.
  static const double _ballRestY = 0.48;
  static const double _penaltySpotX = 0.5;

  // Grass strip — higher up, more visible.
  static const double _grassTop = 0.80;

  // Net.
  static const double _netAlpha = 0.20;
  static const double _netCell = 24.0; // px

  // Ball.
  static const double _ballRadius = 24.0; // px

  // =====================================================================

  @override
  void paint(Canvas canvas, Size size) {
    // White background (the kiosk background shines through).
    // (Screen's Scaffold handles this.)

    // 1) Grass patch at the bottom.
    _drawGrass(canvas, size);

    // 2) Net filling the goal area.
    _drawNet(canvas, size);

    // 3) Goal frame (posts + crossbar).
    _drawGoalFrame(canvas, size);

    // 4) Goalkeeper centered in the goal.
    _drawGoalkeeper(canvas, size);

    // 5) Ball with trajectory.
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
    final double pixelSize = size.height * 0.038; // ~30px at 800
    final int rows = _sprite.length;
    final int cols = _sprite[0].length;

    // Only horizontal sway — no vertical bounce. The keeper
    // slides side to side inside the goal. Wider amplitude
    // so it actually reads as movement.
    final double swayX =
        math.sin(t * 2 * math.pi) * pixelSize * 1.8;

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

  void _drawBall(Canvas canvas, Size size) {
    final double r = _ballRadius;
    double x = size.width * _penaltySpotX;
    double y = size.height * _ballRestY - r;
    double rotation = 0;
    double alpha = 1.0;

    switch (mode) {
      case BackdropMode.idle:
        // Bounce from post to post through the goal area.
        // The ball is "aiming" — the operator watches it
        // sweep across the goal and presses at 10s.
        // A sine wave on X (post to post) and another on Y
        // (up/down through the goal) at different frequencies
        // creates a lively, unpredictable orbit.
        final double goalW = size.width * (_postRight - _postLeft - _postWidth);
        final double goalH =
            size.height * (_postBottom - _crossbarTop - _crossbarThickness);
        final double swayX =
            math.sin(t * 2.8 * math.pi) * goalW * 0.38;
        final double swayY =
            math.cos(t * 3.3 * math.pi) * goalH * 0.25;
        x += swayX;
        y += swayY;
        rotation = t * 4 * math.pi;
        _drawBallGlow(canvas, Offset(x, y), r);
        break;

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
    // Outline.
    canvas.drawOval(
      ballRect,
      Paint()
        ..color = const Color(0xFF111111).withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // Pentagon.
    final double px = r * 2 / 7;
    final Paint pentPaint = Paint()
      ..color = _kBallBlack.withValues(alpha: alpha);
    for (int ri = 0; ri < 7; ri++) {
      for (int ci = 0; ci < 7; ci++) {
        final double dx = (ci - 3) + 0.5;
        final double dy = (ri - 3) + 0.5;
        final double dist = math.sqrt(dx * dx + dy * dy);
        if (dist > 3.0) continue;
        final bool isPent = (ci == 3 && ri == 3) ||
            (ci == 3 && ri == 2) ||
            (ci == 2 && ri == 3) ||
            (ci == 4 && ri == 3) ||
            (ci == 3 && ri == 4);
        if (isPent) {
          canvas.drawRect(
            Rect.fromLTWH(
              (ci - 3) * px - px / 2,
              (ri - 3) * px - px / 2,
              px - 0.5,
              px - 0.5,
            ),
            pentPaint,
          );
        }
      }
    }
    canvas.restore();
  }

  void _drawBallGlow(Canvas canvas, Offset pos, double radius) {
    final double pulse = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
    final double outerR = radius * (2.2 + pulse * 0.6);
    canvas.drawCircle(
      pos,
      outerR,
      Paint()
        ..color = _kAmarilloBandera.withValues(alpha: 0.18 + pulse * 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    final double innerR = radius * (1.4 + pulse * 0.3);
    canvas.drawCircle(
      pos,
      innerR,
      Paint()
        ..color = _kAmarilloBandera.withValues(alpha: 0.35 + pulse * 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  @override
  bool shouldRepaint(GoalBackdropPainter old) =>
      old.mode != mode || old.t != t;
}
