/// RESULT screen — chronograph-style final time + signed delta vs 10s
/// with 4 verdict tiers (the screen learns from classic arcade
/// games where the feedback language is direct and a little mean):
///
///   * VICTORIA       — `elapsed` in `[10.0000, 10.0019]`.
///                     Background tints green, big "¡GANASTE!".
///   * CASI CASI!     — `elapsed` in `[9.0, 10.0)` OR
///                     `elapsed` in `(10.0019, 10.50]`.
///                     Background tints amber, retro CRT glitch,
///                     "¡CASI, CASI!".
///   * NI POR ASOMO!  — `elapsed < 9.0` (player was over a second
///                     short of the target — they never had a
///                     chance to be on time).
///                     Background tints soft red, screen shakes
///                     hard once, "¡NI POR ASOMO!".
///   * TE PASASTE!    — `elapsed > 10.50` (player blew past by more
///                     than half a second).
///                     Background tints deep red, the chronograph
///                     digits scroll left-to-right and fade, then
///                     "¡TE PASASTE!".
///
/// The format on this screen is `SS.mmm` (seconds dot millis) — no
/// `00:` minutes prefix and no centimicros, so the result reads as
/// a clean two-segment time.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/constants.dart';

enum _Verdict { victory, casi, niPorAsomo, tePasaste }

class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.elapsedSeconds,
    required this.onNext,
    this.resultTimeoutSeconds = 5,
  });

  final double elapsedSeconds;
  final VoidCallback onNext;

  /// How many seconds the screen stays visible before
  /// auto-calling [onNext]. Configurable in the admin panel.
  final int resultTimeoutSeconds;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with TickerProviderStateMixin {
  late final AnimationController _glitchController;
  Timer? _autoReturnTimer;
  late final Animation<double> _glitchAnim;
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnim;
  late final AnimationController _scrollController;
  late final Animation<double> _scrollAnim;
  late final _Verdict _verdict;
  AnimationController? _spinController;
  AnimationController? _dropController;
  AnimationController? _teShakeController;

  _Verdict _classifyVerdict(double elapsed) {
    if (elapsed < kFarShortThresholdSeconds) return _Verdict.niPorAsomo;
    if (elapsed > kFarOvershootThresholdSeconds) return _Verdict.tePasaste;
    if (elapsed >= kTargetSeconds &&
        elapsed <= kTargetSeconds + kVictoryOvershootSeconds) {
      return _Verdict.victory;
    }
    return _Verdict.casi;
  }

  @override
  void initState() {
    super.initState();
    _verdict = _classifyVerdict(widget.elapsedSeconds);

    // 1.2s glitch animation, fired on mount for the CASI branch.
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

    // Single hard shake for the NI POR ASOMO branch (0.5s).
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnim = _shakeController;
    if (_verdict == _Verdict.niPorAsomo) {
      _shakeController.forward();
    }

    // Scroll-and-fade for the TE PASASTE branch (1.5s).
    _scrollController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scrollAnim = CurvedAnimation(
      parent: _scrollController,
      curve: Curves.easeIn,
    );
    if (_verdict == _Verdict.tePasaste) {
      _scrollController.forward();
    }

    // Per-verdict emoji animation controllers. CASI has no controller
    // (the emoji renders static, centered).
    if (_verdict == _Verdict.victory) {
      _spinController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 4),
      )..repeat(reverse: true);
    } else if (_verdict == _Verdict.niPorAsomo) {
      _dropController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
      CurvedAnimation(parent: _dropController!, curve: Curves.easeIn)
          .addListener(() {});
      _dropController!.forward();
    } else if (_verdict == _Verdict.tePasaste) {
      _teShakeController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800),
      )..forward();
    }

    // Auto-return to WAITING after the configured timeout. Tap
    // on the screen calls onNext immediately, which cancels
    // the timer in dispose.
    _autoReturnTimer = Timer(
      Duration(seconds: widget.resultTimeoutSeconds),
      () {
        if (mounted) widget.onNext();
      },
    );
  }

  @override
  void dispose() {
    _autoReturnTimer?.cancel();
    _glitchController.dispose();
    _shakeController.dispose();
    _scrollController.dispose();
    _spinController?.dispose();
    _dropController?.dispose();
    _teShakeController?.dispose();
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

  /// `u` — 1-digit micros (100µs resolution). 1 digit maximizes
  /// horizontal space for the main digits.
  String get _microsLabel {
    final int microInsideSecond =
        _renderedSeconds.inMicroseconds.remainder(1000000);
    final int decimicros = (microInsideSecond % 1000) ~/ 100;
    return decimicros.toString(); // 1 digit: 0..9
  }

  double get _delta => widget.elapsedSeconds - kTargetSeconds;

  String get _deltaText {
    final d = _delta;
    final String sign = d >= 0 ? '+' : '-';
    return '$sign${d.abs().toStringAsFixed(4)}';
  }

  String get _verdictLabel {
    switch (_verdict) {
      case _Verdict.victory:
        return '¡GANASTE!';
      case _Verdict.casi:
        return '¡CASI, CASI!';
      case _Verdict.niPorAsomo:
        return '¡NI POR ASOMO!';
      case _Verdict.tePasaste:
        return '¡TE PASASTE!';
    }
  }

  String get _emoji {
    switch (_verdict) {
      case _Verdict.victory:
        return '😀';
      case _Verdict.casi:
        return '😐';
      case _Verdict.niPorAsomo:
        return '😢';
      case _Verdict.tePasaste:
        return '🤦';
    }
  }

  Widget _buildEmoji() {
    final Widget emoji = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: Text(
        _emoji,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 120,
          fontFamily: 'AppleColorEmoji',
          fontFamilyFallback: <String>['NotoColorEmoji', 'Segoe UI Emoji'],
        ),
      ),
    );

    switch (_verdict) {
      case _Verdict.victory:
        return AnimatedBuilder(
          animation: _spinController!,
          builder: (BuildContext context, Widget? child) {
            final double t = _spinController!.value;
            return Transform.rotate(
              angle: t * 2 * math.pi,
              child: child,
            );
          },
          child: emoji,
        );

      case _Verdict.casi:
        return emoji;

      case _Verdict.niPorAsomo:
        return AnimatedBuilder(
          animation: _dropController!,
          builder: (BuildContext context, Widget? child) {
            final double t = Curves.easeIn.transform(_dropController!.value);
            return Transform.translate(
              offset: Offset(0, -80 * (1 - t)),
              child: child,
            );
          },
          child: emoji,
        );

      case _Verdict.tePasaste:
        return AnimatedBuilder(
          animation: _teShakeController!,
          builder: (BuildContext context, Widget? child) {
            final double t = _teShakeController!.value;
            final double decay = 1 - t;
            return Transform.translate(
              offset: Offset(math.sin(t * 2 * math.pi * 12) * 8 * decay, 0),
              child: child,
            );
          },
          child: emoji,
        );
    }
  }

  /// Background color tinted by the verdict. The first ~50ms of
  /// mount animate the background IN from black via the implicit
  /// AnimatedContainer.
  Color get _verdictBg {
    switch (_verdict) {
      case _Verdict.victory:
        return const Color(0xFF003A0A); // deep green
      case _Verdict.casi:
        return const Color(0xFF3A1F00); // deep amber
      case _Verdict.niPorAsomo:
        return const Color(0xFF2A0505); // soft red
      case _Verdict.tePasaste:
        return const Color(0xFF1A0303); // deeper red
    }
  }

  Color get _verdictColor {
    switch (_verdict) {
      case _Verdict.victory:
        return const Color(kDefaultAccentColorHex);
      case _Verdict.casi:
        return const Color(0xFFFFC107);
      case _Verdict.niPorAsomo:
        return const Color(0xFFFF7070);
      case _Verdict.tePasaste:
        return const Color(0xFFFF5252);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000), // pre-animate from black
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onNext,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          color: _verdictBg,
          child: AnimatedBuilder(
            animation: Listenable.merge(<Listenable>[
              _glitchAnim,
              _shakeAnim,
              _scrollAnim,
            ]),
            builder: (BuildContext context, Widget? _) {
              return _buildBody(
                glitchT: _glitchAnim.value,
                shakeT: _shakeAnim.value,
                scrollT: _scrollAnim.value,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBody({
    required double glitchT,
    required double shakeT,
    required double scrollT,
  }) {
    const accent = Color(kDefaultAccentColorHex);
    const white = Color(kDefaultTextColorHex);

    // Per-verdict animation deltas.
    double shakeX = 0;
    double shakeY = 0;
    if (_verdict == _Verdict.casi && glitchT < 1.0) {
      final double intensity = (1.0 - glitchT);
      shakeX = math.sin(glitchT * 4 * math.pi) * 4.0 * intensity;
    } else if (_verdict == _Verdict.niPorAsomo) {
      // Damped sine: strong at the start, decaying to zero.
      final double decay = (1.0 - shakeT);
      shakeX = math.sin(shakeT * 30) * 14 * decay;
      shakeY = math.cos(shakeT * 25) * 6 * decay;
    }

    // TE PASASTE: digits scroll horizontally off-screen left,
    // and fade out as they go.
    double scrollOffset = 0;
    double opacity = 1.0;
    if (_verdict == _Verdict.tePasaste) {
      // Animate from 0 (centered) to -screen.width (off-left).
      // We use a simple linear offset here; the screen's
      // actual width is set by the parent SizedBox so this is
      // bounded to the screen.
      scrollOffset = -1.0 * scrollT; // 0..-1 (relative units)
      opacity = 1.0 - scrollT;
    }

    final Color digitColor = _verdict == _Verdict.victory
        ? accent
        : (_verdict == _Verdict.casi
            ? (glitchT < 1.0
                ? Color.lerp(white, const Color(0xFFFF5252),
                    (1.0 - glitchT) * 0.6)!
                : _verdictColor)
            : _verdictColor);
    final Color borderColor = (_verdict == _Verdict.casi && glitchT < 1.0)
        ? const Color(0xFFFF5252).withValues(alpha: (1.0 - glitchT) * 0.4)
        : const Color(0x00000000);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        // SizedBox.expand + FittedBox(BoxFit.contain) so the WHOLE
        // result block (chronograph + delta + verdict) grows or
        // shrinks together to fill the viewport. The natural
        // fontSize is large enough that FittedBox always scales
        // down, but the content scales up on big screens. This
        // is the same pattern used in WaitingScreen and
        // PlayingScreen.
        child: SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
              // The big chronograph row — TWO text widgets
              // (SS + .mmmcc), no Transforms, no Paddings,
              // baseline-aligned directly. The outer FittedBox
              // handles scaling the whole block.
              ClipRect(
                child: FractionalTranslation(
                  translation: Offset(scrollOffset, 0),
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.translate(
                      offset: Offset(shakeX, shakeY),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: <Widget>[
                          Text(
                            _bigSecondsLabel,
                            style: TextStyle(
                              color: digitColor,
                              fontSize: 720,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                              fontFamily: 'DSEG7Modern-Regular',
                              fontFamilyFallback: const <String>[
                                'DSEG7Modern-Bold',
                                'monospace',
                              ],
                            ),
                          ),
                          Text(
                            '.$_millisLabel$_microsLabel',
                            style: TextStyle(
                              color: digitColor,
                              fontSize: 300,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                              fontFamily: 'DSEG7Modern-Regular',
                              fontFamilyFallback: const <String>[
                                'DSEG7Modern-Bold',
                                'monospace',
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Transform.translate(
                offset: Offset(shakeX * 0.7, shakeY * 0.7),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(
                    _deltaText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _verdict == _Verdict.victory ? accent : white,
                      fontSize: 96,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'DSEG7Modern-Regular',
                      fontFamilyFallback: const <String>[
                        'DSEG7Modern-Bold',
                        'monospace',
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildEmoji(),
              const SizedBox(height: 8),
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
    ));
  }
}







