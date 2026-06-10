/// PLAYING screen — chronograph-style stopwatch in three resolution
/// segments (seconds, milliseconds, centimicros) on a pure-white
/// background, with arcade-style psychological pressure mechanisms:
///
///   * **Fake 3-2-1-GO countdown** at the start of the play — the
///     overlay counts 3, 2, 1, GO! in 1s while the actual stopwatch
///     is hidden. When the GO! step finishes the real stopwatch
///     starts from 0 and a brief white pulse (80ms @ 0.5 alpha)
///     lights the screen. The player presses the button thinking
///     'GO!' is the start signal; by the time the flash settles
///     the real chronograph is already counting from 0, breaking
///     their internal anchor for when the timer 'really' began.
///   * **Mensajes de aliento / chantaje** rotating every ~2 s while
///     the stopwatch runs.
///   * **Truco near-miss al pasar 9.999s** — bright green flash
///     for 200ms suggesting 'you were right there!'.
///   * **Color rotation** — digits start black, drift through a
///     5-color palette, return to black, every 3s.
///   * **Format** — `SS` (880sp) / `.mmm` (420sp) / `.uu` (240sp).
///   * **Self-contained stopwatch** — the screen owns its own
///     [Stopwatch] instance so the countdown can run while the
///     visible chronograph is hidden, then start the real count
///     at the flash without any 'head start' that would skew
///     the player's timing. The [widget.controller] from the
///     parent AppRoot is only consulted for the 60s timeout
///     guard so the orchestration layer can still enforce
///     'no game longer than a minute'.
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

  /// The stopwatch that the visible chronograph reads. Owned by
  /// this widget (not the parent's controller) so we can start
  /// it exactly when the GO! flash ends, not when the screen
  /// mounts.
  final Stopwatch _visibleStopwatch = Stopwatch();

  /// Mirror of the visible stopwatch's elapsed time, updated by
  /// the per-frame ticker.
  Duration _rendered = Duration.zero;

  int _colorIndex = 0;
  int _cheerIndex = 0;
  bool _nearMissFlashed = false;
  int? _countdownValue;

  /// Drives the GO! flash. Filled 1.0 -> 0.0 over 80ms when the
  /// countdown finishes. Peak alpha 0.5 so the digits stay
  /// visible underneath.
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
      duration: const Duration(milliseconds: 80),
    );
    _goFlashAnim = CurvedAnimation(
      parent: _goFlashController,
      curve: Curves.easeOut,
    );

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
          // Trigger a short flash and start the VISIBLE stopwatch
          // from 0 — that's the one the player reads. The
          // parent's StopwatchController is the one the AppRoot
          // uses to enforce the 60s timeout, and that one is
          // already running because AppRoot called start() on
          // the WAITING -> PLAYING transition.
          _goFlashController.forward(from: 0.5);
          _visibleStopwatch
            ..reset()
            ..start();
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
    if (!_visibleStopwatch.isRunning) return;
    final Duration elapsed = _visibleStopwatch.elapsed;
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
    _visibleStopwatch.stop();
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
          // Main chronograph. Hidden during the fake countdown
          // (Opacity 0) so the player only sees the countdown
          // digit; the visible stopwatch is started at the
          // moment the countdown finishes, so the digits
          // appear already at 00.000.00 and start counting up.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
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
          ),
          // GO! flash overlay — a short white pulse (80ms) that
          // sells the GO! transition. Max alpha 0.5 so the player
          // can still see the digits starting at 00.000.00.
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
