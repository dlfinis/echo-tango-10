/// RESULT screen — chronograph-style final time + signed delta vs 10s.
///
/// Same layout language as [PlayingScreen]: big `00:SS` segment with a
/// smaller `.mmmm` sub-label. On asymmetric victory (10.0000s <= elapsed
/// <= 10.0019s) the digits go green and the screen shows VICTORIA. On
/// a miss they stay white and the screen shows CASI.
///
/// PR1: the WINNER_NAME branch is wired in the state machine but the
/// screen is a placeholder that returns to WAITING on next pulse.
/// PR2 lands confetti + name entry.
library;

import 'package:flutter/material.dart';

import '../utils/constants.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.elapsedSeconds,
    required this.onNext,
  });

  final double elapsedSeconds;
  final VoidCallback onNext;

  double get _delta => elapsedSeconds - kTargetSeconds;

  /// 2-digit sub-label (centiseconds inside the current second).
  String get _centisLabel {
    final int microInsideSecond =
        _renderedSeconds.inMicroseconds.remainder(1000000);
    return (microInsideSecond / 10000).round().toString().padLeft(2, '0');
  }

  Duration get _renderedSeconds =>
      Duration(microseconds: (elapsedSeconds * 1000000).round());

  String get _deltaText {
    final d = _delta;
    final sign = d >= 0 ? '+' : '-';
    return '$sign${d.abs().toStringAsFixed(4)}s';
  }

  /// Asymmetric victory: 10.0000s <= elapsed <= 10.0019s. Coming in
  /// short is always a miss.
  bool get _isVictory =>
      elapsedSeconds >= kTargetSeconds &&
      elapsedSeconds <= kTargetSeconds + kVictoryOvershootSeconds;

  @override
  Widget build(BuildContext context) {
    const accent = Color(kDefaultAccentColorHex);
    const white = Color(kDefaultTextColorHex);

    final Color bigColor = _isVictory ? accent : white;
    final Color microColor = _isVictory ? accent : white;
    final String verdictLabel = _isVictory ? '¡VICTORIA!' : '¡CASI!';
    final Color verdictColor = _isVictory ? accent : white;

    return Scaffold(
      backgroundColor: const Color(kDefaultBgColorHex),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onNext,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                // Chronograph — big SS with .mmmm sub-label.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: <Widget>[
                      Text(
                        '00:${_bigSecondsLabel()}',
                        style: TextStyle(
                          color: bigColor,
                          fontSize: 720,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          letterSpacing: -20,
                          fontFamily: 'DSEG7Modern-Regular',
                          fontFamilyFallback: const <String>[
                            'DSEG7Modern-Bold',
                            'DSEG7Classic-Bold',
                            'monospace',
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Transform.translate(
                        offset: const Offset(0, 36),
                        child: Text(
                          '.$_centisLabel',
                          style: TextStyle(
                            color: microColor,
                            fontSize: 280,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                            letterSpacing: -5,
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
                const SizedBox(height: 16),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(
                    _deltaText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _isVictory ? accent : white,
                      fontSize: 120,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      fontFamily: 'DSEG7Modern-Regular',
                      fontFamilyFallback: const <String>[
                        'DSEG7Modern-Bold',
                        'DSEG7Classic-Bold',
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(
                    verdictLabel,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: verdictColor,
                      fontSize: 140,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 8,
                      fontFamily: 'BungeeInline',
                      fontFamilyFallback: const <String>['Bungee'],
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

  /// Inline label: the `00:SS` part of the chronograph.
  String _bigSecondsLabel() {
    final int s = _renderedSeconds.inSeconds.remainder(60);
    return s.toString().padLeft(2, '0');
  }
}
