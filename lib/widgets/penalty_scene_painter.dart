/// PenaltyScenePainter — full-screen penalty scene for the worldcup
/// theme. Two modes:
///
///   * **Compact** (`compact: true`) — used by the PLAYING screen.
///     Drawn inside a SizedBox at the TOP of the screen (the
///     chronograph sits below). The scene shows goal +
///     goalkeeper + a kicker silhouette crouched behind the
///     ball, with a glow halo and pronounced idle wobble.
///
///   * **Full** (`compact: false`, default) — used by the RESULT
///     screen. Drawn across the whole viewport with a ball
///     trajectory animation that matches the verdict (goal /
///     post / wide / over).
///
/// Five animation modes:
///   * `idle`    — ball wobbles, goalkeeper sways, kicker
///                 breathes, crowd bobs.
///   * `goal`    — ball flies into the net, net shakes hard,
///                 crowd raises arms (green tint).
///   * `post`    — ball ricochets off the post with a spark
///                 burst, then bounces back.
///   * `wide`    — ball streaks past the post off-screen,
///                 crowd boos (red zigzags).
///   * `over`    — ball sails over the crossbar with a
///                 parabolic arc, crowd groans.
///
/// Compact mode swaps the goal frame to the upper half of the
/// compact area and places the ball+kicker in the lower half so
/// the chronograph never overlaps them.
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
    this.compact = false,
    this.seed = 1337,
  });

  final PenaltySceneAnimation animation;
  final double t;
  final bool compact;
  final int seed;

  // Selección Colombia tones.
  static const Color _kAzulBandera = Color(0xFF0E1A4A);
  static const Color _kAmarilloBandera = Color(0xFFFFCD00);
  static const Color _kBallBlack = Color(0xFF111111);

  // Crowd / lights.
  static const int _crowdHeads = 80;
  static const double _netSpacing = 10.0;
  static const double _netAlpha = 0.55;

  @override
  void paint(Canvas canvas, Size size) {
    if (compact) {
      _paintCompact(canvas, size);
    } else {
      _paintFull(canvas, size);
    }
  }

  // ===========================================================================
  // COMPACT (PLAYING screen — top portion of viewport)
  // ===========================================================================

  void _paintCompact(Canvas canvas, Size size) {
    // Sky gradient at the top, goal mid-area, ball+kicker at the
    // bottom. No field stripe — the chronograph provides the
    // "floor" below.
    _drawCompactSky(canvas, size);

    // Crowd at the very top.
    _drawCompactCrowd(canvas, size);

    // Stadium floodlights (corners).
    _drawCompactFloodlights(canvas, size);

    // Goal frame + net (top 50% of the compact area).
    final Rect goalRect = Rect.fromLTWH(
      size.width * 0.15,
      size.height * 0.18,
      size.width * 0.70,
      size.height * 0.42,
    );
    _drawNet(canvas, goalRect, shakeT: 0);
    _drawGoalFrame(canvas, goalRect);

    // Goalkeeper — sways dramatically.
    _drawGoalkeeperCompact(canvas, goalRect);

    // Ball — bigger, with glow halo, in front of the kicker.
    _drawBallCompact(canvas, size);

    // Kicker silhouette — crouched behind the ball, breathing.
    _drawKicker(canvas, size);

    // "READY" label below the kicker (subtle).
    _drawReadyLabel(canvas, size);
  }

  void _drawCompactSky(Canvas canvas, Size size) {
    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF87CEEB), // sky blue
            Color(0xFFB0E0E6), // pale blue
            Color(0xFFE8F4D8), // light lime
          ],
          stops: <double>[0.0, 0.5, 1.0],
        ).createShader(rect),
    );
  }

  void _drawCompactCrowd(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = _kAzulBandera.withValues(alpha: 0.18);
    final double baseY = size.height * 0.10;
    for (int i = 0; i < _crowdHeads; i++) {
      final double fx = _hash01(seed + i * 7919);
      final double x = fx * size.width;
      final double r = 4.0 + _hash01(seed + i * 7901) * 5.0;
      // Crowd bobs in idle — each head a different phase.
      final double bob = math.sin(t * 2 * math.pi +
              _hash01(seed + i * 7793) * 6.28) *
          r *
          0.6;
      canvas.drawCircle(Offset(x, baseY - r / 2 + bob), r, paint);
    }
  }

  void _drawCompactFloodlights(Canvas canvas, Size size) {
    final Paint lightPaint = Paint()
      ..color = const Color(0xFFFFE082).withValues(alpha: 0.20);
    final double r = size.height * 0.45;
    canvas.drawCircle(
        Offset(-r * 0.3, size.height * 0.05), r, lightPaint);
    canvas.drawCircle(
        Offset(size.width + r * 0.3, size.height * 0.05), r, lightPaint);
  }

  void _drawGoalkeeperCompact(Canvas canvas, Rect goal) {
    final double cx = goal.center.dx;
    final double cy = goal.center.dy + goal.height * 0.15;
    final double scale = goal.height / 240.0;

    // Idle: pronounced horizontal sway + small vertical bob.
    // Goal: shake. Wide: dive. Over: arms-up crouch.
    double swayX = 0;
    double bobY = 0;
    double armRaise = 0; // 0 = arms at sides, 1 = arms up
    if (animation == PenaltySceneAnimation.idle) {
      swayX = math.sin(t * 2 * math.pi) * goal.width * 0.10;
      bobY = math.cos(t * 2 * math.pi) * goal.height * 0.04;
    } else if (animation == PenaltySceneAnimation.goal) {
      swayX = math.sin(t * math.pi * 8) * goal.width * 0.06;
    } else if (animation == PenaltySceneAnimation.wide) {
      final double dir = t < 0.5 ? -1 : 1;
      swayX = dir * (goal.width * 0.35) * (t < 0.5 ? t * 2 : 1.0);
    } else if (animation == PenaltySceneAnimation.over) {
      armRaise = math.sin(t * math.pi) * 1.0;
      swayX = math.sin(t * math.pi * 2) * goal.width * 0.04;
    }

    canvas.save();
    canvas.translate(cx + swayX, cy + bobY);

    // Body (yellow Selección jersey)
    final Paint bodyPaint = Paint()..color = _kAmarilloBandera;
    canvas.drawRect(
      Rect.fromCenter(center: Offset(0, 0), width: 36 * scale, height: 70 * scale),
      bodyPaint,
    );
    // Shorts (azul)
    final Paint shortsPaint = Paint()..color = _kAzulBandera;
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(0, 45 * scale), width: 38 * scale, height: 28 * scale),
      shortsPaint,
    );
    // Legs
    final Paint legPaint = Paint()..color = const Color(0xFF222222);
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(-12 * scale, 78 * scale), width: 12 * scale, height: 36 * scale),
      legPaint,
    );
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(12 * scale, 78 * scale), width: 12 * scale, height: 36 * scale),
      legPaint,
    );
    // Head (skin)
    final Paint headPaint = Paint()..color = const Color(0xFFE0AC77);
    canvas.drawCircle(Offset(0, -48 * scale), 14 * scale, headPaint);
    // Gloves — at sides normally, raised up when "over" or shaking.
    final Paint glovePaint = Paint()..color = const Color(0xFFFFFFFF);
    final double gloveX = 26 * scale;
    final double gloveYBase = -10 * scale - armRaise * 40 * scale;
    canvas.drawCircle(
        Offset(-gloveX, gloveYBase), 9 * scale, glovePaint);
    canvas.drawCircle(Offset(gloveX, gloveYBase), 9 * scale, glovePaint);
    // Arms (lines from shoulders to gloves)
    final Paint armPaint = Paint()
      ..color = const Color(0xFFE0AC77)
      ..strokeWidth = 6 * scale
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(-14 * scale, -20 * scale),
        Offset(-gloveX, gloveYBase),
        armPaint);
    canvas.drawLine(
        Offset(14 * scale, -20 * scale),
        Offset(gloveX, gloveYBase),
        armPaint);

    canvas.restore();
  }

  void _drawBallCompact(Canvas canvas, Size size) {
    // Ball at the penalty mark (bottom-center of the compact
    // area, visible above the chronograph).
    final double ballRadius = size.width * 0.045;
    final double spotY = size.height * 0.78;
    final double idleWobble =
        math.sin(t * 2 * math.pi) * ballRadius * 0.18;
    final double rotation = t * 2 * math.pi;
    final Offset pos = Offset(size.width / 2, spotY - ballRadius + idleWobble);
    _drawBallAt(canvas, pos, ballRadius, rotation, glow: animation == PenaltySceneAnimation.idle);
  }

  void _drawKicker(Canvas canvas, Size size) {
    // Crouched kicker silhouette behind the ball. Pixel-art
    // 11x10 grid. Always faces right (the goal is on the right
    // in our scene) — left leg planted, right leg drawn back
    // ready to swing.
    final double scale = size.height * 0.012;
    final double baseX = size.width / 2 - size.width * 0.13;
    final double baseY = size.height * 0.92;
    // Breathing bob.
    final double breathe = math.sin(t * 2 * math.pi) * scale * 1.5;

    // Head
    canvas.drawCircle(
      Offset(baseX, baseY - 9 * scale + breathe),
      2.5 * scale,
      Paint()..color = const Color(0xFFE0AC77),
    );
    // Body (jersey Selección amarilla)
    final Paint bodyPaint = Paint()..color = _kAmarilloBandera;
    canvas.drawRect(
      Rect.fromLTWH(
        baseX - 3 * scale,
        baseY - 7 * scale + breathe,
        6 * scale,
        7 * scale,
      ),
      bodyPaint,
    );
    // Shorts (azul)
    final Paint shortsPaint = Paint()..color = _kAzulBandera;
    canvas.drawRect(
      Rect.fromLTWH(
        baseX - 3 * scale,
        baseY + 0 * scale + breathe,
        6 * scale,
        3 * scale,
      ),
      shortsPaint,
    );
    // Planted leg (forward, to the right of the body)
    final Paint legPaint = Paint()..color = const Color(0xFF222222);
    canvas.drawRect(
      Rect.fromLTWH(
        baseX + 1 * scale,
        baseY + 3 * scale + breathe,
        2 * scale,
        5 * scale,
      ),
      legPaint,
    );
    // Kicking leg drawn BACK (to the left) — slight oscillation
    // during idle to reinforce "ready to kick" feel.
    final double backSwing =
        math.sin(t * 2 * math.pi) * scale * 1.0;
    canvas.drawRect(
      Rect.fromLTWH(
        baseX - 5 * scale - backSwing,
        baseY + 3 * scale + breathe,
        2 * scale,
        5 * scale,
      ),
      legPaint,
    );
  }

  void _drawReadyLabel(Canvas canvas, Size size) {
    // Subtle "¡LISTOS!" label that fades in/out gently.
    final double alpha =
        0.5 + 0.5 * math.sin(t * 2 * math.pi);
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: '¡LISTOS!',
        style: TextStyle(
          color: _kAmarilloBandera.withValues(alpha: alpha),
          fontSize: size.height * 0.06,
          fontWeight: FontWeight.w900,
          letterSpacing: 4,
          shadows: const <Shadow>[
            Shadow(
              color: Color(0xCC000000),
              blurRadius: 6,
              offset: Offset(2, 2),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(
        (size.width - tp.width) / 2,
        size.height * 0.02,
      ),
    );
  }

  // ===========================================================================
  // FULL (RESULT screen — full viewport)
  // ===========================================================================

  void _paintFull(Canvas canvas, Size size) {
    _drawField(canvas, size);
    _drawCrowd(canvas, size);
    _drawFloodlights(canvas, size);

    final Rect goalRect = _goalRect(size);
    _drawNet(canvas, goalRect, shakeT: animation == PenaltySceneAnimation.goal ? t : 0);
    _drawGoalFrame(canvas, goalRect);
    _drawGoalkeeper(canvas, goalRect);
    _drawPenaltyMarkings(canvas, size);
    _drawBall(canvas, size);
  }

  Rect _goalRect(Size size) {
    final double w = size.width * 0.55;
    final double h = size.height * 0.35;
    return Rect.fromLTWH(
      (size.width - w) / 2,
      size.height * 0.05,
      w,
      h,
    );
  }

  void _drawField(Canvas canvas, Size size) {
    final Rect fieldRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
      fieldRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFFE8F4D8),
            Color(0xFFBFE3A2),
            Color(0xFF8FBE6F),
          ],
        ).createShader(fieldRect),
    );
    final Paint stripePaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.06);
    for (double y = 0; y < size.height; y += 24) {
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, 12),
        stripePaint,
      );
    }
  }

  void _drawCrowd(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = _kAzulBandera.withValues(alpha: 0.10);
    final double baseY = size.height * 0.04;
    for (int i = 0; i < _crowdHeads; i++) {
      final double fx = _hash01(seed + i * 7919);
      final double x = fx * size.width;
      final double r = 4.0 + _hash01(seed + i * 7901) * 4.0;
      canvas.drawCircle(Offset(x, baseY - r / 2), r, paint);
    }
  }

  void _drawFloodlights(Canvas canvas, Size size) {
    final Paint lightPaint = Paint()
      ..color = const Color(0xFFFFE082).withValues(alpha: 0.15);
    final double r = size.height * 0.20;
    canvas.drawCircle(
        Offset(-r * 0.4, size.height * 0.08), r, lightPaint);
    canvas.drawCircle(
        Offset(size.width + r * 0.4, size.height * 0.08), r, lightPaint);
  }

  void _drawNet(Canvas canvas, Rect goal, {required double shakeT}) {
    final Paint netPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: _netAlpha)
      ..strokeWidth = 1.0;
    for (double x = goal.left; x <= goal.right; x += _netSpacing) {
      canvas.drawLine(Offset(x, goal.top), Offset(x, goal.bottom), netPaint);
    }
    for (double y = goal.top; y <= goal.bottom; y += _netSpacing) {
      canvas.drawLine(Offset(goal.left, y), Offset(goal.right, y), netPaint);
    }
    // Net shake — dramatic on goal, subtle on impact (post).
    double amp = 0;
    if (shakeT > 0.0) {
      amp = (1.0 - shakeT) * 6.0;
    } else if (animation == PenaltySceneAnimation.post &&
        t > 0.5 &&
        t < 0.55) {
      // Single hard shake on post impact.
      amp = (0.55 - t) * 50.0;
    }
    if (amp > 0.5) {
      final Paint shakePaint = Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.7)
        ..strokeWidth = 2.0;
      for (int i = 0; i < 5; i++) {
        final double y = goal.top + goal.height * (0.2 + i * 0.15) +
            math.sin(shakeT * math.pi * 8 + i) * amp;
        canvas.drawLine(
          Offset(goal.left, y),
          Offset(goal.right, y),
          shakePaint,
        );
      }
    }
  }

  void _drawGoalFrame(Canvas canvas, Rect goal) {
    final double frameThickness = math.max(8.0, goal.width * 0.012);
    final Paint framePaint = Paint()
      ..color = _kAmarilloBandera
      ..style = PaintingStyle.stroke
      ..strokeWidth = frameThickness;
    final Rect frameOuter = goal.inflate(frameThickness / 2);
    canvas.drawRect(frameOuter, framePaint);
    final Paint shadowPaint = Paint()
      ..color = const Color(0xCC8A6A00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = frameThickness / 2;
    canvas.drawRect(frameOuter.deflate(frameThickness / 4), shadowPaint);
  }

  void _drawGoalkeeper(Canvas canvas, Rect goal) {
    final double cx = goal.center.dx;
    final double cy = goal.center.dy;
    final double scale = goal.height / 220.0;

    double swayX = 0;
    if (animation == PenaltySceneAnimation.idle) {
      swayX = math.sin(t * 2 * math.pi) * goal.width * 0.05;
    } else if (animation == PenaltySceneAnimation.goal) {
      swayX = math.sin(t * math.pi * 6) * goal.width * 0.04;
    } else if (animation == PenaltySceneAnimation.wide) {
      final double dir = t < 0.5 ? -1 : 1;
      swayX = dir * (goal.width * 0.3) * (t < 0.5 ? t * 2 : 1.0);
    } else if (animation == PenaltySceneAnimation.over) {
      swayX = math.sin(t * math.pi * 2) * goal.width * 0.03;
    }

    canvas.save();
    canvas.translate(cx + swayX, cy);

    final Paint bodyPaint = Paint()..color = _kAmarilloBandera;
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(0, 0), width: 30 * scale, height: 60 * scale),
      bodyPaint,
    );
    final Paint shortsPaint = Paint()..color = _kAzulBandera;
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(0, 38 * scale), width: 32 * scale, height: 24 * scale),
      shortsPaint,
    );
    final Paint legPaint = Paint()..color = const Color(0xFF333333);
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(-10 * scale, 65 * scale), width: 10 * scale, height: 32 * scale),
      legPaint,
    );
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(10 * scale, 65 * scale), width: 10 * scale, height: 32 * scale),
      legPaint,
    );
    final Paint headPaint = Paint()..color = const Color(0xFFE0AC77);
    canvas.drawCircle(Offset(0, -40 * scale), 12 * scale, headPaint);
    final Paint glovePaint = Paint()..color = const Color(0xFFEEEEEE);
    canvas.drawCircle(Offset(-22 * scale, -8 * scale), 8 * scale, glovePaint);
    canvas.drawCircle(Offset(22 * scale, -8 * scale), 8 * scale, glovePaint);

    canvas.restore();
  }

  void _drawPenaltyMarkings(Canvas canvas, Size size) {
    final Paint linePaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final double spotY = size.height * 0.78;
    final double arcRadius = size.height * 0.10;
    canvas.drawArc(
      Rect.fromCircle(
          center: Offset(size.width / 2, spotY), radius: arcRadius),
      -math.pi,
      math.pi,
      false,
      linePaint,
    );
    final Paint spotPaint = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawCircle(Offset(size.width / 2, spotY), 3.0, spotPaint);
    final double boxTop = size.height * 0.40;
    final double boxLeft = size.width * 0.18;
    final double boxRight = size.width * 0.82;
    final Paint boxPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(
      Rect.fromLTRB(boxLeft, boxTop, boxRight, size.height),
      boxPaint,
    );
  }

  void _drawBall(Canvas canvas, Size size) {
    final double ballRadius = size.width * 0.025;
    final double spotY = size.height * 0.78;
    Offset pos;
    double rotation = 0;
    double alpha = 1.0;

    switch (animation) {
      case PenaltySceneAnimation.idle:
        pos = Offset(size.width / 2, spotY - ballRadius);
        rotation = t * 2 * math.pi;
        break;
      case PenaltySceneAnimation.goal:
        final Rect goal = _goalRect(size);
        final Offset start = Offset(size.width / 2, spotY - ballRadius);
        final Offset end =
            Offset(goal.center.dx, goal.center.dy + ballRadius);
        if (t < 0.6) {
          pos = Offset.lerp(start, end, t / 0.6)!;
        } else {
          pos = end;
          alpha = 1.0 - (t - 0.6) / 0.4 * 0.3;
        }
        rotation = t * 4 * math.pi;
        break;
      case PenaltySceneAnimation.post:
        final Rect goal = _goalRect(size);
        final double postX = goal.left + 6;
        final double postY = goal.top + goal.height * 0.55;
        final Offset start = Offset(size.width / 2, spotY - ballRadius);
        if (t < 0.5) {
          pos = Offset.lerp(start, Offset(postX, postY), t / 0.5)!;
        } else {
          pos = Offset.lerp(
            Offset(postX, postY),
            Offset(start.dx + ballRadius * 2, start.dy),
            (t - 0.5) / 0.5,
          )!;
        }
        rotation = t * 6 * math.pi;
        break;
      case PenaltySceneAnimation.wide:
        final double dir = (seed.isEven ? -1 : 1);
        final Rect goal = _goalRect(size);
        final double postX = dir < 0 ? goal.left - 6 : goal.right + 6;
        final double postY = goal.center.dy - 20;
        final Offset start = Offset(size.width / 2, spotY - ballRadius);
        pos = Offset.lerp(start, Offset(postX, postY), t)!;
        rotation = t * 8 * math.pi;
        alpha = 1.0 - (t > 0.8 ? (t - 0.8) / 0.2 * 0.7 : 0.0);
        break;
      case PenaltySceneAnimation.over:
        final Rect goal = _goalRect(size);
        final double crossbarY = goal.top - ballRadius - 8;
        final Offset start = Offset(size.width / 2, spotY - ballRadius);
        final double tt = t;
        pos = Offset(
          size.width / 2 + math.sin(tt * math.pi) * 8,
          start.dy + (crossbarY - start.dy) * tt,
        );
        rotation = t * 5 * math.pi;
        alpha = 1.0 - (t > 0.85 ? (t - 0.85) / 0.15 * 0.5 : 0.0);
        break;
    }

    _drawBallAt(canvas, pos, ballRadius, rotation, glow: false, alpha: alpha);
  }

  // ===========================================================================
  // SHARED ball-drawing primitive
  // ===========================================================================

  void _drawBallAt(
    Canvas canvas,
    Offset pos,
    double radius,
    double rotation, {
    bool glow = false,
    double alpha = 1.0,
  }) {
    if (glow) {
      // Soft pulsing halo around the ball — yellow Selección.
      final double pulse = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
      final double haloR = radius * (2.4 + pulse * 0.5);
      final Paint halo = Paint()
        ..color = _kAmarilloBandera.withValues(alpha: (0.30 + pulse * 0.25) * alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(pos, haloR, halo);
    }

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(rotation);

    final double px = radius * 2 / 7;
    final Paint bodyPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: alpha);
    final Paint pentPaint = Paint()
      ..color = _kBallBlack.withValues(alpha: alpha);
    for (int r = 0; r < 7; r++) {
      for (int c = 0; c < 7; c++) {
        final double dx = (c - 3) + 0.5;
        final double dy = (r - 3) + 0.5;
        final double dist = math.sqrt(dx * dx + dy * dy);
        if (dist > 3.2) continue;
        final bool isPent = (c == 3 && r == 3) ||
            (c == 3 && r == 2) ||
            (c == 2 && r == 3) ||
            (c == 4 && r == 3) ||
            (c == 3 && r == 4);
        canvas.drawRect(
          Rect.fromLTWH(
            (c - 3) * px - px / 2,
            (r - 3) * px - px / 2,
            px - 0.5,
            px - 0.5,
          ),
          isPent ? pentPaint : bodyPaint,
        );
      }
    }
    canvas.restore();
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
      old.animation != animation ||
      old.t != t ||
      old.seed != seed ||
      old.compact != compact;
}
