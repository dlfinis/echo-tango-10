/// WAITING screen — invitation message, sub-tagline, and a full-screen
/// Space Invaders march where the invaders sweep the entire viewport
/// (top to bottom) and trigger a soft background-color shift each time
/// they touch the bottom edge.
///
/// Layout (top to bottom):
///   * Top half: invitation message in huge BungeeInline (240sp) +
///     a sub-tagline underneath in the accent color (110sp).
///     The sub-tagline rotates every ~6 s through the list read from
///     [ConfigStore.subTaglines] (defaulted to arcade call-to-action
///     taglines).
///   * Bottom half: 4-row x 10-col invader formation that marches
///     left/right and steps down a full row every time it hits the
///     edge. The full formation spans the entire viewport so the
///     players feel the invaders 'invading' the screen, not just
///     decorating the lower half.
///   * Each time the formation reaches the bottom edge of the
///     playfield, the Scaffold's [AnimatedContainer] color animates
///     to the next entry in [_kBgPalette] — a soft 3s crossfade
///     between dim arcade tints (deep purple, teal, maroon, navy,
///     near-black) so the background breathes with the march.
///
/// Long-pressing the gear icon for 3s opens the admin panel.
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
  final VoidCallback? onAdminGesture;

  @override
  State<WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends State<WaitingScreen>
    with TickerProviderStateMixin {
  int _messageIndex = 0;
  int _subTaglineIndex = 0;
  bool _showingLeaderboard = false;
  int _elapsedSeconds = 0;
  Timer? _ticker;
  Timer? _adminHoldTimer;
  Timer? _adminHoldTicker;
  double _adminHoldProgress = 0.0;
  int _backdropTick = 0;
  int _bgIndex = 0;
  late final AnimationController _backdropTicker;

  static const Duration _adminHoldTickInterval =
      Duration(milliseconds: 100);

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds += 1;
      _onTick();
    });
    _backdropTicker = AnimationController(
      vsync: this,
      duration: const Duration(days: 365),
    )..addListener(() {
        if (!mounted) return;
        setState(() => _backdropTick = (_backdropTick + 1) % 100000);
      });
    _backdropTicker.repeat(period: const Duration(milliseconds: 50));
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
    final int subTaglineSec = widget.configStore.subTaglineRotationSeconds();
    final int leaderboardSec = widget.configStore.leaderboardRotationSeconds();
    final List<String> messages = widget.configStore.invitationMessages();
    final List<String> taglines = widget.configStore.subTaglines();

    if (messages.isEmpty) {
      if (!_showingLeaderboard) {
        setState(() {
          _showingLeaderboard = true;
        });
      }
      return;
    }

    final int messageTotal = messages.length * messageSec;
    final int total = messageTotal + leaderboardSec;
    if (total <= 0) return;
    final int phase = _elapsedSeconds % total;

    if (phase < messageTotal) {
      final int newMessage = phase ~/ messageSec;
      final int newTagline =
          (_elapsedSeconds ~/ subTaglineSec) % math.max(taglines.length, 1);
      if (_showingLeaderboard ||
          newMessage != _messageIndex ||
          newTagline != _subTaglineIndex) {
        setState(() {
          _showingLeaderboard = false;
          _messageIndex = newMessage;
          _subTaglineIndex = newTagline;
        });
      }
    } else {
      if (!_showingLeaderboard) {
        setState(() {
          _showingLeaderboard = true;
        });
      }
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final List<String> messages = widget.configStore.invitationMessages();
    final List<String> taglines = widget.configStore.subTaglines();
    final List<LeaderboardEntry> top = widget.leaderboard.top(5);

    final String message = messages.isEmpty
        ? '¡Presioná el botón para jugar!'
        : messages[_messageIndex.clamp(0, messages.length - 1)];
    final String tagline = taglines.isEmpty
        ? ''
        : taglines[_subTaglineIndex.clamp(0, taglines.length - 1)];
    final Color bg = _kBgPalette[_bgIndex];

    return Scaffold(
      // The AnimatedContainer color is the result of the invader
      // formation touching the bottom edge — see the painter.
      body: AnimatedContainer(
        duration: const Duration(seconds: 3),
        curve: Curves.easeInOut,
        color: bg,
        child: Stack(
          children: <Widget>[
            // Full-screen Space Invaders march. The painter takes care
            // of advancing its own internal state and updating the
            // background palette when the formation lands.
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _backdropTicker,
                builder: (BuildContext context, Widget? _) {
                  return CustomPaint(
                    painter: InvaderMarchPainter(
                      tick: _backdropTick,
                      seed: 1337,
                      onFormationLanded: (int newBg) {
                        if (!mounted) return;
                        if (newBg != _bgIndex) {
                          setState(() => _bgIndex = newBg);
                        }
                      },
                    ),
                  );
                },
              ),
            ),
            // Foreground: invitation message + sub-tagline on top,
            // leaderboard when in leaderboard phase.
            SafeArea(
              child: _showingLeaderboard
                  ? _buildLeaderboardPanel(top)
                  : _buildInvitationPanel(message, tagline),
            ),
            // Gear icon — 3s long-press → admin.
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
      ),
    );
  }

  Widget _buildInvitationPanel(String message, String tagline) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Main message — centered vertically and horizontally.
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(kDefaultTextColorHex),
                fontSize: 240,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                height: 1.0,
                fontFamily: 'BungeeInline',
                fontFamilyFallback: <String>['Bungee'],
              ),
            ),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                tagline,
                key: ValueKey<String>(tagline),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(kDefaultAccentColorHex),
                  fontSize: 110,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  fontFamily: 'BungeeInline',
                  fontFamilyFallback: <String>['Bungee'],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardPanel(List<LeaderboardEntry> top) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
    );
  }

  String _formatSignedDelta(double delta) {
    final String sign = delta >= 0 ? '+' : '-';
    return '$sign${delta.abs().toStringAsFixed(3)}s';
  }
}

// Background palette: dim arcade tints, cycled every time the
// invader formation lands on the bottom edge.
const List<Color> _kBgPalette = <Color>[
  Color(0xFF0A0A0A), // near-black
  Color(0xFF0E0A1A), // deep purple
  Color(0xFF0A1419), // deep teal
  Color(0xFF150A0A), // deep maroon
  Color(0xFF0A0F1A), // deep navy
];

// ===========================================================================
// InvaderMarchPainter — full-screen Space Invaders march that sweeps
// the entire viewport and triggers a soft background-color shift each
// time the formation touches the bottom edge.
//
// The formation is 4 rows x 10 cols. Each row is a different colored
// invader (green / cyan / magenta / amber). The formation marches
// left/right across the screen, stepping down by one row each time it
// hits an edge. After enough steps the formation has descended through
// the whole playfield and the bottom row reaches the bottom of the
// screen — at that point the painter fires [onFormationLanded] with
// the next palette index and the screen's AnimatedContainer
// crossfades to the new background color.
//
// The painter is the only place that knows the march state — the
// parent widget just supplies a monotonically increasing [tick] and
// gets a callback when a 'landing' event happens. No timers, no
// AnimationController, no extra state in the parent.
// ===========================================================================

class InvaderMarchPainter extends CustomPainter {
  InvaderMarchPainter({
    required this.tick,
    required this.seed,
    required this.onFormationLanded,
  });

  final int tick;
  final int seed;
  final void Function(int newBgIndex) onFormationLanded;

  static const int _invaderCols = 10;
  static const int _invaderRows = 4;
  // March + step animation tuned so one full screen traversal takes
  // ~10 seconds. The formation steps down every half-period, and the
  // bottom row reaches the bottom of the screen after
  // _stepDownsPerTraversal steps.
  static const double _invaderColsSpacing = 70.0;
  static const double _invaderRowsSpacing = 58.0;
  static const double _invaderPixelSize = 3.0;
  static const double _invaderMarchPeriodFrames = 220.0;

  // The formation has to step down _rowsPerTraversal * (rows-1) times
  // The formation descends _stepsBetweenHalfMarches rows every
  // half-march. With 4 rows and 1 step per half-march, the bottom
  // row reaches the bottom of the playfield in a few seconds of
  // march + descent time. After that the formation respawns at the
  // top (we use modulo arithmetic against the playfield height).
  static const int _stepsBetweenHalfMarches = 1;

  // Stars + scanlines — CRT backdrop behind the invaders.
  static const int _starCount = 60;
  static const double _scanlineSpacing = 3.0;
  static const double _scanlineAlpha = 0.05;

  int? _lastLandingTick;

  @override
  void paint(Canvas canvas, Size size) {
    // 1) Scanlines — CRT backdrop.
    final Paint scanPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: _scanlineAlpha)
      ..strokeWidth = 1.0;
    for (double y = 0; y < size.height; y += _scanlineSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scanPaint);
    }

    // 2) Twinkling stars — sit behind the invaders.
    _drawStars(canvas, size);

    // 3) Invader formation — sweeps the entire viewport.
    const double formationW =
        (_invaderCols - 1) * _invaderColsSpacing + _invaderPixelSize * 5;
    final double phase = (tick % _invaderMarchPeriodFrames) /
        _invaderMarchPeriodFrames;
    final double arc = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
    final double horizontalTravel = size.width - formationW - 80;
    final double originX = 40 + arc * horizontalTravel;

    // Number of half-marches (each edge bounce = 1 half-march).
    final int halfMarches = (tick ~/ (_invaderMarchPeriodFrames / 2)) % 100000;
    // The formation descends _stepsBetweenHalfMarches rows every
    // half-march. After enough half-marches the bottom row reaches
    // the bottom of the playfield. The formation then 'respawns' by
    // jumping the row offset back to 0 (we use modulo against the
    // height of the playfield, measured in row-spacings).
    final int playfieldHeightRows = (size.height / _invaderRowsSpacing).floor();
    final int totalRowOffset = halfMarches * _stepsBetweenHalfMarches;
    // Modulo so the formation keeps cycling: 0 -> playfieldHeightRows-1.
    final int visibleRowOffset =
        totalRowOffset % (playfieldHeightRows + _invaderRows);
    final double descentOriginY =
        (size.height * 0.05) + visibleRowOffset * _invaderRowsSpacing;
    // The formation has reached the bottom when the bottom row's
    // Y exceeds the screen height minus one row spacing.
    final double bottomRowY = descentOriginY +
        (_invaderRows - 1) * _invaderRowsSpacing;
    final bool landed = bottomRowY > size.height - 80;
    if (landed && _lastLandingTick != tick) {
      _lastLandingTick = tick;
      final int newBg =
          ((tick ~/ (_invaderMarchPeriodFrames * 4)) % _kBgPalette.length);
      onFormationLanded(newBg);
    }

    final double originY = landed
        ? size.height - 80 - (_invaderRows - 1) * _invaderRowsSpacing
        : descentOriginY;

    // Per-row color and shape (different invader types per row).
    const List<Color> rowColors = <Color>[
      Color(0xFF00FF66), // green
      Color(0xFF00E5FF), // cyan
      Color(0xFFFF4DD2), // magenta
      Color(0xFFFFD400), // amber
    ];
    const List<List<List<int>>> rowShapes = <List<List<int>>>[
      <List<int>>[
        <int>[0, 1, 0, 1, 0],
        <int>[0, 0, 1, 0, 0],
        <int>[0, 1, 1, 1, 0],
        <int>[1, 0, 1, 0, 1],
        <int>[1, 0, 0, 0, 1],
      ],
      <List<int>>[
        <int>[0, 0, 1, 0, 0],
        <int>[0, 1, 1, 1, 0],
        <int>[1, 1, 1, 1, 1],
        <int>[0, 1, 0, 1, 0],
        <int>[1, 0, 0, 0, 1],
      ],
      <List<int>>[
        <int>[0, 0, 1, 0, 0],
        <int>[0, 1, 1, 1, 0],
        <int>[1, 1, 1, 1, 1],
        <int>[1, 0, 1, 0, 1],
        <int>[1, 0, 0, 0, 1],
      ],
      <List<int>>[
        <int>[0, 1, 1, 1, 0],
        <int>[1, 1, 1, 1, 1],
        <int>[0, 1, 0, 1, 0],
      ],
    ];

    final int legFrame = (tick ~/ 6) % 2;
    final Paint pixel = Paint();
    for (int r = 0; r < _invaderRows; r++) {
      pixel.color = rowColors[r];
      final List<List<int>> shape = rowShapes[r];
      final double yBase = originY + r * _invaderRowsSpacing;
      for (int c = 0; c < _invaderCols; c++) {
        final double xBase = originX + c * _invaderColsSpacing;
        _drawSprite(canvas, pixel, xBase, yBase, shape, legFrame);
      }
    }
  }

  void _drawSprite(Canvas canvas, Paint paint, double xBase, double yBase,
      List<List<int>> shape, int legFrame) {
    final int rows = shape.length;
    final int cols = shape[0].length;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        bool lit = shape[r][c] != 0;
        if (r == rows - 1) {
          lit = legFrame == 0 ? (c % 2 == 0) : (c % 2 == 1);
        }
        if (!lit) continue;
        final Rect rect = Rect.fromLTWH(
          xBase + c * _invaderPixelSize,
          yBase + r * _invaderPixelSize,
          _invaderPixelSize - 0.5,
          _invaderPixelSize - 0.5,
        );
        canvas.drawRect(rect, paint);
      }
    }
  }

  void _drawStars(Canvas canvas, Size size) {
    const double starBaseAlpha = 0.20;
    final Paint starPaint = Paint();
    for (int i = 0; i < _starCount; i++) {
      final double fx = _hash01(seed + i * 7919);
      final double fy = _hash01(seed + i * 7901 + 13);
      final double ph = _hash01(seed + i * 7793 + 31) * 6.28;
      final double rate = 0.04 + _hash01(seed + i * 7727 + 51) * 0.10;
      final double twinkle =
          0.5 + 0.5 * ((tick * rate) + ph).remainder(6.28).sinToOne();
      final double alpha = starBaseAlpha * (0.3 + 0.7 * twinkle);
      starPaint.color = const Color(0xFF80DEEA).withValues(alpha: alpha);
      final Offset pos = Offset(fx * size.width, fy * size.height);
      final double r = 1.2 + twinkle * 1.4;
      canvas.drawCircle(pos, r, starPaint);
    }
  }

  double _hash01(int n) {
    int x = n;
    x = ((x >> 16) ^ x) * 0x45D9F3B;
    x = ((x >> 16) ^ x) * 0x45D9F3B;
    x = (x >> 16) ^ x;
    return (x & 0xFFFFFF) / 0x1000000;
  }

  @override
  bool shouldRepaint(InvaderMarchPainter old) => old.tick != tick;
}

extension on double {
  /// Map a radians value to a 0..1 sine wave.
  double sinToOne() => 0.5 + 0.5 * math.sin(this);
}
