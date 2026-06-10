/// PLAYING screen — chronograph-style stopwatch in three resolution
/// segments (seconds, milliseconds, centimicros) on a pure-white
/// background, with arcade-style psychological pressure mechanisms:
///
///   * **Falsa cuenta atrás 3-2-1-GO!** at the start of the play —
///     the digits count 3, 2, 1, GO! in 1s while the real stopwatch
///     is already running underneath. The instant the GO! step
///     finishes the stopwatch is RESET to 0 and a bright white
///     "GO!" flash lights the whole screen for 200ms. The player
///     presses the button thinking "GO!" is the start, but by
///     the time the flash settles and the real chronograph is
///     visible the clock is already counting again from 0 — they
///     have no anchor for when the timer "really" started.
///   * **Mensajes de aliento / chantaje** rotating every ~2 s while
///     the stopwatch runs: "¡DALE!", "¡APURATE!", "¡CASI CASI!",
///     "¡YA!", "¡APRIETA!". The text is small and dim so it
///     doesn't pull focus from the digits.
///   * **Truco near-miss al pasar 9.999s** — a bright green flash
///     on the digits for 200ms, suggesting "you were right there!"
///     even though the real victory is at 10.000s.
///   * **Color rotation** — digits start black, drift through a
///     5-color palette, return to black, every 3s.
///   * **Format** — `SS` (seconds, biggest), `.mmm` (millis, mid),
///     `.uu` (centimicros, smallest). 2-digit microseconds at
///     10us resolution is plenty for the 1.9 ms victory window.
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

class _PlayingScreenState extends State<PlayingScreen>
    with TickerProviderStateMixin {
  Timer? _ticker;
  Timer? _timeoutGuard;
  Timer? _colorTimer;
  Timer? _cheerTimer;
  Timer? _countdownTimer;
  Duration _rendered = Duration.zero;
  int _colorIndex = 0;
  int _cheerIndex = 0;
  bool _nearMissFlashed = false;
  int? _countdownValue;

  /// Drives the GO! flash. Filled 1.0 -> 0.0 over 200ms when the
  /// countdown finishes. White screen at value 1.0 (full opacity).
  late final AnimationController _goFlashController;
  late final Animation<double> _goFlashAnim;

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
    _countdownValue = 3;
    _goFlashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _goFlashAnim = CurvedAnimation(
      parent: _goFlashController,
      curve: Curves.easeOut,
    );

    // The fake countdown: 3 (250ms) -> 2 (250ms) -> 1 (250ms) -> GO
    // (250ms) -> null. Total ~1.0s. The real stopwatch is already
    // running in the background.
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
          _countdownValue = 0; // "GO!"
        } else {
          _countdownValue = null;
          t.cancel();
          // Trigger the GO! flash and reset the stopwatch so the
          // real chronograph starts cleanly from 0.
          _goFlashController.forward(from: 1.0);
          widget.controller.reset();
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
    _goFlashController.dispose();
    super.dispose();
  }

  /// `SS` — integer second inside the current minute. "00".."59".
  String get _seconds =>
      _rendered.inSeconds.remainder(60).toString().padLeft(2, '0');

  /// `mmm` — milliseconds inside the current second. "000".."999".
  String get _millis {
    final int microInsideSecond =
        _rendered.inMicroseconds.remainder(1000000);
    return (microInsideSecond ~/ 1000).toString().padLeft(3, '0');
  }

  /// `uu` — 2-digit centimicros inside the current millisecond.
  String get _centimicros {
    final int microInsideSecond =
        _rendered.inMicroseconds.remainder(1000000);
    final int centimicros = (microInsideSecond % 1000) ~/ 10;
    return centimicros.toString().padLeft(2, '0');
  }

  /// Whether the near-miss flash is currently visible.
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
    final Color digitColor = _nearMissActive
        ? const Color(kDefaultAccentColorHex)
        : baseColor;
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
          // Main chronograph.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                      _seconds,
                      style: TextStyle(
                        color: digitColor,
                        fontSize: 880,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        letterSpacing: -28,
                        fontFamily: 'DSEG7Modern-Regular',
                        fontFamilyFallback: const <String>[
                          'DSEG7Modern-Bold',
                          'DSEG7Classic-Bold',
                          'monospace',
                        ],
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(0, 36),
                      child: Text(
                        '.$_millis',
                        style: TextStyle(
                          color: digitColor,
                          fontSize: 420,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          letterSpacing: -12,
                          fontFamily: 'DSEG7Modern-Regular',
                          fontFamilyFallback: const <String>[
                            'DSEG7Modern-Bold',
                            'DSEG7Classic-Bold',
                            'monospace',
                          ],
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(0, 64),
                      child: Text(
                        '.$_centimicros',
                        style: TextStyle(
                          color: digitColor,
                          fontSize: 240,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          letterSpacing: -6,
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
          ),
          // GO! flash overlay — a white screen that fades out
          // over 200ms when the fake countdown finishes. It sells
          // the GO! transition and also acts as a visual reset cue.
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _goFlashAnim,
              builder: (BuildContext context, Widget? _) {
                return Container(
                  color: const Color(0xFFFFFFFF)
                      .withValues(alpha: _goFlashAnim.value),
                );
              },
            ),
          ),
          // Fake countdown overlay (3 - 2 - 1 - GO!). Sits on top
          // of the flash and the digits.
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
