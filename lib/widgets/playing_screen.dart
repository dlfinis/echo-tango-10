/// PLAYING screen — chronograph-style stopwatch in microsecond resolution.
///
/// Layout mimics a real digital chronograph:
///   * Big `00:10` segment — the part the player reads at a glance.
///   * Smaller `.0000` segment — microseconds as a sub-label, signalling
///     "this is the part that matters for the win".
///
/// The big-segment color cycles through [kPlayingColorPaletteHex] every
/// [kPlayingColorShiftInterval] (3 s default) to keep the screen alive
/// during the long PLAYING window. The microsecond segment stays in the
/// accent green so the player can always read the precise value when
/// they're trying to land 10.0000.
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
    // 30 fps keeps the 4-decimal counter smooth without taxing the device.
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

  /// Splits the elapsed time into the chronograph-style chunks:
  ///   * `seconds` — integer part (0..60), goes into the big "00:SS" segment.
  ///   * `micros` — microseconds inside the current second, rendered as
  ///     the 4-decimal sub-label.
  String _bigSeconds() => _rendered.inSeconds.remainder(60).toString().padLeft(2, '0');
  String _micros() {
    final int microInsideSecond = _rendered.inMicroseconds.remainder(1000000);
    final int fourDecimals = (microInsideSecond / 100).round();
    return fourDecimals.toString().padLeft(4, '0');
  }

  @override
  Widget build(BuildContext context) {
    final Color bigColor = Color(kPlayingColorPaletteHex[_colorIndex]);
    const Color microColor = Color(kDefaultAccentColorHex);

    return Scaffold(
      backgroundColor: const Color(kDefaultBgColorHex),
      // Layout: a single centered Row with the big "00:SS" and the
      // smaller ".mmmm" sitting on the baseline. FittedBox.scaleDown
      // grows the whole row to fill the screen and only shrinks if it
      // would overflow. No manual breakpoints needed.
      body: Padding(
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
                    fontSize: 480,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                    letterSpacing: -12,
                    fontFamily: 'monospace',
                    fontFamilyFallback: const <String>[
                      'Menlo',
                      'Consolas',
                      'Courier New',
                    ],
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Transform.translate(
                  offset: const Offset(0, 24),
                  child: Text(
                    '.${_micros()}',
                    style: const TextStyle(
                      color: microColor,
                      fontSize: 180,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                      letterSpacing: -4,
                      fontFamily: 'monospace',
                      fontFamilyFallback: <String>[
                        'Menlo',
                        'Consolas',
                        'Courier New',
                      ],
                      fontFeatures: <FontFeature>[
                        FontFeature.tabularFigures(),
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
