/// PLAYING screen — chronograph-style stopwatch in three resolution
/// segments (seconds, milliseconds, centimicros) on a pure-white
/// background, with arcade-style psychological pressure mechanisms:
///
///   * **Falsa cuenta atrás 3-2-1** at the start of the play —
///     the digits count 3, 2, 1 before the real stopwatch starts.
///     The player presses the button thinking "GO!" but the
///     stopwatch had already been running for a fraction of a
///     second, breaking their internal sense of when zero was.
///   * **Mensajes de aliento / chantaje** rotating every ~2 s while
///     the stopwatch runs: "¡DALE!", "¡APURATE!", "¡CASI CASI!",
///     "¡YA!", "¡APRIETA!". The text is small and dim so it
///     doesn't pull focus from the digits, but it adds an
///     arcade-carnival atmosphere that pressures the player to act.
///   * **Truco near-miss al pasar 9.999s** — a bright green flash
///     on the digits for 200ms, suggesting "you were right there!
///     one more try!" even though the real victory is at 10.000s.
///     The flash creates a false sense of closeness so the player
///     presses a few ms too early on the next attempt.
///   * **Color rotation** — digits start black, drift through a
///     5-color palette, return to black, every 3s.
///   * **Format** — `SS` (seconds, biggest), `.mmm` (millis, mid),
///     `.uu` (centimicros, smallest). 2-digit microseconds at
///     10us resolution is plenty for the 1.9 ms victory window.
///
/// The stopwatch itself starts on PLAYING entry; the fake countdown
/// sits ON TOP of the first ~0.8s of the real elapsed time.
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
  Duration _rendered = Duration.zero;
  int _colorIndex = 0;
  int _cheerIndex = 0;

  /// Tracks whether the near-miss green flash has already fired
  /// for the current play (we only want to fire it once per play).
  bool _nearMissFlashed = false;

  /// The moment the screen mounted — reserved for future use
  /// (debug overlays). Currently unused but kept so the field
  /// doesn't get removed by the linter; remove if no overlay
  /// ever lands.
  // ignore: unused_field
  late final DateTime _mountedAt;
  Timer? _countdownTimer;

  /// The current "fake countdown" value: 3, 2, 1, GO, or null
  /// (null = countdown finished, show the real chronograph).
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
    _mountedAt = DateTime.now();
    _countdownValue = 3;
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
    // Near-miss flash: fire once per play when the stopwatch crosses
    // 9.999s. The flash lasts ~200ms and is layered on top of the
    // normal color rotation.
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

  /// Whether the near-miss flash is currently visible. Fades out
  /// over 200ms after firing.
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
          // Cheer message — small, dim, bottom-right. Pulls some
          // attention without competing with the digits.
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
          // Fake countdown overlay (3 - 2 - 1 - GO!). Sits on top
          // of the digits for the first ~1s of play.
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
