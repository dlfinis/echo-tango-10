/// WAITING screen — invitation loop + small leaderboard panel.
///
/// The screen owns a `Timer.periodic` that rotates through:
///   1. Each message from `ConfigStore.invitationMessages`, shown for
///      `messageRotationSeconds` each.
///   2. The leaderboard top-5, shown for `leaderboardRotationSeconds`.
///
/// The intervals are re-read from the store on every tick so admin
/// changes apply live without restarting the loop.
///
/// Background: an [ArcadeBackdropPainter] draws scanlines + twinkling
/// stars in a dim palette to give the screen the 'CRT/Atari/Neo Geo'
/// atmosphere the operator wants. The mesh is repainted on a 60ms
/// timer so the stars feel alive without burning cycles.
///
/// The bottom-right gear icon accepts a 3 s long-press to open the
/// admin panel. On Web, Spacebar reaches the state machine through
/// the [KeyboardInputWidget] layer in `AppRoot` — not this screen.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/leaderboard_entry.dart';
import '../services/config_store.dart';
import '../services/leaderboard.dart';
import '../utils/constants.dart';

class WaitingScreen extends StatefulWidget {
  const WaitingScreen({
    super.key,
    required this.configStore,
    required this.leaderboard,
    this.onAdminGesture,
  });

  final ConfigStore configStore;
  final Leaderboard leaderboard;

  /// Forwarded by the parent (AppRoot) when the 3 s long-press fires.
  final VoidCallback? onAdminGesture;

  @override
  State<WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends State<WaitingScreen>
    with SingleTickerProviderStateMixin {
  /// Drives the rotation: -1 means "leaderboard view", otherwise the
  /// index into the message list.
  int _index = 0;

  /// Tracks whether we're in the leaderboard slot (true) or the message
  /// slot (false). When the message list is empty, the screen still
  /// shows the leaderboard on every tick.
  bool _showingLeaderboard = false;

  /// Seconds since the screen mounted — used to drive the rotation.
  int _elapsedSeconds = 0;

  Timer? _ticker;

  /// Tracks the 3 s long-press window for the admin gesture.
  Timer? _adminHoldTimer;

  /// Visual progress of the long-press (0.0..1.0). Re-renders the
  /// gear icon so the operator sees that the press is being detected
  /// and doesn't think the icon is broken.
  double _adminHoldProgress = 0.0;

  /// Frame ticker for the long-press progress (10 fps is plenty).
  Timer? _adminHoldTicker;

  /// Drives the arcade backdrop repaint. 16fps is enough to make the
  /// stars twinkle without burning cycles.
  int _backdropTick = 0;

  late final AnimationController _backdropTicker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds += 1;
      _onTick();
    });
    _backdropTicker = AnimationController(
      vsync: this,
      duration: const Duration(days: 365), // long enough to never end
    )..addListener(() {
        if (!mounted) return;
        setState(() => _backdropTick = (_backdropTick + 1) % 100000);
      });
    _backdropTicker.repeat(period: const Duration(milliseconds: 60));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _adminHoldTimer?.cancel();
    _adminHoldTicker?.cancel();
    _backdropTicker.dispose();
    super.dispose();
  }

  void _onTick() {
    if (!mounted) return;
    final int messageSec = widget.configStore.messageRotationSeconds();
    final int leaderboardSec = widget.configStore.leaderboardRotationSeconds();
    final List<String> messages = widget.configStore.invitationMessages();

    final int total = _totalCycleLength(
      messages: messages.length,
      messageSec: messageSec,
      leaderboardSec: leaderboardSec,
    );
    if (total <= 0) return; // misconfigured — do nothing
    final int phase = _elapsedSeconds % total;

    if (messages.isEmpty) {
      if (!_showingLeaderboard) {
        setState(() {
          _showingLeaderboard = true;
          _index = -1;
        });
      }
      return;
    }

    if (phase < messages.length * messageSec) {
      final int msgIndex = phase ~/ messageSec;
      if (_showingLeaderboard || _index != msgIndex) {
        setState(() {
          _showingLeaderboard = false;
          _index = msgIndex;
        });
      }
    } else {
      if (!_showingLeaderboard) {
        setState(() {
          _showingLeaderboard = true;
          _index = -1;
        });
      }
    }
  }

  int _totalCycleLength({
    required int messages,
    required int messageSec,
    required int leaderboardSec,
  }) {
    final int m = messages < 1 ? 0 : messages;
    return m * messageSec + leaderboardSec;
  }

  // ---------------------------------------------------------------------------
  // Admin long-press (3 s)
  // ---------------------------------------------------------------------------

  static const Duration _adminHoldTickInterval =
      Duration(milliseconds: 100);

  void _startAdminHold() {
    _adminHoldTimer?.cancel();
    _adminHoldTicker?.cancel();
    setState(() => _adminHoldProgress = 0.0);
    final DateTime startedAt = DateTime.now();
    _adminHoldTicker = Timer.periodic(_adminHoldTickInterval, (Timer t) {
      if (!mounted) return;
      final double elapsed =
          DateTime.now().difference(startedAt).inMilliseconds /
              kAdminLongPressDuration.inMilliseconds;
      setState(() => _adminHoldProgress = elapsed.clamp(0.0, 1.0));
    });
    _adminHoldTimer = Timer(kAdminLongPressDuration, () {
      _adminHoldTicker?.cancel();
      _adminHoldTicker = null;
      if (mounted) setState(() => _adminHoldProgress = 0.0);
      widget.onAdminGesture?.call();
    });
  }

  void _cancelAdminHold() {
    _adminHoldTimer?.cancel();
    _adminHoldTicker?.cancel();
    _adminHoldTimer = null;
    _adminHoldTicker = null;
    if (mounted) setState(() => _adminHoldProgress = 0.0);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final List<String> messages = widget.configStore.invitationMessages();
    final List<LeaderboardEntry> top = widget.leaderboard.top(5);

    return Scaffold(
      backgroundColor: const Color(kDefaultBgColorHex),
      body: Stack(
        children: <Widget>[
          // Animated arcade backdrop: scanlines + twinkling stars.
          // Repaints on a 60ms ticker driven by the _backdropTick
          // counter; full re-layout only when the message swaps.
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _backdropTicker,
              builder: (BuildContext context, Widget? _) {
                return CustomPaint(
                  painter: ArcadeBackdropPainter(
                    tick: _backdropTick,
                    seed: 1337,
                  ),
                );
              },
            ),
          ),
          // Center content — either the current message or the
          // leaderboard panel.
          SafeArea(
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: _showingLeaderboard
                    ? _buildLeaderboardPanel(top)
                    : _buildMessagePanel(messages),
              ),
            ),
          ),

          // Gear icon — bottom-right, 3 s long-press → admin.
          // Visually obvious: circular container with accent border,
          // a clear "config" tooltip, and a progress arc that fills
          // during the 3s hold so the operator knows the press is
          // being detected.
          Positioned(
            right: 24,
            bottom: 24,
            child: Tooltip(
              message: 'Mantener 3s para configurar',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPressStart: (_) => _startAdminHold(),
                onLongPressEnd: (_) => _cancelAdminHold(),
                onLongPressCancel: _cancelAdminHold,
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: _adminHoldProgress,
                          strokeWidth: 4,
                          backgroundColor: const Color(0xFF1E1E1E),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(kDefaultAccentColorHex),
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(kDefaultAccentColorHex),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.settings,
                          color: Color(kDefaultAccentColorHex),
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagePanel(List<String> messages) {
    final String text = messages.isEmpty
        ? '¡Presioná el botón para jugar!'
        : messages[_index.clamp(0, messages.length - 1)];
    return KeyedSubtree(
      key: const ValueKey<String>('message'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Text(
            text,
            key: ValueKey<String>(text),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(kDefaultTextColorHex),
              fontSize: 140,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              height: 1.05,
              fontFamily: 'BungeeInline',
              fontFamilyFallback: <String>['Bungee'],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardPanel(List<LeaderboardEntry> top) {
    return KeyedSubtree(
      key: const ValueKey<String>('leaderboard'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'ÚLTIMOS GANADORES',
                style: TextStyle(
                  color: Color(kDefaultAccentColorHex),
                  fontSize: 80,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  fontFamily: 'BungeeInline',
                  fontFamilyFallback: <String>['Bungee'],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (top.isEmpty)
              const FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'TODAVÍA NO HAY GANADORES. ¡SÉ EL PRIMERO!',
                  style: TextStyle(
                    color: Color(0xFFAAAAAA),
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    fontFamily: 'BungeeInline',
                    fontFamilyFallback: <String>['Bungee'],
                  ),
                ),
              )
            else
              ...top.asMap().entries.map((MapEntry<int, LeaderboardEntry> e) {
                final int rank = e.key + 1;
                final LeaderboardEntry entry = e.value;
                final String deltaStr = _formatSignedDelta(entry.delta);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        SizedBox(
                          width: 80,
                          child: Text(
                            '$rank.',
                            style: const TextStyle(
                              color: Color(0xFFAAAAAA),
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'BungeeInline',
                              fontFamilyFallback: <String>['Bungee'],
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 600,
                          child: Text(
                            entry.name,
                            style: const TextStyle(
                              color: Color(kDefaultTextColorHex),
                              fontSize: 56,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'BungeeInline',
                              fontFamilyFallback: <String>['Bungee'],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          deltaStr,
                          style: const TextStyle(
                            color: Color(kDefaultAccentColorHex),
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'DSEG7Modern-Regular',
                            fontFamilyFallback: <String>[
                              'DSEG7Modern-Bold',
                              'DSEG7Classic-Bold',
                            ],
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  String _formatSignedDelta(double delta) {
    final String sign = delta >= 0 ? '+' : '-';
    return '$sign${delta.abs().toStringAsFixed(3)}s';
  }
}

// ===========================================================================
// ArcadeBackdropPainter — CRT/Atari/Neo Geo look for the WAITING screen.
//
// Two layers, both intentionally low-contrast so they read as
// "atmosphere" and never compete with the foreground text or the
// leaderboard panel:
//
//   * Scanlines — thin horizontal lines every ~3 px, alpha 0.05.
//     The classical CRT effect.
//   * Stars — ~50 dim points at fixed positions (seeded so the layout
//     is deterministic across rebuilds). Each star has its own phase
//     and twinkle rate, derived from its index. The Painter is told
//     the current [tick] by the AnimatedBuilder so the twinkle reads
//     as continuous motion without a Controller of its own.
// ===========================================================================

class ArcadeBackdropPainter extends CustomPainter {
  ArcadeBackdropPainter({required this.tick, this.seed = 1337});

  /// Monotonically increasing frame counter from the parent ticker.
  final int tick;
  final int seed;

  static const int _starCount = 60;
  static const double _scanlineSpacing = 3.0;
  static const double _scanlineAlpha = 0.05;
  static const double _starBaseAlpha = 0.18;

  @override
  void paint(Canvas canvas, Size size) {
    // Fill the background with a near-black tint so the scanlines have
    // something to draw against; the Scaffold already paints
    // kDefaultBgColorHex but we want a uniform surface for the painter
    // to operate on independently of theme changes.
    final Paint bgPaint = Paint()..color = const Color(0xFF0A0A0A);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // 1) Scanlines.
    final Paint scanPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: _scanlineAlpha)
      ..strokeWidth = 1.0;
    for (double y = 0; y < size.height; y += _scanlineSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scanPaint);
    }

    // 2) Stars — seeded layout so the screen is deterministic.
    final Paint starPaint = Paint();
    for (int i = 0; i < _starCount; i++) {
      final double fx = _hash01(seed + i * 7919);
      final double fy = _hash01(seed + i * 7901 + 13);
      final double ph = _hash01(seed + i * 7793 + 31) * 6.28;
      final double rate = 0.04 + _hash01(seed + i * 7727 + 51) * 0.10;
      final double twinkle =
          0.5 + 0.5 * ((tick * rate) + ph).remainder(6.28).sinToOne();
      final double alpha = _starBaseAlpha * (0.3 + 0.7 * twinkle);
      starPaint.color = const Color(0xFF80DEEA).withValues(alpha: alpha);
      final Offset pos = Offset(fx * size.width, fy * size.height);
      final double r = 1.2 + twinkle * 1.4;
      canvas.drawCircle(pos, r, starPaint);
    }
  }

  /// Cheap deterministic hash returning a value in [0, 1).
  double _hash01(int n) {
    int x = n;
    x = ((x >> 16) ^ x) * 0x45D9F3B;
    x = ((x >> 16) ^ x) * 0x45D9F3B;
    x = (x >> 16) ^ x;
    return (x & 0xFFFFFF) / 0x1000000;
  }

  @override
  bool shouldRepaint(ArcadeBackdropPainter old) => old.tick != tick;
}

extension on double {
  /// Map a radians value to a 0..1 sine wave.
  double sinToOne() => 0.5 + 0.5 * math.sin(this);
}
