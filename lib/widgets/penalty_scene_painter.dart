/// PenaltyScenePainter — penalty scene rendered as a small
/// inset in the upper-right corner of the PLAYING / RESULT
/// screen. The kiosk background is white (the chronograph
/// lives on top of it); the scene only renders the goal +
/// goalkeeper + kicker + ball in the corner.
///
/// The painter is intentionally compact — designed for a
/// box of roughly 35% of the viewport width × 40% of the
/// viewport height. Pixel art is hand-tuned for that scale.
///
/// Five animation modes:
///   * `idle`     — ball pulses with a yellow glow, kicker
///                  crouches, goalkeeper sways.
///   * `goal`     — ball flies into the net, net shakes
///                  hard, crowd raises arms.
///   * `post`     — ball ricochets off the post with sparks.
///   * `wide`     — ball streaks past the post off-screen.
///   * `over`     — ball sails over the crossbar.
///
/// Compact-only now: the full-screen mode was removed because
/// the kiosk uses a small corner inset. The painter is invoked
/// from PlayingScreen and ResultScreen with the same
/// corner-box layout.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

enum PenaltySceneAnimation {
  idle,
  goal,
  post,
  wide,
  over,
}

class PenaltyScenePainter extends CustomPainter {
  PenaltyScenePainter({
    required this.animation,
    required this.t,
    this.seed = 1337,
  });

  final PenaltySceneAnimation animation;
  final double t;
  final int seed;

  // Selección Colombia tones.
  static const Color _kAzulBandera = Color(0xFF0E1A4A);
  static const Color _kAmarilloBandera = Color(0xFFFFCD00);
  static const Color _kAmarilloOscuro = Color(0xFFE8B400);
  static const Color _kRojoBandera = Color(0xFFCE1126);
  static const Color _kBallBlack = Color(0xFF111111);
  static const Color _kSkinTone = Color(0xFFE0AC77);

  @override
  void paint(Canvas canvas, Size size) {
    // Background — TRANSPARENT so the white kiosk background
    // shows through. No green field, no sky gradient.
    // (Operator asked for the white kiosk background to remain.)

    // Field patch (small green strip at the bottom of the
    // corner box, NOT a full-screen fill — just a tiny
    // grass patch for context).
    _drawGrassPatch(canvas, size);

    // Subtle box border (CRT-style outline).
    _drawFrameBorder(canvas, size);

    // Crowd at the very top — small dots.
    _drawCrowd(canvas, size);

    // Goal frame + net (top 55% of the corner box).
    final Rect goalRect = Rect.fromLTWH(
      size.width * 0.18,
      size.height * 0.18,
      size.width * 0.64,
      size.height * 0.45,
    );
    _drawNet(canvas, goalRect, shakeT: _netShakeT());
    _drawGoalFrame(canvas, goalRect);

    // Goalkeeper in the goal (sways with verdict).
    _drawGoalkeeper(canvas, goalRect);

    // Kicker silhouette in the lower-left, crouched, breathing.
    _drawKicker(canvas, size);

    // Ball — animated by verdict. Idle has a glow halo.
    _drawBall(canvas, size);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _drawGrassPatch(Canvas canvas, Size size) {
    // Small green strip at the bottom 18% of the corner box.
    final Rect grassRect = Rect.fromLTWH(
      0,
      size.height * 0.82,
      size.width,
      size.height * 0.18,
    );
    canvas.drawRect(
      grassRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFFBFE3A2),
            Color(0xFF7FB05A),
          ],
        ).createShader(grassRect),
    );
    // Grass texture — short vertical strokes.
    final Paint grassStroke = Paint()
      ..color = const Color(0xFF4F8A3F).withValues(alpha: 0.5)
      ..strokeWidth = 1.0;
    for (double x = 4; x < size.width; x += 6) {
      final double h = 3 + _hash01(seed + x.toInt()) * 3;
      canvas.drawLine(
        Offset(x, grassRect.top + 2),
        Offset(x, grassRect.top + 2 + h),
        grassStroke,
      );
    }
  }

  void _drawFrameBorder(Canvas canvas, Size size) {
    // Thin amber inner border + thicker dark outer border —
    // gives the corner box a CRT-monitor feel.
    final Rect outer = Rect.fromLTWH(
      1.0,
      1.0,
      size.width - 2.0,
      size.height - 2.0,
    );
    canvas.drawRect(
      outer,
      Paint()
        ..color = const Color(0xFF1A1A1A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
    // Inner amber inset (3 px in from the border).
    final Rect inner = outer.deflate(3);
    canvas.drawRect(
      inner,
      Paint()
        ..color = _kAmarilloBandera.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  void _drawCrowd(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = _kAzulBandera.withValues(alpha: 0.25);
    final double baseY = size.height * 0.08;
    final int n = 18;
    for (int i = 0; i < n; i++) {
      final double fx = (i + 0.5) / n;
      final double x = fx * size.width + (_hash01(seed + i) - 0.5) * 4;
      final double r = 2.5 + _hash01(seed + i * 31) * 1.5;
      // On goal: arms raised (heads lift slightly). On misses:
      // bob normally.
      double lift = 0;
      if (animation == PenaltySceneAnimation.goal && t > 0.6) {
        lift = (math.sin(t * math.pi * 6 + i)) * 2;
      }
      canvas.drawCircle(Offset(x, baseY - r - lift), r, paint);
    }
  }

  void _drawNet(Canvas canvas, Rect goal, {required double shakeT}) {
    // Real-net look: two layers of interlaced diagonal strands
    // — a slightly faded "back" layer (gives depth) and a
    // sharper "front" layer on top, plus black knot-dots at
    // every intersection so the weave reads at the small scale.
    final double w = goal.width;
    final double h = goal.height;
    final double cell = math.min(w, h) / 7; // mesh cell size

    // 1) BACK layer — slightly inset (the net recedes 1.5 px
    //    in from the front goal frame) and drawn at lower alpha
    //    to suggest the strands behind the front plane.
    final Rect backRect = goal.deflate(1.5);
    _drawInterlacedLayer(canvas, backRect, cell,
        strandColor: const Color(0xFF000000).withValues(alpha: 0.45),
        knotColor: const Color(0xFF000000).withValues(alpha: 0.45),
        knotSize: 1.0);

    // 2) FRONT layer — sharp, on the goal rect itself.
    _drawInterlacedLayer(canvas, goal, cell,
        strandColor: const Color(0xFF111111),
        knotColor: const Color(0xFF000000),
        knotSize: 1.5);

    if (shakeT > 0) {
      // Net shake (3 horizontal lines bowing in/out).
      final double amp = (1.0 - shakeT) * 4.0;
      final Paint shake = Paint()
        ..color = const Color(0xFF111111).withValues(alpha: 0.7 * shakeT)
        ..strokeWidth = 1.5;
      for (int i = 0; i < 3; i++) {
        final double y = goal.top + goal.height * (0.3 + i * 0.2) +
            math.sin(shakeT * math.pi * 6 + i) * amp;
        canvas.drawLine(
          Offset(goal.left, y),
          Offset(goal.right, y),
          shake,
        );
      }
    }
  }

  /// One layer of the interlaced black mesh. Two sets of
  /// diagonals (\\ and //) clipped to [bounds], plus black
  /// knot-dots at every intersection.
  void _drawInterlacedLayer(
    Canvas canvas,
    Rect bounds,
    double cell, {
    required Color strandColor,
    required Color knotColor,
    required double knotSize,
  }) {
    final double w = bounds.width;
    final double h = bounds.height;
    final Paint strand = Paint()
      ..color = strandColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    // Strand set A — diagonals going down-right.
    for (double x = bounds.left - h; x <= bounds.right; x += cell) {
      final Offset start = Offset(math.max(bounds.left, x), bounds.top);
      final Offset end = Offset(
        math.min(bounds.right, x + h),
        math.min(bounds.bottom, bounds.top + h),
      );
      if (start.dx >= end.dx) continue;
      _drawClippedLine(canvas, strand, start, end, bounds);
    }
    // Strand set B — diagonals going down-left.
    for (double x = bounds.left; x <= bounds.right + h; x += cell) {
      final Offset start = Offset(math.min(bounds.right, x), bounds.top);
      final Offset end = Offset(
        math.max(bounds.left, x - h),
        math.min(bounds.bottom, bounds.top + h),
      );
      if (start.dx <= end.dx) continue;
      _drawClippedLine(canvas, strand, start, end, bounds);
    }
    // Knot dots.
    final Paint knot = Paint()..color = knotColor;
    final int nx = (w / cell).round();
    final int ny = (h / cell).round();
    for (int i = 0; i <= nx; i++) {
      for (int j = 0; j <= ny; j++) {
        final double px = bounds.left + (i * w / nx);
        final double py = bounds.top + (j * h / ny);
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(px, py),
            width: knotSize,
            height: knotSize,
          ),
          knot,
        );
      }
    }
  }

  /// Draw a line clipped to [bounds] so the net strands don't
  /// extend outside the goal rectangle.
  void _drawClippedLine(
    Canvas canvas,
    Paint paint,
    Offset start,
    Offset end,
    Rect bounds,
  ) {
    canvas.save();
    canvas.clipRect(bounds);
    canvas.drawLine(start, end, paint);
    canvas.restore();
  }

  void _drawGoalFrame(Canvas canvas, Rect goal) {
    // 3D-look yellow goal frame, drawn as a STROKE (not a
    // fill) so the net behind it shows against the kiosk
    // white background, not against yellow. Two-tone shading
    // on the posts: a bright "highlight" on the right/top
    // edges and a darker shadow on the left/bottom edges
    // give the frame a 3D look.
    final double frameT = math.max(3.0, goal.width * 0.018);
    final Rect outer = goal.inflate(frameT / 2);
    final Rect inner = goal.deflate(frameT * 0.1);

    // --- Left post (with 3D shading) ---
    // Highlight: bright amarillo thin line on the LEFT edge
    // (the sun is on the left in this scene).
    canvas.drawRect(
      outer,
      Paint()
        ..color = const Color(0xFF111111)
        ..style = PaintingStyle.stroke
        ..strokeWidth = frameT,
    );
    // Yellow fill on the LEFT half of each post/crossbar.
    final Paint postHighlight = Paint()
      ..color = _kAmarilloBandera
      ..style = PaintingStyle.fill;
    // Left post (vertical bar from top-left to bottom-left).
    canvas.drawRect(
      Rect.fromLTRB(
        outer.left,
        outer.top,
        outer.left + frameT,
        outer.bottom,
      ),
      postHighlight,
    );
    // Crossbar (horizontal bar from top-left to top-right).
    canvas.drawRect(
      Rect.fromLTRB(
        outer.left,
        outer.top,
        outer.right,
        outer.top + frameT,
      ),
      postHighlight,
    );
    // Right post (vertical bar from top-right to bottom-right).
    canvas.drawRect(
      Rect.fromLTRB(
        outer.right - frameT,
        outer.top,
        outer.right,
        outer.bottom,
      ),
      postHighlight,
    );
    // Yellow fill on the RIGHT half (slightly darker for the
    // shadow side).
    final Paint postShadow = Paint()
      ..color = _kAmarilloOscuro
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTRB(
        outer.left + frameT * 0.55,
        outer.top + frameT * 0.55,
        outer.left + frameT,
        outer.bottom,
      ),
      postShadow,
    );
    canvas.drawRect(
      Rect.fromLTRB(
        outer.left + frameT * 0.55,
        outer.top,
        outer.right,
        outer.top + frameT * 0.55,
      ),
      postShadow,
    );
    canvas.drawRect(
      Rect.fromLTRB(
        outer.right - frameT,
        outer.top + frameT * 0.55,
        outer.right - frameT * 0.55,
        outer.bottom,
      ),
      postShadow,
    );
    // Inner darker rim (the "back" of the goal frame visible
    // at the inner edge).
    canvas.drawRect(
      inner,
      Paint()
        ..color = const Color(0xFF5A4400)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  void _drawGoalkeeper(Canvas canvas, Rect goal) {
    final double cx = goal.center.dx;
    final double cy = goal.bottom - goal.height * 0.10;
    final double scale = goal.height / 90.0;

    double swayX = 0;
    double armRaise = 0;
    switch (animation) {
      case PenaltySceneAnimation.idle:
        swayX = math.sin(t * 2 * math.pi) * goal.width * 0.06;
        break;
      case PenaltySceneAnimation.goal:
        swayX = math.sin(t * math.pi * 6) * goal.width * 0.04;
        break;
      case PenaltySceneAnimation.wide:
        final double dir = t < 0.5 ? -1 : 1;
        swayX = dir * (goal.width * 0.30) * (t < 0.5 ? t * 2 : 1.0);
        break;
      case PenaltySceneAnimation.over:
        armRaise = math.sin(t * math.pi) * 1.0;
        swayX = math.sin(t * math.pi * 2) * goal.width * 0.04;
        break;
      case PenaltySceneAnimation.post:
        swayX = math.sin(t * math.pi * 4) * goal.width * 0.05;
        break;
    }

    canvas.save();
    canvas.translate(cx + swayX, cy);

    // Body (amarillo jersey)
    _paintRect(canvas, 0, -10 * scale, 12 * scale, 22 * scale, _kAmarilloBandera);
    // Azule detail on the chest
    _paintRect(canvas, -3 * scale, -4 * scale, 6 * scale, 2 * scale, _kAzulBandera);
    // Shorts (azul)
    _paintRect(canvas, -5 * scale, 12 * scale, 10 * scale, 8 * scale, _kAzulBandera);
    // Legs
    _paintRect(canvas, -4 * scale, 20 * scale, 3 * scale, 12 * scale, const Color(0xFF222222));
    _paintRect(canvas, 1 * scale, 20 * scale, 3 * scale, 12 * scale, const Color(0xFF222222));
    // Head (skin)
    canvas.drawCircle(Offset(0, -16 * scale), 5 * scale, Paint()..color = _kSkinTone);
    // Hair (dark)
    _paintRect(canvas, -4 * scale, -21 * scale, 8 * scale, 3 * scale, const Color(0xFF222222));
    // Gloves (white) — at sides normally, raised up on 'over'.
    final double gloveY = -8 * scale - armRaise * 16 * scale;
    canvas.drawCircle(
        Offset(-9 * scale, gloveY), 3 * scale, Paint()..color = const Color(0xFFFFFFFF));
    canvas.drawCircle(
        Offset(9 * scale, gloveY), 3 * scale, Paint()..color = const Color(0xFFFFFFFF));
    // Arms (skin) connecting shoulders to gloves.
    final Paint arm = Paint()
      ..color = _kSkinTone
      ..strokeWidth = 2.5 * scale
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(-5 * scale, -6 * scale),
      Offset(-9 * scale, gloveY),
      arm,
    );
    canvas.drawLine(
      Offset(5 * scale, -6 * scale),
      Offset(9 * scale, gloveY),
      arm,
    );

    canvas.restore();
  }

  void _drawKicker(Canvas canvas, Size size) {
    // Crouched kicker in the lower-left corner, behind the
    // ball. Always faces right (the goal is to the right).
    // Smaller now — ~70% of the previous scale so it doesn't
    // crowd the ball + corner box. BOTH legs connect to the
    // body's hip edge (no gap).
    final double scale = size.height * 0.015;
    final double baseX = size.width * 0.28;
    final double baseY = size.height * 0.80;
    // Breathing bob — faster on idle, slower when ball is in
    // flight.
    final double bobRate = animation == PenaltySceneAnimation.idle
        ? 2.0
        : 1.0;
    final double breathe = math.sin(t * math.pi * bobRate) * scale * 1.2;

    // Body (amarillo jersey, leaning forward) — drawn first so
    // the legs and shorts cover the body where they overlap.
    _paintRect(canvas,
        baseX - 3 * scale, baseY - 8 * scale + breathe,
        7 * scale, 11 * scale, _kAmarilloBandera);
    // Azule diagonal stripe on chest (the Selección number area)
    _paintRect(canvas,
        baseX - 2 * scale, baseY - 5 * scale + breathe,
        5 * scale, 2 * scale, _kAzulBandera);
    // Shorts (azul) — span the full hip.
    _paintRect(canvas,
        baseX - 3 * scale, baseY + 3 * scale + breathe,
        7 * scale, 4 * scale, _kAzulBandera);
    // LEFT leg (kicking, drawn back) — TOP edge (hip) at
    // baseX-3 to baseX-1 so it connects to the body's LEFT
    // edge. No gap with the body.
    _paintRect(canvas,
        baseX - 3 * scale, baseY + 4 * scale + breathe,
        2 * scale, 6 * scale, const Color(0xFF222222));
    // Planted (RIGHT) leg — TOP edge inside the body X range
    // (baseX+1 to baseX+3). Connects to the body's RIGHT edge.
    _paintRect(canvas,
        baseX + 1 * scale, baseY + 3 * scale + breathe,
        2 * scale, 7 * scale, const Color(0xFF222222));
    // Hip joint — small dark dot at the right hip (the kicking
    // hip is rotated back so the leg swings from there).
    canvas.drawCircle(
      Offset(baseX - 2 * scale, baseY + 4 * scale + breathe),
      0.8 * scale,
      Paint()..color = const Color(0xFF111111),
    );
    // Head.
    canvas.drawCircle(
      Offset(baseX, baseY - 12 * scale + breathe),
      3.5 * scale,
      Paint()..color = _kSkinTone,
    );
    // Hair.
    _paintRect(canvas,
        baseX - 3 * scale, baseY - 15 * scale + breathe,
        6 * scale, 2 * scale, const Color(0xFF222222));
  }

  // ---------------------------------------------------------------------------
  // Ball — verdict-driven trajectory, with idle glow and
  // post-impact reset.
  // ---------------------------------------------------------------------------

  void _drawBall(Canvas canvas, Size size) {
    final double ballRadius = size.width * 0.045;
    final double spotY = size.height * 0.78;
    final double startX = size.width * 0.46;
    Offset pos;
    double rx = ballRadius;
    double ry = ballRadius;
    double rotation = 0;
    double alpha = 1.0;

    switch (animation) {
      case PenaltySceneAnimation.idle:
        // Subtle wobble + glow.
        final double wobble = math.sin(t * 2 * math.pi) * ballRadius * 0.10;
        pos = Offset(startX, spotY - ballRadius + wobble);
        rotation = t * 2 * math.pi;
        _drawBallGlow(canvas, pos, ballRadius);
        break;

      case PenaltySceneAnimation.goal:
        final Rect goal = Rect.fromLTWH(
          size.width * 0.18,
          size.height * 0.18,
          size.width * 0.64,
          size.height * 0.45,
        );
        final Offset end = Offset(goal.center.dx, goal.center.dy);
        if (t < 0.6) {
          final double tt = t / 0.6;
          // Parabolic arc — peaks mid-flight.
          final double midY = (spotY - ballRadius + end.dy) / 2 - 12;
          final double x = startX + (end.dx - startX) * tt;
          final double y = _quadBezier(spotY - ballRadius, midY, end.dy, tt);
          pos = Offset(x, y);
        } else {
          pos = end;
          alpha = 1.0 - (t - 0.6) / 0.4 * 0.3;
        }
        rotation = t * 5 * math.pi;
        break;

      case PenaltySceneAnimation.post:
        final Rect goal = Rect.fromLTWH(
          size.width * 0.18,
          size.height * 0.18,
          size.width * 0.64,
          size.height * 0.45,
        );
        final double postX = goal.left + 3;
        final double postY = goal.top + goal.height * 0.30;
        if (t < 0.45) {
          final double tt = t / 0.45;
          pos = Offset.lerp(
            Offset(startX, spotY - ballRadius),
            Offset(postX, postY),
            tt,
          )!;
        } else if (t < 0.55) {
          // Spark burst at the post — ball squashed against it.
          pos = Offset(postX, postY);
          rx = ballRadius * (1.0 - (t - 0.45) / 0.10 * 0.4);
          ry = ballRadius * (1.0 + (t - 0.45) / 0.10 * 0.3);
        } else {
          final double tt = (t - 0.55) / 0.45;
          pos = Offset.lerp(
            Offset(postX, postY),
            Offset(startX + ballRadius * 2, spotY - ballRadius),
            tt,
          )!;
        }
        rotation = t * 7 * math.pi;
        _drawSparks(canvas, pos, t);
        break;

      case PenaltySceneAnimation.wide:
        final double dir = seed.isEven ? -1 : 1;
        final Rect goal = Rect.fromLTWH(
          size.width * 0.18,
          size.height * 0.18,
          size.width * 0.64,
          size.height * 0.45,
        );
        final double postX = dir < 0 ? goal.left - 4 : goal.right + 4;
        final double postY = goal.center.dy;
        pos = Offset.lerp(
          Offset(startX, spotY - ballRadius),
          Offset(postX, postY),
          t,
        )!;
        rotation = t * 9 * math.pi;
        alpha = 1.0 - (t > 0.8 ? (t - 0.8) / 0.2 * 0.7 : 0.0);
        _drawStreak(canvas, pos, dir);
        break;

      case PenaltySceneAnimation.over:
        final Rect goal = Rect.fromLTWH(
          size.width * 0.18,
          size.height * 0.18,
          size.width * 0.64,
          size.height * 0.45,
        );
        final double crossbarY = goal.top - ballRadius - 4;
        final double tt = t;
        pos = Offset(
          startX + (goal.center.dx - startX) * tt,
          (spotY - ballRadius) + (crossbarY - (spotY - ballRadius)) * tt,
        );
        rotation = t * 6 * math.pi;
        alpha = 1.0 - (t > 0.85 ? (t - 0.85) / 0.15 * 0.5 : 0.0);
        _drawStreak(canvas, pos, 0);
        break;
    }

    _drawBallOval(canvas, pos, rx, ry, rotation, alpha: alpha);
  }

  void _drawBallGlow(Canvas canvas, Offset pos, double radius) {
    // Pulsing yellow halo around the ball.
    final double pulse = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
    final double haloR = radius * (2.0 + pulse * 0.6);
    final Paint halo = Paint()
      ..color = _kAmarilloBandera.withValues(alpha: 0.25 + pulse * 0.20)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(pos, haloR, halo);
  }

  void _drawSparks(Canvas canvas, Offset pos, double t) {
    if (t < 0.40 || t > 0.65) return;
    final Paint paint = Paint()
      ..color = _kAmarilloBandera
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final double spread = (t - 0.40) * 30.0;
    for (int i = 0; i < 6; i++) {
      final double angle = i * math.pi / 3;
      canvas.drawLine(
        pos,
        Offset(pos.dx + math.cos(angle) * spread, pos.dy + math.sin(angle) * spread),
        paint,
      );
    }
  }

  void _drawStreak(Canvas canvas, Offset pos, double dir) {
    final Paint paint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.6)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(pos.dx - dir * 14, pos.dy),
      pos,
      paint,
    );
  }

  // ---------------------------------------------------------------------------
  // Ball oval drawing (handles non-round balls).
  // ---------------------------------------------------------------------------

  void _drawBallOval(
    Canvas canvas,
    Offset pos,
    double rx,
    double ry,
    double rotation, {
    double alpha = 1.0,
  }) {
    if (alpha <= 0.01) return;
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(rotation);

    // Body — gradient for shading.
    final Rect ballRect = Rect.fromCenter(
      center: Offset.zero,
      width: rx * 2,
      height: ry * 2,
    );
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
        ..strokeWidth = 1.0,
    );
    // Pentagon (squashed along with the ball).
    final double px = rx * 2 / 7;
    final Paint pentPaint = Paint()
      ..color = _kBallBlack.withValues(alpha: alpha);
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
          // Squash the pentagon vertically with the ball.
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
    canvas.restore();
  }

  void _paintRect(Canvas canvas, double x, double y, double w, double h, Color color) {
    canvas.drawRect(Rect.fromLTWH(x, y, w, h), Paint()..color = color);
  }

  double _netShakeT() {
    if (animation == PenaltySceneAnimation.goal) {
      return t > 0.55 ? (t - 0.55) / 0.45 : 0.0;
    }
    if (animation == PenaltySceneAnimation.post &&
        t > 0.45 &&
        t < 0.60) {
      return (t - 0.45) / 0.15;
    }
    return 0.0;
  }

  double _quadBezier(double p0, double p1, double p2, double t) {
    final double u = 1 - t;
    return u * u * p0 + 2 * u * t * p1 + t * t * p2;
  }

  double _hash01(int n) {
    int x = n;
    x = ((x >> 16) ^ x) * 0x45D9F3B;
    x = ((x >> 16) ^ x) * 0x45D9F3B;
    x = (x >> 16) ^ x;
    return (x & 0xFFFFFF) / 0x1000000;
  }

  @override
  bool shouldRepaint(PenaltyScenePainter old) =>
      old.animation != animation || old.t != t || old.seed != seed;
}
