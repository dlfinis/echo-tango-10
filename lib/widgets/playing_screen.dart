/// PLAYING screen — chronograph-style stopwatch in microsecond resolution.
///
/// Layout mimics a real digital chronograph:
///   * Big `00:SS` segment — the part the player reads at a glance.
///   * Smaller `.cc` segment — centiseconds as a sub-label, signalling
///     "this is the part that matters for the win".
///
/// The big-segment color cycles through [kPlayingColorPaletteHex] every
/// [kPlayingColorShiftInterval] (3 s default) to keep the screen alive
/// during the long PLAYING window. The centisecond segment stays in the
/// accent green so the player can always read the precise value when
/// they're trying to land 10.00.
///
/// Background: a [PlayingBackdropPainter] draws scanlines + ~80 colored
/// streaks that travel across the screen in random directions, like
/// hyperspace / starfield motion. The streaks are dim enough to read as
/// "atmosphere" but bright enough to feel alive, and their color is
/// drawn from a 5-color palette so the screen is visually busy.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/stopwatch_controller.dart';
import '../utils/constants.dart';

class PlayingScreen extends StatefulWidget {
  const PlayingScreen({
    super.key,
    required this.controller,
    required this.onTimeout,
  });

  final StopwatchController controller;
  final VoidCallback onTimeout;

  @override
  State<PlayingScreen> createState() => _PlayingScreenState();
}

class _PlayingScreenState extends State<PlayingScreen>
    with SingleTickerProviderStateMixin {
  Timer? _ticker;
  Timer? _timeoutGuard;
  Timer? _colorTimer;
  Duration _rendered = Duration.zero;
  int _colorIndex = 0;

  /// Drives the backdrop repaint. ~16fps is enough to make the streaks
  /// feel like motion without burning cycles.
  int _backdropTick = 0;
  late final AnimationController _backdropTicker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(milliseconds: 33),
      (_) => _onTick(),
    );
    _timeoutGuard = Timer(kPlayingTimeout, () {
      if (!mounted) return;
      widget.onTimeout();
    });
    _colorTimer = Timer.periodic(kPlayingColorShiftInterval, (_) {
      if (!mounted) return;
      setState(() {
        _colorIndex = (_colorIndex + 1) % kPlayingColorPaletteHex.length;
      });
    });
    _backdropTicker = AnimationController(
      vsync: this,
      duration: const Duration(days: 365),
    )..addListener(() {
        if (!mounted) return;
        setState(() => _backdropTick = (_backdropTick + 1) % 100000);
      });
    _backdropTicker.repeat(period: const Duration(milliseconds: 50));
  }

  void _onTick() {
    if (!mounted) return;
    setState(() {
      _rendered = widget.controller.elapsed;
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _timeoutGuard?.cancel();
    _colorTimer?.cancel();
    _backdropTicker.dispose();
    super.dispose();
  }

  /// Splits the elapsed time into the chronograph-style chunks:
  ///   * `seconds` — integer part (0..60), goes into the big "00:SS" segment.
  ///   * `centis` — centiseconds (0..99) inside the current second,
  ///     rendered as the 2-digit sub-label.
  String _bigSeconds() =>
      _rendered.inSeconds.remainder(60).toString().padLeft(2, '0');
  String _centis() {
    final int microInsideSecond =
        _rendered.inMicroseconds.remainder(1000000);
    final int centis = (microInsideSecond / 10000).round();
    return centis.toString().padLeft(2, '0');
  }

  @override
  Widget build(BuildContext context) {
    final Color bigColor = Color(kPlayingColorPaletteHex[_colorIndex]);
    const Color microColor = Color(kDefaultAccentColorHex);

    return Scaffold(
      backgroundColor: const Color(kDefaultBgColorHex),
      body: Stack(
        children: <Widget>[
          // Animated hyperspace backdrop: dim scanlines + ~80 colored
          // streaks traveling across the screen in random directions.
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _backdropTicker,
              builder: (BuildContext context, Widget? _) {
                return CustomPaint(
                  painter: PlayingBackdropPainter(
                    tick: _backdropTick,
                    seed: 4242,
                  ),
                );
              },
            ),
          ),
          // Foreground chronograph.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    Text(
                      '00:${_bigSeconds()}',
                      style: TextStyle(
                        color: bigColor,
                        fontSize: 880,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        letterSpacing: -28,
                        fontFamily: 'DSEG7Modern-Regular',
                        fontFamilyFallback: const <String>[
                          'DSEG7Modern-Bold',
                          'DSEG7Classic-Bold',
                          'monospace',
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Transform.translate(
                      offset: const Offset(0, 48),
                      child: Text(
                        '.${_centis()}',
                        style: const TextStyle(
                          color: microColor,
                          fontSize: 360,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          letterSpacing: -10,
                          fontFamily: 'DSEG7Modern-Regular',
                          fontFamilyFallback: <String>[
                            'DSEG7Modern-Bold',
                            'DSEG7Classic-Bold',
                            'monospace',
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// PlayingBackdropPainter — "hyperspace streaks" backdrop for the PLAYING
// screen. ~80 colored streaks travel across the screen in seeded random
// directions. Each streak wraps around when it leaves the viewport, so
// the formation density stays constant. The painter also adds the same
// scanline layer as the waiting screen so the two screens feel related.
//
// Streak color is drawn from a 5-color palette so the backdrop reads as
// multicolor (cyan, green, magenta, amber, white) — not a single tinted
// overlay. Brightness is kept low (alpha 0.25 max) so the foreground
// chronograph always wins the visual hierarchy.
// ===========================================================================

class PlayingBackdropPainter extends CustomPainter {
  PlayingBackdropPainter({required this.tick, this.seed = 4242});

  final int tick;
  final int seed;

  static const int _streakCount = 80;
  static const double _scanlineSpacing = 3.0;
  static const double _scanlineAlpha = 0.05;

  static const List<Color> _palette = <Color>[
    Color(0xFF00E5FF), // cyan
    Color(0xFF00FF66), // green
    Color(0xFFFF4DD2), // magenta
    Color(0xFFFFD400), // amber
    Color(0xFFFFFFFF), // white
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // Near-black backdrop.
    final Paint bgPaint = Paint()..color = const Color(0xFF0A0A0A);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // 1) Scanlines.
    final Paint scanPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: _scanlineAlpha)
      ..strokeWidth = 1.0;
    for (double y = 0; y < size.height; y += _scanlineSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scanPaint);
    }

    // 2) Streaks — each one has a fixed angle, a fixed speed, and a
    // fixed color; position cycles modulo the screen dimensions so
    // the formation stays uniformly dense.
    final Paint streakPaint = Paint()
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < _streakCount; i++) {
      final double angle =
          _hash01(seed + i * 9173) * 2 * math.pi;
      final double speed =
          1.5 + _hash01(seed + i * 9137 + 19) * 4.5; // px per tick
      final double length =
          12.0 + _hash01(seed + i * 9119 + 41) * 28.0;
      final int colorIdx = i % _palette.length;
      final double alpha = 0.18 + _hash01(seed + i * 9101 + 53) * 0.18;
      streakPaint.color = _palette[colorIdx].withValues(alpha: alpha);

      // Initial position is random inside a band 1.5x the screen
      // dimensions; the modulo keeps it on-screen.
      final double startX =
          _hash01(seed + i * 9241) * size.width * 1.5 - size.width * 0.25;
      final double startY =
          _hash01(seed + i * 9281 + 7) * size.height * 1.5 -
              size.height * 0.25;
      final double dist = tick * speed;
      final double cx = (startX + math.cos(angle) * dist) % (size.width + 200);
      final double cy = (startY + math.sin(angle) * dist) %
          (size.height + 200);
      // Off-screen on the negative side — wrap to positive.
      final double wrappedX = cx < -50 ? cx + size.width + 200 : cx;
      final double wrappedY = cy < -50 ? cy + size.height + 200 : cy;
      final double tailX = wrappedX - math.cos(angle) * length;
      final double tailY = wrappedY - math.sin(angle) * length;
      canvas.drawLine(
        Offset(tailX, tailY),
        Offset(wrappedX, wrappedY),
        streakPaint,
      );
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
  bool shouldRepaint(PlayingBackdropPainter old) => old.tick != tick;
}
