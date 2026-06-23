/// PenaltyScenePainter — full-screen penalty scene used as the
/// background of the worldcup-theme PLAYING screen. Draws:
///   * Green field gradient at the bottom.
///   * Penalty arc / box markings.
///   * Penalty spot (center).
///   * Ball at the spot, with a subtle "rolling" idle animation
///     driven by `t`.
///   * Goal frame + net (pixel art, top half).
///   * Goalkeeper silhouette standing in the goal center.
///   * Crowd silhouette at the top (very low alpha so the
///     chronograph stays readable on top).
///
/// The scene is intentionally low-contrast so the white
/// background of the PLAYING screen still gives the
/// chronograph digits maximum contrast. Colours are Selección
/// Colombia tones: yellow goal frame, white ball, blue goalie.
///
/// On the RESULT screen the same painter is reused with a
/// `sceneAnimation` enum that drives the ball trajectory:
///   * `idle`            — used by PLAYING (no animation).
///   * `goal`            — ball flies to the net and the net
///                         shakes; used for VICTORIA.
///   * `post`            — ball hits the post and bounces back;
///                         used for CASI.
///   * `wide`            — ball flies past the post (out of
///                         frame); used for NI POR ASOMO.
///   * `over`            — ball flies over the crossbar; used
///                         for TE PASASTE.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Which moment of the penalty the scene is showing.
enum PenaltySceneAnimation {
  /// Static scene used by PLAYING. Ball stays at the spot
  /// with a tiny "rolling" wobble.
  idle,

  /// Ball goes into the net. Net shakes briefly.
  goal,

  /// Ball hits the post and bounces back.
  post,

  /// Ball flies wide of the goal (off-screen left or right).
  wide,

  /// Ball sails over the crossbar.
  over,
}

class PenaltyScenePainter extends CustomPainter {
  PenaltyScenePainter({
    required this.animation,
    required this.t,
    this.seed = 1337,
  });

  /// Which penalty moment to render. `idle` is the PLAYING
  /// background; the others are RESULT-screen animations
  /// driven by `t ∈ [0, 1]`.
  final PenaltySceneAnimation animation;

  /// Animation phase in `[0, 1]`. Used for everything that
  /// moves (ball position, net shake, post bounce).
  final double t;

  /// Reserved for future crowd / star randomization.
  final int seed;

  // Selección Colombia tones.
  static const Color _kAzulBandera = Color(0xFF0E1A4A);
  static const Color _kAmarilloBandera = Color(0xFFFFCD00);
  static const Color _kBallBlack = Color(0xFF111111);

  // Scene geometry — fractions of the viewport so the scene
  // scales to any kiosk resolution.
  static const double _goalTopFraction = 0.05;
  static const double _goalBottomFraction = 0.40;
  static const double _goalWidthFraction = 0.55;
  static const double _penaltySpotFraction = 0.78;
  static const double _ballRadiusFraction = 0.025;

  // Crowd / lights.
  static const int _crowdHeads = 80;
  static const double _crowdAlpha = 0.08;
  static const double _floodlightAlpha = 0.12;

  // Net drawing constants.
  static const double _netSpacing = 10.0;
  static const double _netAlpha = 0.45;

  @override
  void paint(Canvas canvas, Size size) {
    // 0) Field gradient (green tint at bottom, darker at top).
    final Rect fieldRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final Paint fieldPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFFE8F4D8), // light lime
          Color(0xFFBFE3A2), // grass mid
          Color(0xFF8FBE6F), // grass dark
        ],
      ).createShader(fieldRect);
    canvas.drawRect(fieldRect, fieldPaint);

    // Faint pitch stripes (mowed-grass look) — every ~24 px
    // we paint a slightly lighter stripe.
    final Paint stripePaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.06);
    for (double y = 0; y < size.height; y += 24) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 12), stripePaint);
    }

    // 1) Crowd silhouette at the top (very faint).
    _drawCrowd(canvas, size);

    // 2) Stadium floodlights — two big pale circles at the
    //    top corners, low alpha.
    _drawFloodlights(canvas, size);

    // 3) Goal frame + net (top half of the screen).
    final Rect goalRect = _goalRect(size);
    _drawNet(canvas, goalRect);
    _drawGoalFrame(canvas, goalRect);

    // 4) Goalkeeper silhouette standing in the goal.
    _drawGoalkeeper(canvas, goalRect);

    // 5) Penalty arc + spot.
    _drawPenaltyMarkings(canvas, size);

    // 6) Ball — position depends on `animation` and `t`.
    _drawBall(canvas, size);
  }

  Rect _goalRect(Size size) {
    final double w = size.width * _goalWidthFraction;
    final double h = (size.height * (_goalBottomFraction - _goalTopFraction));
    return Rect.fromLTWH(
      (size.width - w) / 2,
      size.height * _goalTopFraction,
      w,
      h,
    );
  }

  void _drawNet(Canvas canvas, Rect goal) {
    final Paint netPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: _netAlpha)
      ..strokeWidth = 1.0;
    // Vertical lines.
    for (double x = goal.left; x <= goal.right; x += _netSpacing) {
      canvas.drawLine(Offset(x, goal.top), Offset(x, goal.bottom), netPaint);
    }
    // Horizontal lines.
    for (double y = goal.top; y <= goal.bottom; y += _netSpacing) {
      canvas.drawLine(Offset(goal.left, y), Offset(goal.right, y), netPaint);
    }
    // Net shake on goal (t 0.6..1.0).
    if (animation == PenaltySceneAnimation.goal && t > 0.6) {
      final double shakeT = (t - 0.6) / 0.4; // 0..1
      final double shakeAmp = (1.0 - shakeT) * 3.0;
      final Paint shakePaint = Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: shakeT * 0.7)
        ..strokeWidth = 2.0;
      for (int i = 0; i < 3; i++) {
        final double y = goal.top +
            goal.height * (0.3 + i * 0.2) +
            math.sin((shakeT + i) * math.pi * 4) * shakeAmp;
        canvas.drawLine(
          Offset(goal.left, y),
          Offset(goal.right, y),
          shakePaint,
        );
      }
    }
  }

  void _drawGoalFrame(Canvas canvas, Rect goal) {
    // Yellow Selección goal frame. Thick outer rectangle with
    // a darker inner shadow.
    final double frameThickness = math.max(8.0, goal.width * 0.012);
    final Paint framePaint = Paint()
      ..color = _kAmarilloBandera
      ..style = PaintingStyle.stroke
      ..strokeWidth = frameThickness;
    final Rect frameOuter = goal.inflate(frameThickness / 2);
    canvas.drawRect(frameOuter, framePaint);
    // Inner shadow for depth.
    final Paint shadowPaint = Paint()
      ..color = const Color(0xCC8A6A00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = frameThickness / 2;
    canvas.drawRect(frameOuter.deflate(frameThickness / 4), shadowPaint);
  }

  void _drawGoalkeeper(Canvas canvas, Rect goal) {
    // Simple stick-figure goalkeeper standing in the center of
    // the goal, Selección jersey (amarillo), blue shorts.
    final double cx = goal.center.dx;
    final double cy = goal.center.dy;
    final double scale = goal.height / 220.0;

    // Idle: small horizontal sway. Goal/wide: dives left/right.
    double swayX = 0;
    if (animation == PenaltySceneAnimation.idle) {
      swayX = math.sin(t * 2 * math.pi) * goal.width * 0.05;
    } else if (animation == PenaltySceneAnimation.goal) {
      swayX = math.sin(t * math.pi * 6) * goal.width * 0.04;
    } else if (animation == PenaltySceneAnimation.wide) {
      // Dive to one side as the ball flies past.
      final double dir = t < 0.5 ? -1 : 1;
      swayX = dir * (goal.width * 0.3) * (t < 0.5 ? t * 2 : 1.0);
    } else if (animation == PenaltySceneAnimation.over) {
      // Crouch / arms up as the ball sails over.
      swayX = math.sin(t * math.pi * 2) * goal.width * 0.03;
    }

    canvas.save();
    canvas.translate(cx + swayX, cy);

    // Body
    final Paint bodyPaint = Paint()..color = _kAmarilloBandera;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(0, 0),
        width: 30 * scale,
        height: 60 * scale,
      ),
      bodyPaint,
    );
    // Shorts (blue)
    final Paint shortsPaint = Paint()..color = _kAzulBandera;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(0, 38 * scale),
        width: 32 * scale,
        height: 24 * scale,
      ),
      shortsPaint,
    );
    // Legs
    final Paint legPaint = Paint()..color = const Color(0xFF333333);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(-10 * scale, 65 * scale),
        width: 10 * scale,
        height: 32 * scale,
      ),
      legPaint,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(10 * scale, 65 * scale),
        width: 10 * scale,
        height: 32 * scale,
      ),
      legPaint,
    );
    // Head (skin)
    final Paint headPaint = Paint()..color = const Color(0xFFE0AC77);
    canvas.drawCircle(Offset(0, -40 * scale), 12 * scale, headPaint);
    // Gloves (white hands at sides)
    final Paint glovePaint = Paint()..color = const Color(0xFFEEEEEE);
    canvas.drawCircle(Offset(-22 * scale, -8 * scale), 8 * scale, glovePaint);
    canvas.drawCircle(Offset(22 * scale, -8 * scale), 8 * scale, glovePaint);

    canvas.restore();
  }

  void _drawCrowd(Canvas canvas, Size size) {
    final Paint crowdPaint = Paint()
      ..color = _kAzulBandera.withValues(alpha: _crowdAlpha);
    final double baseY = size.height * _goalTopFraction - 6;
    for (int i = 0; i < _crowdHeads; i++) {
      final double fx = _hash01(seed + i * 7919);
      final double x = fx * size.width;
      final double r = 4.0 + _hash01(seed + i * 7901) * 4.0;
      canvas.drawCircle(Offset(x, baseY - r / 2), r, crowdPaint);
    }
  }

  void _drawFloodlights(Canvas canvas, Size size) {
    final Paint lightPaint = Paint()
      ..color = const Color(0xFFFFE082).withValues(alpha: _floodlightAlpha);
    final double r = size.height * 0.18;
    canvas.drawCircle(Offset(-r * 0.4, size.height * 0.10), r, lightPaint);
    canvas.drawCircle(
        Offset(size.width + r * 0.4, size.height * 0.10), r, lightPaint);
  }

  void _drawPenaltyMarkings(Canvas canvas, Size size) {
    final Paint linePaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Penalty arc (the "D" at the top of the box).
    final double spotY = size.height * _penaltySpotFraction;
    final double arcRadius = size.height * 0.10;
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(size.width / 2, spotY),
        radius: arcRadius,
      ),
      // Top half of the circle (180°..360° in screen coords).
      -math.pi,
      math.pi,
      false,
      linePaint,
    );

    // Penalty spot — a small white dot.
    final Paint spotPaint = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawCircle(
      Offset(size.width / 2, spotY),
      3.0,
      spotPaint,
    );

    // Penalty box outline (faint).
    final double boxTop = size.height * _goalBottomFraction;
    final double boxBottom = size.height;
    final double boxLeft = size.width * 0.18;
    final double boxRight = size.width * 0.82;
    final Paint boxPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(
      Rect.fromLTRB(boxLeft, boxTop, boxRight, boxBottom),
      boxPaint,
    );
  }

  void _drawBall(Canvas canvas, Size size) {
    final double ballRadius = size.width * _ballRadiusFraction;
    final double spotY = size.height * _penaltySpotFraction;
    Offset pos;
    double rotation = 0;
    double alpha = 1.0;

    switch (animation) {
      case PenaltySceneAnimation.idle:
        // Subtle vertical wobble ("winding up") — visually
        // reinforces that the player hasn't kicked yet.
        final double wobble = math.sin(t * 2 * math.pi) * ballRadius * 0.08;
        pos = Offset(size.width / 2, spotY - ballRadius - wobble);
        rotation = t * 2 * math.pi;
        break;

      case PenaltySceneAnimation.goal:
        // Ball flies to the net (center of goal).
        final Rect goal = _goalRect(size);
        final Offset start = Offset(size.width / 2, spotY - ballRadius);
        final Offset end = Offset(
          goal.center.dx,
          goal.center.dy + ballRadius,
        );
        // 0..0.6: travels from spot to net.
        if (t < 0.6) {
          final double tt = t / 0.6;
          pos = Offset.lerp(start, end, tt)!;
        } else {
          // 0.6..1.0: net absorbed the ball — it sits inside.
          pos = end;
          alpha = 1.0 - (t - 0.6) / 0.4 * 0.3;
        }
        rotation = t * 4 * math.pi;
        break;

      case PenaltySceneAnimation.post:
        // Ball hits the post and bounces back.
        final Rect goal = _goalRect(size);
        final double postX = goal.left + 6;
        final double postY = goal.top + goal.height * 0.55;
        final Offset start = Offset(size.width / 2, spotY - ballRadius);
        if (t < 0.5) {
          final double tt = t / 0.5;
          pos = Offset.lerp(start, Offset(postX, postY), tt)!;
        } else {
          // Bounce back.
          final double tt = (t - 0.5) / 0.5;
          pos = Offset.lerp(
            Offset(postX, postY),
            Offset(start.dx + ballRadius * 2, start.dy),
            tt,
          )!;
        }
        rotation = t * 6 * math.pi;
        break;

      case PenaltySceneAnimation.wide:
        // Ball flies past the post, off-screen left or right.
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
        // Ball sails over the crossbar.
        final Rect goal = _goalRect(size);
        final double crossbarY = goal.top - ballRadius - 8;
        final Offset start = Offset(size.width / 2, spotY - ballRadius);
        final Offset end = Offset(size.width / 2, crossbarY);
        // Parabolic arc: lerp on Y with a slight x drift.
        final double tt = t;
        pos = Offset(
          size.width / 2 + math.sin(tt * math.pi) * 8,
          start.dy + (end.dy - start.dy) * tt,
        );
        rotation = t * 5 * math.pi;
        alpha = 1.0 - (t > 0.85 ? (t - 0.85) / 0.15 * 0.5 : 0.0);
        break;
    }

    // Draw the ball with the classic 7x7 pentagon pattern.
    final double px = ballRadius * 2 / 7;
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(rotation);
    final Paint bodyPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: alpha);
    final Paint pentPaint = Paint()
      ..color = _kBallBlack.withValues(alpha: alpha);
    const int pattern = 7;
    // Layout: outer ring + central pentagon.
    for (int r = 0; r < pattern; r++) {
      for (int c = 0; c < pattern; c++) {
        // Outer circle mask.
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
      old.animation != animation || old.t != t || old.seed != seed;
}
