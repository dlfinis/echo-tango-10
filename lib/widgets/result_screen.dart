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

import '../theme/kiosk_theme.dart';
import '../theme/themes/classic_theme.dart';
import '../utils/constants.dart';
import 'crt_scanlines_painter.dart';

enum _Verdict { victory, casi, niPorAsomo, tePasaste }

class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.elapsedSeconds,
    required this.onNext,
    this.resultTimeoutSeconds = 5,
    this.victoryRangeStart = 9.9990,
    this.victoryRangeEnd = 10.0010,
    this.theme = const ClassicTheme(),
  });

  final double elapsedSeconds;
  final VoidCallback onNext;

  /// How many seconds the screen stays visible before
  /// auto-calling [onNext]. Configurable in the admin panel.
  final int resultTimeoutSeconds;

  /// Inclusive lower bound of the VICTORY window, in seconds.
  /// Defaults to [kDefaultVictoryRangeStart]; passed in by [AppRoot]
  /// from the live [ConfigStore] so the operator can tune the range
  /// from the admin panel without recompiling.
  final double victoryRangeStart;

  /// Inclusive upper bound of the VICTORY window, in seconds.
  /// Defaults to [kDefaultVictoryRangeEnd].
  final double victoryRangeEnd;

  /// Visual theme. Defaults to [ClassicTheme] so existing tests
  /// and call sites keep working without a theme argument.
  final KioskTheme theme;

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
  late final AnimationController _sceneController; // drives the penalty scene
  late final _Verdict _verdict;
  AnimationController? _spinController;
  AnimationController? _dropController;
  AnimationController? _teShakeController;
  AnimationController? _casiTrembleController; // CASI sweat-drop cycle (800ms repeat).

  /// Set to true on mount for the CASI branch. Gates the one-shot
  /// scale-in of the achieved-time "sign" widget next to the
  /// invader. The flag is read by [_buildEmoji] so the
  /// [TweenAnimationBuilder] only runs on the first frame.
  bool _casiSignAnimated = false;

  _Verdict _classifyVerdict(double elapsed) {
    if (elapsed < kFarShortThresholdSeconds) return _Verdict.niPorAsomo;
    if (elapsed > kFarOvershootThresholdSeconds) return _Verdict.tePasaste;
    if (elapsed >= widget.victoryRangeStart &&
        elapsed <= widget.victoryRangeEnd) {
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
      // 1s repeat (NOT reverse): the painter derives a 3 Hz bounce
      // and a 4 Hz rotation from the linear 0→1 t. A 4s
      // repeat-reverse would make those 0.75 Hz and 1 Hz — too
      // slow to read as motion.
      _spinController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 1),
      )..repeat();
    } else if (_verdict == _Verdict.casi) {
      // Flip the "sign animated" flag so [_buildEmoji] mounts the
      // TweenAnimationBuilder exactly once on the first frame.
      _casiSignAnimated = true;
      // Sweat drop cycle: 800ms repeat (no reverse). The painter
      // uses t to position a single pixel drop that falls from
      // above the invader's head to the bottom of the sprite,
      // fading out as it falls. Loops cleanly at 1.25 Hz.
      _casiTrembleController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800),
      )..repeat();
    } else if (_verdict == _Verdict.niPorAsomo) {
      _dropController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2500),
      )..repeat();
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

    // Scene controller: drives the result-screen penalty scene
    // (ball trajectory animation). 1.6s linear 0..1 once on
    // mount. The painter reads `t` to position the ball,
    // shake the net (victory), or fade it out (misses).
    _sceneController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();
  }

  @override
  void dispose() {
    _autoReturnTimer?.cancel();
    _glitchController.dispose();
    _shakeController.dispose();
    _scrollController.dispose();
    _sceneController.dispose();
    _spinController?.dispose();
    _dropController?.dispose();
    _teShakeController?.dispose();
    _casiTrembleController?.dispose();
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
    return widget.theme.verdictLabel(_toVerdictKind(_verdict));
  }

  /// Map the internal verdict to the public [VerdictKind] enum
  /// that the theme understands.
  VerdictKind _toVerdictKind(_Verdict v) {
    switch (v) {
      case _Verdict.victory:
        return VerdictKind.victoria;
      case _Verdict.casi:
        return VerdictKind.casi;
      case _Verdict.niPorAsomo:
        return VerdictKind.niPorAsomo;
      case _Verdict.tePasaste:
        return VerdictKind.tePasaste;
    }
  }

  /// Body / cavity colour pair fed to the painter. We use the
  /// per-verdict accent colour for the body and the screen
  /// background tint for the cavity so the eyes / mouth read as
  /// "carved out" of the sprite.
  List<Color> get _spriteColors {
    final Color body = _verdictColor;
    final Color cavity = _verdictBg;
    return <Color>[body, cavity];
  }

  /// Replaces the old emoji widget. The animation controllers
  /// (spin / drop / teShake) are still owned by the parent — they
  /// just feed `t` into the painter instead of driving a Transform.
  ///
  /// For the CASI branch the layout becomes a [Row] with TWO
  /// children: the invader (existing [CustomPaint]) and a
  /// "sign" widget showing the achieved time (e.g. "9.98s") with
  /// a one-shot scale-in. The other 3 verdicts keep the original
  /// single-invader layout (a [Flexible] + [FittedBox] wrap).
  ///
  /// The sprite is wrapped in [Flexible] + [FittedBox] so it
  /// shrinks to fit on the smallest kiosk viewport (800x480) but
  /// stays at the full 128x176 natural size on bigger screens.
  Widget _buildEmoji() {
    // 128 logical px tall sprite; the painter scales the 11x8 grid
    // to fit via pixelSize = 128/8 = 16. Width is 11*16 = 176.
    const double height = 128.0;
    const double pixelSize = height / 8.0;

    final Widget invader = Flexible(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: SizedBox(
          height: height,
          width: 11.0 * pixelSize,
          child: AnimatedBuilder(
            animation: Listenable.merge(<Listenable>[
              _spinController ?? const AlwaysStoppedAnimation<double>(0.0),
              _dropController ?? const AlwaysStoppedAnimation<double>(0.0),
              _teShakeController ?? const AlwaysStoppedAnimation<double>(0.0),
            ]),
            builder: (BuildContext context, Widget? _) {
              final double t;
              final List<Color> colors = _spriteColors;
              switch (_verdict) {
                case _Verdict.victory:
                  // Linear t — the bounce/rotation are sin waves so
                  // they read as constant motion; an easeInOut curve
                  // would make the speed non-uniform and feel stuttery.
                  t = _spinController!.value;
                  break;
                case _Verdict.casi:
                  // Sweat drop cycle: controller is 800ms repeat (no
                  // reverse), so t goes 0→1 in 800ms. The painter
                  // uses t to drive the drop's Y position and
                  // alpha — at t=0 the drop is above the head, at
                  // t=1 it has fallen and faded out.
                  t = _casiTrembleController?.value ?? 0.0;
                  break;
                case _Verdict.niPorAsomo:
                  // Linear 0..1..0..1 in 2.5s — the painter handles its
                  // own fall/rise curve internally.
                  t = _dropController!.value;
                  break;
                case _Verdict.tePasaste:
                  t = Curves.easeIn.transform(_teShakeController!.value);
                  break;
              }
              return CustomPaint(
                painter: widget.theme.resultSpritePainter(
                  verdict: _toVerdictKind(_verdict),
                  pixelSize: pixelSize,
                  t: t,
                  colors: colors,
                ),
              );
            },
          ),
        ),
      ),
    );

    if (_verdict != _Verdict.casi) {
      return invader;
    }

    // CASI: a Row of [invader | sign]. The sign scales in once on
    // mount via a TweenAnimationBuilder — the flag set in
    // initState ensures we only run the animation on the first
    // build. The sign shows the static arcade caption "¡POR UN
    // PELO!" in BungeeInline (no number, no tremble) and the
    // invader itself is what carries the motion (alpha flicker
    // inside the painter).
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        invader,
        const SizedBox(width: 16),
        if (_casiSignAnimated)
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                builder: (BuildContext context, double scale, Widget? child) {
                  return Transform.scale(
                    scale: scale,
                    child: child,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF000000),
                    border: Border.all(
                      color: widget.theme.accentColor,
                      width: 4,
                    ),
                  ),
                  child: Text(
                    widget.theme.casiCaption(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFFFFFFF),
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'BungeeInline',
                      fontFamilyFallback: <String>['Bungee'],
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Background color tinted by the verdict. The first ~50ms of
  /// mount animate the background IN from black via the implicit
  /// AnimatedContainer. The active [KioskTheme] owns the palette
  /// so different themes can pick different mood colours.
  Color get _verdictBg =>
      widget.theme.verdictBackground(_toVerdictKind(_verdict));

  Color get _verdictColor =>
      widget.theme.verdictColor(_toVerdictKind(_verdict));

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
              return LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final Size viewport = constraints.biggest;
                  final bool sceneIsVisible =
                      widget.theme.id != 'classic';
                  final double sceneW = viewport.width * 0.35;
                  final double sceneH = viewport.height * 0.40;
                  return Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      // Themed result scene — small inset in
                      // the UPPER-RIGHT corner. Drives the
                      // ball trajectory that matches the
                      // verdict.
                      if (sceneIsVisible)
                        Positioned(
                          top: 16,
                          right: 16,
                          width: sceneW,
                          height: sceneH,
                          child: IgnorePointer(
                            child: AnimatedBuilder(
                              animation: _sceneController,
                              builder: (BuildContext context, Widget? _) {
                                return CustomPaint(
                                  painter: widget.theme
                                      .resultScenePainter(
                                    verdict:
                                        _toVerdictKind(_verdict),
                                    t: _sceneController.value,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      _buildBody(
                        glitchT: _glitchAnim.value,
                        shakeT: _shakeAnim.value,
                        scrollT: _scrollAnim.value,
                      ),
                      // CRT scanlines overlay (worldcup only).
                      if (widget.theme.appliesCrtOverlay)
                        const Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: CrtScanlinesPainter(),
                            ),
                          ),
                        ),
                    ],
                  );
                },
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
    final Color accent = widget.theme.accentColor;
    final Color white = widget.theme.textColor;

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







