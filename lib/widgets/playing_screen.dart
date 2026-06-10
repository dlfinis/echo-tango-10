/// PLAYING screen — chronograph-style stopwatch in three resolution
/// segments (seconds, milliseconds, microseconds), printed on a
/// pure-white background like a paper stopwatch.
///
/// Layout (left-to-right, baseline-aligned):
///   * `SS`     — biggest segment. Pure seconds.
///   * `.mmm`   — middle segment. Milliseconds inside the current
///                second.
///   * `.uu`    — smallest segment. Microseconds inside the current
///                millisecond, rounded to 2 digits (centimicros)
///                so the segment can be visually larger.
///
/// All digits start in BLACK and cycle through a 5-color palette
/// (black → blue → green → amber → magenta → black) every 3s via a
/// [Timer.periodic]. The color is applied to the whole row at once
/// so the player reads 'the chronograph' as a single object whose
/// color is drifting, not three independent color streams.
library;

import 'dart:async';

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

class _PlayingScreenState extends State<PlayingScreen> {
  Timer? _ticker;
  Timer? _timeoutGuard;
  Timer? _colorTimer;
  Duration _rendered = Duration.zero;
  int _colorIndex = 0;

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
        _colorIndex =
            (_colorIndex + 1) % kPlayingColorPaletteHex.length;
      });
    });
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
    super.dispose();
  }

  /// `SS` — the integer second inside the current minute. "00".."59".
  String get _seconds =>
      _rendered.inSeconds.remainder(60).toString().padLeft(2, '0');

  /// `mmm` — milliseconds inside the current second. "000".."999".
  String get _millis {
    final int microInsideSecond =
        _rendered.inMicroseconds.remainder(1000000);
    return (microInsideSecond ~/ 1000).toString().padLeft(3, '0');
  }

  /// `uu` — 2-digit centimicros inside the current millisecond.
  /// Microsecond resolution is overkill for a human-pressable button;
  /// 2 digits gives a 10us resolution which is plenty for the
  /// 1.9ms victory window. Shorter label -> the segment can be
  /// visually larger.
  String get _centimicros {
    final int microInsideSecond =
        _rendered.inMicroseconds.remainder(1000000);
    final int centimicros = (microInsideSecond % 1000) ~/ 10;
    return centimicros.toString().padLeft(2, '0');
  }

  @override
  Widget build(BuildContext context) {
    final Color digitColor = Color(kPlayingColorPaletteHex[_colorIndex]);

    return Scaffold(
      backgroundColor: const Color(kPlayingBackgroundColorHex),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                // SS — biggest. Black-or-color digits on white.
                Text(
                  _seconds,
                  style: TextStyle(
                    color: digitColor,
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
                // .mmm — medium.
                Transform.translate(
                  offset: const Offset(0, 36),
                  child: Text(
                    '.$_millis',
                    style: TextStyle(
                      color: digitColor,
                      fontSize: 420,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                      letterSpacing: -12,
                      fontFamily: 'DSEG7Modern-Regular',
                      fontFamilyFallback: const <String>[
                        'DSEG7Modern-Bold',
                        'DSEG7Classic-Bold',
                        'monospace',
                      ],
                    ),
                  ),
                ),
                // .uu — smallest but bigger than before (since the
                // segment is now 2 digits instead of 3, we have more
                // room).
                Transform.translate(
                  offset: const Offset(0, 64),
                  child: Text(
                    '.$_centimicros',
                    style: TextStyle(
                      color: digitColor,
                      fontSize: 240,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                      letterSpacing: -6,
                      fontFamily: 'DSEG7Modern-Regular',
                      fontFamilyFallback: const <String>[
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
    );
  }
}
