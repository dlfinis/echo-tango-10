/// RESULT screen — chronograph-style final time + signed delta vs 10s
/// with a 4-branch verdict:
///
///   * VICTORIA — `delta < kVictoryOvershootSeconds` (1.9 ms).
///     Digits go green, no glitch, label "¡GANASTE!".
///   * CASI     — 1.9 ms to 100 ms (kNearMissUpperBoundSeconds).
///     Retro CRT glitch: shake + color flicker + red border for 1.2 s.
///     Label "¡POR POCO!" or "¡CASI CASI!".
///   * UPS-SHALLOW — 100 ms to 300 ms. Background tints a soft red,
///     no glitch, label "¡POR UN PELITO!" / "¡CERCA PERO NO!" /
///     "¡CASI, CASI!" picked at random per visit.
///   * UPS-DEEP — > 300 ms OR elapsed < 10 s (came in short).
///     Background tints a deeper red, label "¡UPS!" / "¡A LA
///     PRÓXIMA!" / "¡QUÉ MAL!" picked at random per visit.
///
/// The "UPS" branches were merged into one tier in iteration #9
/// (just "UPS"). Diego asked for them to be split again with
/// different copy and visual treatment so the player gets a more
/// nuanced read of how off they were.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/constants.dart';

enum _Verdict { victory, casi, upsShallow, upsDeep }

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
  late final String _shallowMessage;
  late final String _deepMessage;
  late final _Verdict _verdict;

  static const List<String> _shallowMessages = <String>[
    '¡POR UN PELITO!',
    '¡CERCA PERO NO!',
    '¡CASI, CASI!',
  ];

  static const List<String> _deepMessages = <String>[
    '¡UPS!',
    '¡A LA PRÓXIMA!',
    '¡QUÉ MAL!',
  ];

  _Verdict _classifyVerdict(double elapsed) {
    if (elapsed < kTargetSeconds) return _Verdict.upsDeep;
    final double delta = elapsed - kTargetSeconds;
    if (delta <= kVictoryOvershootSeconds) return _Verdict.victory;
    if (delta < kNearMissUpperBoundSeconds) return _Verdict.casi;
    if (delta < kBigMissUpperBoundSeconds) return _Verdict.upsShallow;
    return _Verdict.upsDeep;
  }

  @override
  void initState() {
    super.initState();
    _verdict = _classifyVerdict(widget.elapsedSeconds);
    _shallowMessage = _shallowMessages[
        math.Random().nextInt(_shallowMessages.length)];
    _deepMessage =
        _deepMessages[math.Random().nextInt(_deepMessages.length)];

    _glitchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _glitchAnim = CurvedAnimation(
      parent: _glitchController,
      curve: Curves.easeOut,
    );
    if (_verdict == _Verdict.casi) {
      _glitchController.forward();
    } else {
      _glitchController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _glitchController.dispose();
    super.dispose();
  }

  Duration get _renderedSeconds =>
      Duration(microseconds: (widget.elapsedSeconds * 1000000).round());

  String get _bigSecondsLabel {
    final int s = _renderedSeconds.inSeconds.remainder(60);
    return s.toString().padLeft(2, '0');
  }

  String get _millisLabel {
    final int microInsideSecond =
        _renderedSeconds.inMicroseconds.remainder(1000000);
    return (microInsideSecond ~/ 1000).toString().padLeft(3, '0');
  }

  double get _delta => widget.elapsedSeconds - kTargetSeconds;

  String get _deltaText {
    final d = _delta;
    final String sign = d >= 0 ? '+' : '-';
    return '$sign${d.abs().toStringAsFixed(4)}s';
  }

  String get _verdictLabel {
    switch (_verdict) {
      case _Verdict.victory:
        return '¡GANASTE!';
      case _Verdict.casi:
        return '¡POR POCO!';
      case _Verdict.upsShallow:
        return _shallowMessage;
      case _Verdict.upsDeep:
        return _deepMessage;
    }
  }

  /// Background color tinted by the verdict. VICTORIA = green tint,
  /// CASI = amber tint (suggests 'caution, you almost had it'),
  /// UPS-SHALLOW = soft red, UPS-DEEP = deeper red.
  Color get _verdictBg {
    switch (_verdict) {
      case _Verdict.victory:
        return const Color(0xFF003A0A);
      case _Verdict.casi:
        return const Color(0xFF3A1F00);
      case _Verdict.upsShallow:
        return const Color(0xFF2A0A0A);
      case _Verdict.upsDeep:
        return const Color(0xFF1A0505);
    }
  }

  Color get _verdictColor {
    switch (_verdict) {
      case _Verdict.victory:
        return const Color(kDefaultAccentColorHex);
      case _Verdict.casi:
        return const Color(0xFFFFC107);
      case _Verdict.upsShallow:
        return const Color(0xFFFF8A80);
      case _Verdict.upsDeep:
        return const Color(kDefaultTextColorHex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _verdictBg,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onNext,
        child: AnimatedBuilder(
          animation: _glitchAnim,
          builder: (BuildContext context, Widget? _) {
            return _buildBody(glitchT: _glitchAnim.value);
          },
        ),
      ),
    );
  }

  Widget _buildBody({required double glitchT}) {
    const accent = Color(kDefaultAccentColorHex);
    const white = Color(kDefaultTextColorHex);

    final bool glitchActive =
        _verdict == _Verdict.casi && glitchT < 1.0;
    final double glitchIntensity = glitchActive ? (1.0 - glitchT) : 0.0;
    final double shake = glitchActive
        ? math.sin(glitchT * 4 * math.pi) * 4.0 * glitchIntensity
        : 0.0;
    final Color digitColor = _verdict == _Verdict.victory
        ? accent
        : (glitchActive
            ? Color.lerp(white, const Color(0xFFFF5252), glitchIntensity * 0.6)!
            : _verdictColor);
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
                        '00:$_bigSecondsLabel',
                        style: TextStyle(
                          color: digitColor,
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
                      Transform.translate(
                        offset: Offset(shake, 36),
                        child: Text(
                          '.$_millisLabel',
                          style: TextStyle(
                            color: digitColor,
                            fontSize: 320,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                            letterSpacing: -8,
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
                      color: _verdict == _Verdict.victory ? accent : white,
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
                  _verdictLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _verdictColor,
                    fontSize: 160,
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
}
