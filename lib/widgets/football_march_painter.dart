/// FootballMarchPainter — full-screen pelotas (soccer balls) march
/// for the Selección Colombia (worldcup) theme. Mirrors the
/// structure of [InvaderMarchPainter]: same marching cadence, same
/// scanlines, same stars. The only differences are the sprite
/// shape (soccer ball instead of invader) and the background
/// palette (azul bandera / rojo bandera / dark navy / deep purple
/// — Selección Colombia tones, no green).
///
/// Like the invader painter, this one draws EVERYTHING (background
/// + scanlines + stars + pelotas) and re-paints on every tick of
/// the listenable. Zero painter -> widget communication. The
/// parent screen hands in the listenable and never has to rebuild.
///
/// Football-specific touches:
///   * The background is a deep "stadium at night" navy that
///     crossfades to a midnight blue and (rarely) a deep red —
///     subtle nods to the Selección jersey.
///   * The pelotas have a center black pentagon (rendered as a
///     plus-shaped cluster of black pixels) for unmistakable
///     "soccer ball" recognition at the kiosk's 4-pixel size.
///   * The marching cadence is the same as the invader (220 frames
///     = 11 seconds) so the visual rhythm is preserved.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

class FootballMarchPainter extends CustomPainter {
  FootballMarchPainter({
    required this.seed,
    Listenable? listenable,
  })  : _listenable = listenable,
        super(repaint: listenable);

  final int seed;
  final Listenable? _listenable;

  // Same marching geometry as InvaderMarchPainter — the 220-frame
  // period produces an 11-second sweep, matching the arcade feel.
  static const int _cols = 10;
  static const int _rows = 4;
  static const double _colSpacing = 70.0;
  static const double _rowSpacing = 58.0;
  static const double _pixelSize = 3.0;
  static const double _marchPeriodFrames = 220.0;
  static const int _stepsBetweenHalfMarches = 1;

  static const int _starCount = 60;
  static const double _scanlineSpacing = 8.0;
  static const double _scanlineAlpha = 0.10;

  static const int _bgCrossfadeFrames = 60;

  // Painter-local state. Same pattern as InvaderMarchPainter.
  int? _lastLandingTick;
  int _bgColorIndex = 0;
  int _bgCrossfadeStartTick = 0;
  Color _currentBg = _kBgPalette[0];

  /// Background-color palette for the Selección Colombia theme.
  /// Cool blues dominate; deep red appears occasionally as a nod
  /// to the jersey's red accent.
  static const List<Color> _kBgPalette = <Color>[
    Color(0xFF0E1A4A), // azul bandera (start)
    Color(0xFF06112E), // midnight blue
    Color(0xFF150A0A), // deep maroon (rare — red jersey hint)
    Color(0xFF0A0F1A), // deep navy
    Color(0xFF1A0833), // deep purple
  ];

  /// Pelota colors per row. The visual reads as "white soccer
  /// balls with a yellow / blue / red / amber rim", so even at
  /// 3px the ball is recognizable AND the row colour reads as
  /// "Selección" not "classic arcade".
  static const List<Color> _rowColors = <Color>[
    Color(0xFFFFCD00), // amarillo bandera
    Color(0xFF00B0FF), // sky blue
    Color(0xFFCE1126), // rojo bandera
    Color(0xFFFF8F00), // warm amber
  ];

  /// 7x7 soccer ball bitmap. Two animation frames (frame 0 and
  /// frame 1 are 90° rotations of each other). `1` = lit pixel
  /// (body), `0` = off (cavity / pentagon). The plus-shaped
  /// central cluster reads as a pentagon at low resolution.
  static const List<List<List<int>>> _ballShapes = <List<List<int>>>[
    // Frame 0 — pentagon pointing up
    <List<int>>[
      <int>[0, 0, 1, 1, 1, 0, 0],
      <int>[0, 1, 1, 1, 1, 1, 0],
      <int>[1, 1, 0, 1, 0, 1, 1],
      <int>[1, 0, 1, 1, 1, 0, 1],
      <int>[1, 1, 0, 1, 0, 1, 1],
      <int>[0, 1, 1, 1, 1, 1, 0],
      <int>[0, 0, 1, 1, 1, 0, 0],
    ],
    // Frame 1 — pentagon rotated 45°
    <List<int>>[
      <int>[0, 0, 1, 1, 1, 0, 0],
      <int>[0, 1, 1, 0, 1, 1, 0],
      <int>[1, 1, 0, 1, 0, 1, 1],
      <int>[1, 0, 1, 1, 1, 0, 1],
      <int>[1, 1, 0, 1, 0, 1, 1],
      <int>[0, 1, 1, 0, 1, 1, 0],
      <int>[0, 0, 1, 1, 1, 0, 0],
    ],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final Listenable? l = _listenable;
    final int tick = (l is AnimationController)
        ? (l.lastElapsedDuration?.inMilliseconds ?? 0) ~/ 50
        : 0;

    // 0) Background.
    final Color bg = _computeCurrentBg(tick);
    final Paint bgPaint = Paint()..color = bg;
    canvas.drawRect(Offset.zero & size, bgPaint);

    // 1) Scanlines.
    final Paint scanPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: _scanlineAlpha)
      ..strokeWidth = 1.0;
    for (double y = 0; y < size.height; y += _scanlineSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scanPaint);
    }

    // 2) Twinkling stars.
    _drawStars(canvas, size, tick);

    // 3) Pelota formation.
    const double formationW =
        (_cols - 1) * _colSpacing + _pixelSize * 7; // 7x7 sprite
    final double phase =
        (tick % _marchPeriodFrames) / _marchPeriodFrames;
    final double arc = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
    final double horizontalTravel = size.width - formationW - 80;
    final double originX = 40 + arc * horizontalTravel;

    final int halfMarches =
        (tick ~/ (_marchPeriodFrames / 2)) % 100000;
    final int playfieldHeightRows =
        (size.height / _rowSpacing).floor();
    final int totalRowOffset = halfMarches * _stepsBetweenHalfMarches;
    final int visibleRowOffset =
        totalRowOffset % (playfieldHeightRows + _rows);
    final double descentOriginY =
        (size.height * 0.05) + visibleRowOffset * _rowSpacing;
    final double bottomRowY =
        descentOriginY + (_rows - 1) * _rowSpacing;
    final bool landed = bottomRowY > size.height - 80;
    if (landed && _lastLandingTick != tick) {
      _lastLandingTick = tick;
      _bgColorIndex = (_bgColorIndex + 1) % _kBgPalette.length;
      _bgCrossfadeStartTick = tick;
    }

    final double originY = landed
        ? size.height - 80 - (_rows - 1) * _rowSpacing
        : descentOriginY;

    // Two-frame leg/rotation animation, same cadence as the
    // invader (6-tick period = ~300ms @ 20Hz).
    final int legFrame = (tick ~/ 6) % 2;
    final Paint pixel = Paint();
    for (int r = 0; r < _rows; r++) {
      pixel.color = _rowColors[r];
      final List<List<int>> shape = _ballShapes[legFrame];
      final double yBase = originY + r * _rowSpacing;
      for (int c = 0; c < _cols; c++) {
        final double xBase = originX + c * _colSpacing;
        _drawSprite(canvas, pixel, xBase, yBase, shape);
      }
    }
  }

  /// Linear interpolation between the previous palette entry and
  /// the new one, over [_bgCrossfadeFrames] frames after a landing.
  Color _computeCurrentBg(int currentTick) {
    if (_bgCrossfadeStartTick == 0) {
      _currentBg = _kBgPalette[_bgColorIndex];
      return _currentBg;
    }
    final int elapsed = currentTick - _bgCrossfadeStartTick;
    if (elapsed >= _bgCrossfadeFrames) {
      _currentBg = _kBgPalette[_bgColorIndex];
      return _currentBg;
    }
    final int fromIndex = (_bgColorIndex - 1 + _kBgPalette.length) %
        _kBgPalette.length;
    final Color from = _kBgPalette[fromIndex];
    final Color to = _kBgPalette[_bgColorIndex];
    final double t = (elapsed / _bgCrossfadeFrames).clamp(0.0, 1.0);
    final Color lerped = Color.lerp(from, to, t) ?? to;
    _currentBg = lerped;
    return lerped;
  }

  void _drawSprite(
      Canvas canvas, Paint paint, double xBase, double yBase, List<List<int>> shape) {
    final int rows = shape.length;
    final int cols = shape[0].length;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (shape[r][c] == 0) continue;
        final Rect rect = Rect.fromLTWH(
          xBase + c * _pixelSize,
          yBase + r * _pixelSize,
          _pixelSize - 0.5,
          _pixelSize - 0.5,
        );
        canvas.drawRect(rect, paint);
      }
    }
  }

  void _drawStars(Canvas canvas, Size size, int tick) {
    const double starBaseAlpha = 0.20;
    final Paint starPaint = Paint();
    for (int i = 0; i < _starCount; i++) {
      final double fx = _hash01(seed + i * 7919);
      final double fy = _hash01(seed + i * 7901 + 13);
      final double ph = _hash01(seed + i * 7793 + 31) * 6.28;
      final double rate = 0.04 + _hash01(seed + i * 7727 + 51) * 0.10;
      final double twinkle =
          0.5 + 0.5 * ((tick * rate) + ph).remainder(6.28).sinToOne();
      final double alpha = starBaseAlpha * (0.3 + 0.7 * twinkle);
      starPaint.color = const Color(0xFF80DEEA).withValues(alpha: alpha);
      final Offset pos = Offset(fx * size.width, fy * size.height);
      final double r = 1.2 + twinkle * 1.4;
      canvas.drawCircle(pos, r, starPaint);
    }
  }

  double _hash01(int n) {
    int x = n;
    x = ((x >> 16) ^ x) * 0x45D9F3B;
    x = ((x >> 16) ^ x) * 0x45D9F3B;
    x = (x >> 16) ^ x;
    return (x & 0xFFFFFF) / 0x1000000;
  }

  @override
  bool shouldRepaint(FootballMarchPainter old) =>
      old._listenable != _listenable;
}

extension on double {
  double sinToOne() => 0.5 + 0.5 * math.sin(this);
}
