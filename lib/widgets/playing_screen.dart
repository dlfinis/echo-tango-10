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
  Timer? _cheerTimer;
  Timer? _countdownTimer;

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

  static const List<String> _cheerMessages = <String>[
    '¡DALE!',
    '¡APURATE!',
    '¡CASI CASI!',
    '¡YA!',
    '¡APRIETA!',
    '¡NO PIERDAS!',
    '¡TUS 10!',
  ];

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
            (_colorIndex + 1) % kPlayingColorPaletteHex.length;
      });
    });
    _cheerTimer = Timer.periodic(const Duration(milliseconds: 2000), (_) {
      if (!mounted) return;
      setState(() => _cheerIndex = (_cheerIndex + 1) % _cheerMessages.length);
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
    final Color baseColor = Color(kPlayingColorPaletteHex[_colorIndex]);
    final Color digitColor =
        _nearMissActive ? const Color(kDefaultAccentColorHex) : baseColor;
    final String cheer = _cheerMessages[_cheerIndex];

    return Scaffold(
      backgroundColor: const Color(kPlayingBackgroundColorHex),
      body: Stack(
        children: <Widget>[
          // Cheer message — small, dim, bottom-right.
          Positioned(
            right: 32,
            bottom: 32,
            child: IgnorePointer(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  cheer,
                  key: ValueKey<String>(cheer),
                  style: TextStyle(
                    color: baseColor.withValues(alpha: 0.35),
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    fontFamily: 'BungeeInline',
                    fontFamilyFallback: const <String>['Bungee'],
                  ),
                ),
              ),
            ),
          ),
          // Main chronograph — TWO text widgets in a simple Row
          // (no Transforms, no Paddings, no multi-font-size
          // wizardry). The FittedBox scales the whole Row to
          // fit the viewport. Hidden during countdown via Opacity.
          Padding(
            padding: const EdgeInsets.all(24),
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
                          fontSize: 900,
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
                        '.$_millis$_micros',
                        style: TextStyle(
                          color: digitColor,
                          fontSize: 400,
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
                            ? const Color(kDefaultAccentColorHex)
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
      ),
    );
  }
}
