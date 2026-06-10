/// RESULT screen — chronograph-style final time + signed delta vs 10s.
///
/// Same layout language as [PlayingScreen]: big `00:SS` segment with a
/// smaller `.mmmm` sub-label. On asymmetric victory (10.0000s <= elapsed
/// <= 10.0019s) the digits go green and the screen shows VICTORIA. On
/// a miss they stay white and the screen shows CASI.
///
/// On a "casi" (miss) the screen animates a retro CRT glitch effect:
/// the chronograph digits shift horizontally by 2-4 pixels on a sine
/// wave and flash between white and a desaturated red, twice per
/// second, for 1.2s. The animation then settles to a static state
/// so the player can read the result. A victory (delta in range)
/// animates a brief green flash instead.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/constants.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.elapsedSeconds,
    required this.onNext,
  });

  final double elapsedSeconds;
  final VoidCallback onNext;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glitchController;
  late final Animation<double> _glitchAnim;

  @override
  void initState() {
    super.initState();
    // 1.2s glitch animation, run once on mount.
    _glitchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _glitchAnim = CurvedAnimation(
      parent: _glitchController,
      curve: Curves.easeOut,
    );
    _glitchController.forward();
  }

  @override
  void dispose() {
    _glitchController.dispose();
    super.dispose();
  }

  double get _delta => widget.elapsedSeconds - kTargetSeconds;

  /// 4-digit sub-label (microseconds inside the current second, rounded
  /// to 10us for display).
  String get _microsLabel {
    final int microInsideSecond =
        _renderedSeconds.inMicroseconds.remainder(1000000);
    return (microInsideSecond / 100).round().toString().padLeft(4, '0');
  }

  Duration get _renderedSeconds =>
      Duration(microseconds: (widget.elapsedSeconds * 1000000).round());

  String get _deltaText {
    final d = _delta;
    final String sign = d >= 0 ? '+' : '-';
    return '$sign${d.abs().toStringAsFixed(4)}s';
  }

  bool get _isVictory =>
      widget.elapsedSeconds >= kTargetSeconds &&
      widget.elapsedSeconds <= kTargetSeconds + kVictoryOvershootSeconds;

  @override
  Widget build(BuildContext context) {
    const accent = Color(kDefaultAccentColorHex);
    const white = Color(kDefaultTextColorHex);

    return Scaffold(
      backgroundColor: const Color(kDefaultBgColorHex),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onNext,
        child: AnimatedBuilder(
          animation: _glitchAnim,
          builder: (BuildContext context, Widget? _) {
            return _buildBody(
              accent: accent,
              white: white,
              glitchT: _glitchAnim.value,
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody({
    required Color accent,
    required Color white,
    required double glitchT,
  }) {
    // CRT glitch parameters — applied only to the "casi" branch.
    final bool glitchActive = !_isVictory && glitchT < 1.0;
    final double glitchIntensity = glitchActive ? (1.0 - glitchT) : 0.0;
    // Two full sine cycles over the 1.2s animation, amplitude in px.
    final double shake =
        glitchActive ? math.sin(glitchT * 4 * math.pi) * 4.0 * glitchIntensity : 0.0;
    // Color flicker for "casi": mix between white and a desaturated red.
    final Color bigColor = _isVictory
        ? accent
        : Color.lerp(white, const Color(0xFFFF5252), glitchIntensity * 0.6)!;
    final Color microColor = bigColor;

    // Subtle red border flash on the body during the glitch.
    final Color borderColor = glitchActive
        ? const Color(0xFFFF5252).withValues(alpha: glitchIntensity * 0.4)
        : const Color(0x00000000);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Transform.translate(
                  offset: Offset(shake, 0),
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
                        offset: Offset(shake, 36),
                        child: Text(
                          '.$_microsLabel',
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
              ),
              const SizedBox(height: 16),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Transform.translate(
                  offset: Offset(shake * 0.7, 0),
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
              ),
              const SizedBox(height: 16),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  _isVictory ? '¡VICTORIA!' : '¡CASI!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isVictory ? accent : white,
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
    );
  }

  String _bigSecondsLabel() {
    final int s = _renderedSeconds.inSeconds.remainder(60);
    return s.toString().padLeft(2, '0');
  }
}
