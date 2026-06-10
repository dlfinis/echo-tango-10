/// RESULT screen — shows raw time and signed delta vs the 10 s target.
///
/// On `|delta| < kVictoryToleranceSeconds` (10 ms) the delta text is
/// rendered in the green accent color (spec requirement 6).
///
/// PR1 simplification: the WINNER_NAME branch is wired in the state
/// machine but this screen is a placeholder that always returns to
/// WAITING on the next pulse. The real winner flow with name entry
/// and confetti lands in PR2 (task T8).
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

  bool get _isVictory => _delta.abs() < kVictoryToleranceSeconds;

  @override
  Widget build(BuildContext context) {
    const accent = Color(kDefaultAccentColorHex);
    const white = Color(kDefaultTextColorHex);

    return Scaffold(
      backgroundColor: const Color(kDefaultBgColorHex),
      body: SafeArea(
        child: GestureDetector(
          // Make the next-pulse tap work even before a keyboard listener
          // is wired up (handy for manual web testing on a trackpad).
          behavior: HitTestBehavior.opaque,
          onTap: onNext,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _rawTime,
                style: const TextStyle(
                  color: white,
                  fontSize: 96,
                  fontWeight: FontWeight.w900,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _deltaText,
                style: TextStyle(
                  color: _isVictory ? accent : white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 64),
              // PR1 placeholder — PR2 wires confetti + winner name entry.
              const Text(
                'VICTORIA — ingreso de nombre en PR2',
                textAlign: TextAlign.center,
                style: TextStyle(color: white, fontSize: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
