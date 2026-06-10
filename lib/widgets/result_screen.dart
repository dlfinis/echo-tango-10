/// RESULT screen — shows raw time and signed delta vs the 10 s target.
///
/// On asymmetric victory (10.000s <= elapsed <= 10.010s) the screen
/// flashes "VICTORIA" in the green accent color. A miss shows the
/// raw time + signed delta in white.
///
/// The next pulse advances to WINNER_NAME (handled by the AppRoot once
/// the state machine has read the isVictory flag). This screen itself
/// is presentation only — it calls [onNext] on tap or external pulse.
library;

import 'package:flutter/material.dart';

import '../utils/constants.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.elapsedSeconds,
    required this.onNext,
  });

  /// Raw measured time, in seconds, from `Stopwatch.elapsedMicroseconds`.
  final double elapsedSeconds;

  /// Called by the parent on the next accepted pulse.
  final VoidCallback onNext;

  double get _delta => elapsedSeconds - kTargetSeconds;

  String get _rawTime => elapsedSeconds.toStringAsFixed(4);

  String get _deltaText {
    final d = _delta;
    final sign = d >= 0 ? '+' : '-';
    return '$sign${d.abs().toStringAsFixed(4)}s';
  }

  /// Asymmetric victory: 10.000s <= elapsed <= 10.010s. Coming in short
  /// is always a miss.
  bool get _isVictory =>
      elapsedSeconds >= kTargetSeconds &&
      elapsedSeconds <= kTargetSeconds + kVictoryOvershootSeconds;

  bool get _isMiss => !_isVictory;

  @override
  Widget build(BuildContext context) {
    const accent = Color(kDefaultAccentColorHex);
    const white = Color(kDefaultTextColorHex);

    return Scaffold(
      backgroundColor: const Color(kDefaultBgColorHex),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onNext,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Big raw time — same FittedBox trick as the playing screen.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  _rawTime,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isVictory ? accent : white,
                    fontSize: 280,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -6,
                    height: 1.0,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
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
                    color: _isMiss ? white : accent,
                    fontSize: 120,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  _isVictory ? '¡VICTORIA!' : '¡CASI!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isVictory ? accent : white,
                    fontSize: 96,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
