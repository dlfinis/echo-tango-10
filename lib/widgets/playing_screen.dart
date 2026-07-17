/// PLAYING screen — chronograph-style stopwatch in three resolution
/// segments (seconds, milliseconds, centimicros) on a pure-white
/// background, with optional arcade-style countdown.
///
/// Toggle [kShowCountdown] in `lib/utils/constants.dart` to
/// enable/disable the 3-2-1-GO! countdown overlay. Default is
/// `false` (chronograph visible immediately). When enabled, the
/// chronograph is hidden behind `Opacity 0` during the 1s countdown
/// and a short white pulse (80ms @ 0.5 alpha) flashes at the GO!
/// transition. The visible stopwatch is owned by this widget so the
/// countdown and the real count are independent.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../state/stopwatch_controller.dart';
import '../theme/kiosk_theme.dart';
import '../theme/themes/classic_theme.dart';
import '../utils/constants.dart';
import 'crt_scanlines_painter.dart';

class PlayingScreen extends StatefulWidget {
  const PlayingScreen({
    super.key,
    required this.controller,
    required this.onTimeout,
    this.theme = const ClassicTheme(),
  });

  final StopwatchController controller;
  final VoidCallback onTimeout;
  final KioskTheme theme;

  @override
  State<PlayingScreen> createState() => _PlayingScreenState();
}

class _PlayingScreenState extends State<PlayingScreen>
    with TickerProviderStateMixin {
  Timer? _ticker;
  Timer? _timeoutGuard;
  Timer? _colorTimer;
  Timer? _cheerTimer;
  Timer? _countdownTimer;
  late final AnimationController _sceneTicker;

  /// The stopwatch the visible chronograph reads. This is the
  /// parent's [StopwatchController] — the same one the [AppRoot]
  /// uses to read the elapsed time on the WAITING→PLAYING and
  /// PLAYING→RESULT transitions. We no longer own a private
  /// Stopwatch; the parent controller IS the source of truth.

  Duration _rendered = Duration.zero;
  int _colorIndex = 0;
  int _cheerIndex = 0;
  bool _nearMissFlashed = false;
  int? _countdownValue;

  /// Cheer / taunt messages shown below the chronograph. Two sets
  /// supplied by the active [KioskTheme]:
  ///   * [preparation] runs while the chronograph is still far from
  ///     10 (calm, encouraging).
  ///   * [urgency] runs once we cross [kCheerPhaseSwitchSeconds]
  ///     (push, press now).
  /// The split is deliberate: a "PREPARATE" while the player is at
  /// 9.7s would be confusing; an "APURATE" at 3.0s would be
  /// premature. Each theme picks its own list of phrases.
  List<String> get _preparationMessages => widget.theme.playingPreparationMessages;
  List<String> get _urgencyMessages => widget.theme.playingUrgencyMessages;

  @override
  void initState() {
    super.initState();
    // Default behaviour: chronograph visible immediately.
    // Set kShowCountdown to true to re-enable 3-2-1-GO!.
    _countdownValue = kShowCountdown ? 3 : null;
    // When the countdown is disabled, start the parent's
    // controller now so the AppRoot can read the elapsed
    // time on the PLAYING→RESULT transition.
    if (!kShowCountdown) {
      widget.controller.start();
    }

    // Scene ticker: 4-second loop. Drives the idle animation
    // of the penalty scene (ball wobble, goalkeeper sway).
    // The scene painter subscribes via its own repaint cycle
    // (see _sceneTicker below in the Stack) so this does not
    // trigger widget rebuilds.
    _sceneTicker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _countdownTimer = Timer.periodic(const Duration(milliseconds: 250), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_countdownValue == 3) {
          _countdownValue = 2;
        } else if (_countdownValue == 2) {
          _countdownValue = 1;
        } else if (_countdownValue == 1) {
          _countdownValue = 0;
        } else {
          _countdownValue = null;
          t.cancel();
          widget.controller.start();
        }
      });
    });

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
            (_colorIndex + 1) % widget.theme.playingColorPalette.length;
      });
    });
    _cheerTimer = Timer.periodic(const Duration(milliseconds: 2000), (_) {
      if (!mounted) return;
      // Cycle within the currently-active list. If the list
      // has 0 items (shouldn't happen — both have 5) we'd
      // hit modulo-by-zero, so guard explicitly.
      setState(() {
        final bool urgency =
            widget.controller.elapsed.inSeconds >= kCheerPhaseSwitchSeconds;
        final List<String> list =
            urgency ? _urgencyMessages : _preparationMessages;
        if (list.isEmpty) return;
        _cheerIndex = (_cheerIndex + 1) % list.length;
      });
    });
  }

  void _onTick() {
    if (!mounted) return;
    if (!widget.controller.isRunning) return;
    final Duration elapsed = widget.controller.elapsed;
    setState(() {
      _rendered = elapsed;
    });
    if (!_nearMissFlashed && elapsed >= const Duration(milliseconds: 9999)) {
      _nearMissFlashed = true;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _timeoutGuard?.cancel();
    _colorTimer?.cancel();
    _cheerTimer?.cancel();
    _countdownTimer?.cancel();
    _sceneTicker.dispose();
    super.dispose();
  }

  String get _seconds =>
      _rendered.inSeconds.remainder(60).toString().padLeft(2, '0');

  String get _millis {
    final int microInsideSecond =
        _rendered.inMicroseconds.remainder(1000000);
    return (microInsideSecond ~/ 1000).toString().padLeft(3, '0');
  }

  /// `u` — 1-digit (tenths of a centimicro) inside the current
  /// millisecond. 1 digit = 100µs resolution, 5x finer than the
  /// 1.9ms victory window. Maximizes horizontal space for the main
  /// digits.
  String get _micros {
    final int microInsideSecond =
        _rendered.inMicroseconds.remainder(1000000);
    final int decimicros = (microInsideSecond % 1000) ~/ 100;
    return decimicros.toString(); // 1 digit: 0..9
  }

  bool get _nearMissActive {
    if (!_nearMissFlashed) return false;
    final Duration sinceMiss =
        _rendered - const Duration(milliseconds: 9999);
    if (sinceMiss < Duration.zero) return false;
    return sinceMiss < const Duration(milliseconds: 200);
  }

  @override
  Widget build(BuildContext context) {
    final Color baseColor = widget.theme.playingColorPalette[_colorIndex];
    final Color digitColor =
        _nearMissActive ? widget.theme.accentColor : baseColor;
    // Pick the right list based on the visible elapsed time.
    // Clamp the index so a leftover index from the other list
    // can't cause an out-of-bounds crash.
    final bool urgency =
        _rendered.inSeconds >= kCheerPhaseSwitchSeconds;
    final List<String> activeList =
        urgency ? _urgencyMessages : _preparationMessages;
    final String cheer = activeList.isEmpty
        ? ''
        : activeList[_cheerIndex % activeList.length];

    return Scaffold(
      backgroundColor: widget.theme.playingBackgroundColor,
      // Full-screen goal backdrop (worldcup) or transparent
      // (classic). The painter handles the idle ball orbit +
      // goalkeeper animation via the scene ticker.
      body: Stack(
        children: <Widget>[
          // Goal backdrop — fills the entire screen. Behind
          // the chronograph.
          AnimatedBuilder(
            animation: _sceneTicker,
            builder: (BuildContext context, Widget? _) {
              return CustomPaint(
                painter: widget.theme.playingBackdropPainter(
                  t: _sceneTicker.value,
                ),
                size: Size.infinite,
              );
            },
          ),
          // Chronograph area — on top of the backdrop.
          Positioned.fill(
            child: _buildChronographArea(
              baseColor: baseColor,
              digitColor: digitColor,
              urgency: urgency,
              cheer: cheer,
            ),
          ),
          // CRT scanlines (worldcup only).
          if (widget.theme.appliesCrtOverlay)
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: CrtScanlinesPainter(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Builds the bottom-of-screen area: cheer message,
  /// chronograph, and countdown overlay. Extracted from the
  /// main `build` to keep the scene-vs-chronograph split
  /// readable.
  Widget _buildChronographArea({
    required Color baseColor,
    required Color digitColor,
    required bool urgency,
    required String cheer,
  }) {
    return Stack(
      children: <Widget>[
        // Cheer message — bigger and more visible than before
        // because the user said the dim 48sp version "didn't
        // have much sense". During the urgency phase the
        // color is the accent (green) so it really pops.
        Positioned(
          right: 25,
          top: 7,
          child: IgnorePointer(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: Text(
                cheer,
                key: ValueKey<String>(cheer),
                style: TextStyle(
                  color: urgency
                      ? widget.theme.accentColor
                      : baseColor.withValues(alpha: 0.55),
                  fontSize: 59,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  fontFamily: 'BungeeInline',
                  fontFamilyFallback: const <String>['Bungee'],
                ),
              ),
            ),
          ),
        ),
        // Main chronograph — shifted up via Transform.translate
        // so the cheer message fits below without constraining
        // the chronograph's size.
        Transform.translate(
          offset: const Offset(-15, -10),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Opacity(
                opacity: _countdownValue == null ? 1.0 : 0.0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    Text(
                        _seconds,
                        style: TextStyle(
                          color: digitColor,
                          fontSize: 1800,
                          fontWeight: FontWeight.w900,
                          height: 1.5,
                          fontFamily: 'DSEG7Modern-Regular',
                          fontFamilyFallback: const <String>[
                            'DSEG7Modern-Bold',
                            'monospace',
                          ],
                          shadows: const <Shadow>[
                            Shadow(
                              color: Color(0x660E1A4A),
                              blurRadius: 8,
                              offset: Offset(10, 10),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '.$_millis',
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
                          shadows: const <Shadow>[
                            Shadow(
                              color: Color(0x660E1A4A),
                              blurRadius: 8,
                              offset: Offset(10, 10),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _micros,
                        style: TextStyle(
                          color: digitColor.withValues(alpha: 0.6),
                          fontSize: 360,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          fontFamily: 'DSEG7Modern-Regular',
                          fontFamilyFallback: const <String>[
                            'DSEG7Modern-Bold',
                            'monospace',
                          ],
                          shadows: const <Shadow>[
                            Shadow(
                              color: Color(0x660E1A4A),
                              blurRadius: 8,
                              offset: Offset(10, 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // (Flash overlay removed in iteration #22 — it was
          // causing a visible white flash on entry. The
          // countdown already provides enough visual
          // transition when kShowCountdown is true.)
          // Fake countdown overlay. Only shown if kShowCountdown is
          // true AND the countdown is still running.
          if (_countdownValue != null)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _countdownValue == 0 ? '¡GO!' : '$_countdownValue',
                      key: ValueKey<int?>(_countdownValue),
                      style: TextStyle(
                        color: _countdownValue == 0
                            ? widget.theme.accentColor
                            : digitColor,
                        fontSize: 480,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'BungeeInline',
                        fontFamilyFallback: const <String>['Bungee'],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
  }
}
