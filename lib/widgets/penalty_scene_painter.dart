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
  static const Color _kBallBlack = Color(0xFF111111);
  static const Color _kSkinTone = Color(0xFFE0AC77);

  // Goalkeeper pixel-art sprite — 12 columns × 10 rows,
  // coloured with 6 palette entries. Values reference
  // _kGoalkeeperPalette below (index 0 = transparent).
  static const List<List<int>> _goalkeeperSprite = <List<int>>[
    <int>[0, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 0], // 0: hair
    <int>[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1], // 1: head
    <int>[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1], // 2: head
    <int>[3, 0, 2, 2, 2, 2, 2, 2, 2, 2, 0, 3], // 3: gloves + shoulders
    <int>[3, 0, 2, 2, 2, 2, 2, 2, 2, 2, 0, 3], // 4: arms spread
    <int>[0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0], // 5: chest
    <int>[0, 0, 4, 4, 4, 4, 4, 4, 4, 4, 0, 0], // 6: shorts
    <int>[0, 0, 5, 5, 0, 0, 0, 0, 5, 5, 0, 0], // 7: legs
    <int>[0, 0, 6, 6, 0, 0, 0, 0, 6, 6, 0, 0], // 8: boots
    <int>[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], // 9: ground
  ];

  /// Palette matching the indices in [_goalkeeperSprite].
  /// Index 0 = transparent (not drawn).
  static const List<Color> _goalkeeperPalette = <Color>[
    Color(0x00000000), // 0: transparent
    _kSkinTone, // 1: head / skin
    _kAmarilloBandera, // 2: jersey
    Color(0xFFFFFFFF), // 3: gloves
    _kAzulBandera, // 4: shorts
    Color(0xFF222222), // 5: legs
    Color(0xFF111111), // 6: boots
    Color(0xFF1A1A1A), // 7: hair
  ];

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

    // Goal frame + net (top 40% of the corner box — smaller
    // and higher so the bigger kicker has room below).
    final Rect goalRect = Rect.fromLTWH(
      size.width * 0.18,
      size.height * 0.05,
      size.width * 0.64,
      size.height * 0.35,
    );
    _drawNet(canvas, goalRect, shakeT: _netShakeT());
    _drawGoalFrame(canvas, goalRect);

    // Goalkeeper in the goal (sways + jumps with verdict).
    _drawGoalkeeper(canvas, goalRect);

    // Ball — animated by verdict. Idle has a bigger glow halo
    // and grass-kick-up particles for a dynamic, alive feel.
    _drawGrassKickUp(canvas, size);
    _drawBall(canvas, size);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _drawGrassPatch(Canvas canvas, Size size) {
    // Bigger grass strip at the bottom 30% of the corner box
    // so the ball + kicker have a real "field" to stand on.
    final Rect grassRect = Rect.fromLTWH(
      0,
      size.height * 0.70,
      size.width,
      size.height * 0.30,
    );
    canvas.drawRect(
      grassRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFFA8D572),
            Color(0xFF6BAA3D),
            Color(0xFF3F8023),
          ],
        ).createShader(grassRect),
    );
    // Mowed-grass stripes for a stadium feel.
    final Paint stripePaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.06);
    for (double y = grassRect.top; y < grassRect.bottom; y += 8) {
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, 4),
        stripePaint,
      );
    }
    // Grass blades — short vertical strokes, denser than before.
    final Paint grassStroke = Paint()
      ..color = const Color(0xFF2F6818).withValues(alpha: 0.7)
      ..strokeWidth = 1.0;
    final Paint grassStroke2 = Paint()
      ..color = const Color(0xFF8FC85A).withValues(alpha: 0.5)
      ..strokeWidth = 1.0;
    for (double x = 3; x < size.width; x += 4) {
      final double h = 3 + _hash01(seed + x.toInt()) * 3;
      canvas.drawLine(
        Offset(x, grassRect.top + 1),
        Offset(x, grassRect.top + 1 + h),
        grassStroke,
      );
      // Lighter highlight blade.
      canvas.drawLine(
        Offset(x + 1, grassRect.top + 2),
        Offset(x + 1, grassRect.top + 2 + h * 0.7),
        grassStroke2,
      );
    }
    // Top edge of the grass — a darker line for definition.
    canvas.drawLine(
      Offset(0, grassRect.top),
      Offset(size.width, grassRect.top),
      Paint()
        ..color = const Color(0xFF2F6818).withValues(alpha: 0.4)
        ..strokeWidth = 0.5,
    );
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
    final double cy = goal.bottom - goal.height * 0.15;
    final double pixelSize = goal.height / _goalkeeperSprite.length;
    final int rows = _goalkeeperSprite.length;
    final int cols = _goalkeeperSprite[0].length;

    double swayX = 0;
    double bobY = 0;
    switch (animation) {
      case PenaltySceneAnimation.idle:
        swayX = math.sin(t * 2 * math.pi) * goal.width * 0.06;
        bobY = math.sin(t * 4 * math.pi) * goal.height * 0.06;
        break;
      case PenaltySceneAnimation.goal:
        swayX = math.sin(t * math.pi * 6) * goal.width * 0.04;
        break;
      case PenaltySceneAnimation.wide:
        final double dir = t < 0.5 ? -1 : 1;
        swayX = dir * (goal.width * 0.30) * (t < 0.5 ? t * 2 : 1.0);
        break;
      case PenaltySceneAnimation.over:
        swayX = math.sin(t * math.pi * 2) * goal.width * 0.04;
        break;
      case PenaltySceneAnimation.post:
        swayX = math.sin(t * math.pi * 4) * goal.width * 0.05;
        break;
    }

    canvas.save();
    canvas.translate(cx + swayX, cy + bobY);

    // Render the goalkeeper as pixel-art cells — each cell is a
    // coloured rectangle. Index 0 = transparent (not drawn).
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final int idx = _goalkeeperSprite[r][c];
        if (idx == 0) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            (c - cols / 2) * pixelSize,
            (r - rows / 2) * pixelSize,
            pixelSize - 0.3,
            pixelSize - 0.3,
          ),
          Paint()..color = _goalkeeperPalette[idx],
        );
      }
    }
    canvas.restore();
  }

  // -- DYNAMIC IDLE EFFECTS

  /// Grass clippings / dust particles that fly up from the
  /// field during idle — gives the impression that the
  /// action is about to start. The particles orbit near the
  /// ball position and fade in/out with `t`.
  void _drawGrassKickUp(Canvas canvas, Size size) {
    if (animation != PenaltySceneAnimation.idle) return;
    final Paint particle = Paint()
      ..color = const Color(0xFF4F8A3F).withValues(alpha: 0.7)
      ..strokeCap = StrokeCap.round;
    // 5 particles in slightly different phases.
    for (int i = 0; i < 5; i++) {
      final double phase =
          (t + _hash01(seed + i * 97) * 6.28) % (2 * math.pi);
      final double alpha =
          (math.sin(phase) + 1) / 2; // 0..1
      if (alpha < 0.1) continue;
      final double x = size.width * 0.56 +
          math.cos(phase * 1.3 + i) * size.width * 0.04;
      final double y = size.height * 0.88 -
          math.sin(phase * 1.7 + i) * size.height * 0.04;
      particle.strokeWidth = 1.0 + alpha * 1.5;
      canvas.drawLine(
        Offset(x - 1, y - 1),
        Offset(x + 1, y + 1),
        particle,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Ball — verdict-driven trajectory, with idle glow and
  // post-impact reset.
  // ---------------------------------------------------------------------------

  void _drawBall(Canvas canvas, Size size) {
    final double ballRadius = size.width * 0.045;
    // Ball sits ON the grass, at the same Y as the kicker's
    // feet. In a side view the ball is at ground level and
    // the kicker is behind it. The kicker's planted foot
    // reaches toward the ball from the left.
    final double spotY = size.height * 0.88;
    final double startX = size.width * 0.58;
    Offset pos;
    double rx = ballRadius;
    double ry = ballRadius;
    double rotation = 0;
    double alpha = 1.0;

    switch (animation) {
      case PenaltySceneAnimation.idle:
        // Bigger wobble + glow. The ball is the main visual —
        // no kicker, so it needs to carry the animation.
        final double wobble = math.sin(t * 2 * math.pi) * ballRadius * 0.20;
        pos = Offset(startX, spotY - ballRadius + wobble);
        rotation = t * 3 * math.pi;
        _drawBallGlow(canvas, pos, ballRadius);
        break;

      case PenaltySceneAnimation.goal:
        final Rect goal = Rect.fromLTWH(
          size.width * 0.18,
          size.height * 0.05,
          size.width * 0.64,
          size.height * 0.35,
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
          size.height * 0.05,
          size.width * 0.64,
          size.height * 0.35,
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
          size.height * 0.05,
          size.width * 0.64,
          size.height * 0.35,
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
          size.height * 0.05,
          size.width * 0.64,
          size.height * 0.35,
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
    // Pulsing yellow halo around the ball — bigger and more
    // dramatic now that the kicker is gone (the ball is the
    // main visual anchor).
    final double pulse = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
    // Outer ring: large, soft, fades in/out.
    final double outerR = radius * (2.5 + pulse * 0.8);
    canvas.drawCircle(
      pos,
      outerR,
      Paint()
        ..color = _kAmarilloBandera.withValues(alpha: 0.15 + pulse * 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // Inner ring: tighter, brighter.
    final double innerR = radius * (1.5 + pulse * 0.4);
    canvas.drawCircle(
      pos,
      innerR,
      Paint()
        ..color = _kAmarilloBandera.withValues(alpha: 0.35 + pulse * 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
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
