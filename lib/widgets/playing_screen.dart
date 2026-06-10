/// PLAYING screen — chronograph-style stopwatch in three resolution
/// segments (seconds, milliseconds, microseconds).
///
/// Layout (left-to-right, baseline-aligned):
///   * `SS`     — biggest segment, e.g. "10". Pure seconds.
///   * `.mmm`   — middle segment, e.g. ".234". Milliseconds inside
///                the current second.
///   * `.uuuu`  — smallest segment, e.g. ".5678". Microseconds inside
///                the current millisecond.
///
/// Three sizes give each segment its own visual weight so the player
/// can read the second-tick from a distance and the microsecond tick
/// up close.
///
/// The digits are a single static white — no flashing, no rotation —
/// per Diego: "blanco para notar el juego". The screen has no other
/// animations or distractions during play; only the chronograph.
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
  Duration _rendered = Duration.zero;

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

  /// `uuuu` — microseconds inside the current millisecond. "000".."999".
  String get _micros {
    final int microInsideSecond =
        _rendered.inMicroseconds.remainder(1000000);
    return (microInsideSecond % 1000).toString().padLeft(3, '0');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(kDefaultBgColorHex),
      // The three segments share a single FittedBox so the whole row
      // grows to fill the screen width and shrinks together if the
      // longest segment won't fit.
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
                // SS — biggest. Static white, DSEG7 Modern.
                Text(
                  _seconds,
                  style: const TextStyle(
                    color: Color(kPlayingDigitColorHex),
                    fontSize: 880,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                    letterSpacing: -28,
                    fontFamily: 'DSEG7Modern-Regular',
                    fontFamilyFallback: <String>[
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
                    style: const TextStyle(
                      color: Color(kPlayingDigitColorHex),
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
                // .uuuu — smallest. Translates further down to sit
                // on the baseline next to the medium segment.
                Transform.translate(
                  offset: const Offset(0, 64),
                  child: Text(
                    '.$_micros',
                    style: const TextStyle(
                      color: Color(kPlayingDigitColorHex),
                      fontSize: 180,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                      letterSpacing: -4,
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
    );
  }
}
