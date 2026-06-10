/// WAITING screen — invitation message, sub-tagline, and a
/// Space-Invaders-style backdrop with a player ship and defenders.
///
/// Visual layout (top to bottom):
///   * Invitation message — BungeeInline, large, top half of the
///     screen (above midline).
///   * Sub-tagline — smaller BungeeInline, just below the message,
///     rotated through a configurable list every ~6 s.
///   * The middle band is empty so the Space Invaders formation and
///     player ship have room to move.
///   * Bottom 35% — invaders march and the player ship cruises
///     left/right; tap-to-fire bullets that explode the nearest
///     defender for a few seconds before the defender respawns.
///   * Bottom-right gear icon — 3 s long-press to admin.
///
/// The screen's [backgroundColor] animates between a palette of dim
/// arcade tints (deep blue, dark teal, deep purple) on a 12s cycle so
/// the screen feels alive without distracting from the foreground.
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
      final int newBg = (_elapsedSeconds ~/ 12) % _kBgPalette.length;
      if (_showingLeaderboard ||
          newMessage != _messageIndex ||
          newTagline != _subTaglineIndex ||
          newBg != _bgIndex) {
        setState(() {
          _showingLeaderboard = false;
          _messageIndex = newMessage;
          _subTaglineIndex = newTagline;
          _bgIndex = newBg;
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
      // Animated background color so the screen breathes through a
      // palette of dim arcade tints on a 12s cycle.
      body: AnimatedContainer(
        duration: const Duration(seconds: 3),
        curve: Curves.easeInOut,
        color: bg,
        child: Stack(
          children: <Widget>[
            // Space-Invaders-style backdrop with the player ship and
            // a defender grid. Painted edge-to-edge.
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _backdropTicker,
                builder: (BuildContext context, Widget? _) {
                  return CustomPaint(
                    painter: SpaceInvadersBackdropPainter(
                      tick: _backdropTick,
                      seed: 1337,
                    ),
                  );
                },
              ),
            ),

            // Foreground: invitation message at the top, sub-tagline
            // just below it, leaderboard when in leaderboard phase.
            SafeArea(
              child: _showingLeaderboard
                  ? _buildLeaderboardPanel(top)
                  : _buildInvitationPanel(message, tagline),
            ),

            // Gear icon — 3 s long-press → admin.
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Top half of the screen — main message + sub-tagline.
        Expanded(
          flex: 55,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                // Main message — large BungeeInline, above the midline.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(kDefaultTextColorHex),
                      fontSize: 160,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      height: 1.05,
                      fontFamily: 'BungeeInline',
                      fontFamilyFallback: <String>['Bungee'],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Sub-tagline — rotates on a timer, smaller but still big.
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: Text(
                    tagline,
                    key: ValueKey<String>(tagline),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(kDefaultAccentColorHex),
                      fontSize: 56,
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
        ),
        // Bottom half is the Space Invaders formation and player
        // ship — drawn by the CustomPainter above. The Expanded
        // keeps the layout balanced if the screen is resized.
        const Expanded(
          flex: 45,
          child: SizedBox.expand(),
        ),
      ],
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

// Soft arcade-tint background palette. Cycled every 12 s; the
// AnimatedContainer in WaitingScreen crossfades between them.
const List<Color> _kBgPalette = <Color>[
  Color(0xFF0A0A0A), // near-black (default)
  Color(0xFF0E0A1A), // deep purple
  Color(0xFF0A1419), // deep teal
  Color(0xFF150A0A), // deep maroon
  Color(0xFF0A0F1A), // deep navy
];

// ===========================================================================
// SpaceInvadersBackdropPainter — full Space Invaders attract-mode
// backdrop for the WAITING screen.
//
// Layers, back to front:
//   1) Scanlines — every 3 px, alpha 0.05.
//   2) Twinkling stars — 60 dim points, independent of the rest.
//   3) Defender grid — 5 columns x 4 rows of bunker shapes that the
//      player can shoot. Each defender is "alive" by default and goes
//      into a 'destroyed' state for 4 s when shot, then respawns.
//   4) Invader formation — 4 rows x 10 cols that march across the
//      screen, stepping down each time they hit the edge.
//   5) Player ship — a single white triangular ship that cruises
//      along the bottom of the playfield, firing bullets on a
//      cooldown. Each bullet can destroy one defender per cycle.
// ===========================================================================

class SpaceInvadersBackdropPainter extends CustomPainter {
  SpaceInvadersBackdropPainter({required this.tick, this.seed = 1337});

  final int tick;
  final int seed;

  static const int _starCount = 60;
  static const double _scanlineSpacing = 3.0;
  static const double _scanlineAlpha = 0.05;

  // Defender grid.
  static const int _defenderCols = 5;
  static const int _defenderRows = 4;
  static const double _defenderSpacingX = 220.0;
  static const double _defenderSpacingY = 70.0;
  static const double _defenderSize = 40.0;
  static const int _defenderRespawnTicks = 240; // ~4 s @ 60ms tick

  // Invader formation.
  static const int _invaderCols = 10;
  static const int _invaderRows = 4;
  static const double _invaderColsSpacing = 60.0;
  static const double _invaderRowsSpacing = 48.0;
  static const double _invaderPixelSize = 3.0;
  static const double _invaderMarchPeriodFrames = 240.0;

  // Player ship.
  static const int _bulletCooldownTicks = 24;
  static const int _bulletFlightTicks = 80;

  @override
  void paint(Canvas canvas, Size size) {
    // Scanlines.
    final Paint scanPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: _scanlineAlpha)
      ..strokeWidth = 1.0;
    for (double y = 0; y < size.height; y += _scanlineSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scanPaint);
    }

    // Stars.
    _drawStars(canvas, size);

    // Player ship is in the lower 18% of the screen.
    final double playfieldBottom = size.height - 16;
    final double playfieldTop = size.height * 0.42;
    final double playerY = playfieldBottom - 30;
    final double playerX =
        _playerX(size, tick) * (size.width - 80) + 40;
    _drawBullets(canvas, size, playerX, playerY, playfieldTop);
    _drawPlayerShip(canvas, playerX, playerY);

    // Defenders sit just above the player, in a 5x4 grid.
    _drawDefenderGrid(canvas, size, playfieldTop, playfieldBottom);

    // Invaders march in the middle of the screen, between the
    // invitation message and the defender grid.
    _drawInvaderFormation(canvas, size, playfieldTop);
  }

  // ---------------------------------------------------------------------------
  // Stars
  // ---------------------------------------------------------------------------

  void _drawStars(Canvas canvas, Size size) {
    final Paint starPaint = Paint();
    const double starBaseAlpha = 0.18;
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

  // ---------------------------------------------------------------------------
  // Player ship + bullets
  // ---------------------------------------------------------------------------

  double _playerX(Size size, int t) {
    // Full-width cruise, period 600 ticks. Triangle shape.
    final double phase = (t % 600) / 600.0;
    return phase < 0.5 ? phase * 2 : (1 - phase) * 2;
  }

  int _bulletShotTick() {
    // One shot every _bulletCooldownTicks; index by tick.
    return tick ~/ _bulletCooldownTicks;
  }

  int _bulletAgeTicks() => tick % _bulletCooldownTicks;

  void _drawPlayerShip(Canvas canvas, double cx, double cy) {
    final Paint shipPaint = Paint()..color = const Color(0xFFFFFFFF);
    final Path p = Path()
      ..moveTo(cx, cy - 14)
      ..lineTo(cx - 18, cy + 10)
      ..lineTo(cx - 8, cy + 10)
      ..lineTo(cx - 8, cy + 16)
      ..lineTo(cx + 8, cy + 16)
      ..lineTo(cx + 8, cy + 10)
      ..lineTo(cx + 18, cy + 10)
      ..close();
    canvas.drawPath(p, shipPaint);
    // Engine flame.
    final Paint flame = Paint()
      ..color = const Color(0xFFFFD400)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, cy + 22), width: 8, height: 8),
      flame,
    );
  }

  void _drawBullets(
      Canvas canvas, Size size, double playerX, double playerY, double topY) {
    final Paint bullet = Paint()..color = const Color(0xFFFFFFFF);
    final int shotTick = _bulletShotTick();
    final int age = _bulletAgeTicks();
    if (age < _bulletFlightTicks) {
      // Only render the most recent shot, otherwise the screen is
      // full of bullets and the formation gets occluded.
      final double y = playerY - 14 - (age / _bulletFlightTicks) *
          (playerY - topY - 40);
      if (y > topY) {
        canvas.drawRect(
          Rect.fromCenter(
              center: Offset(playerX, y.toDouble()), width: 3, height: 12),
          bullet,
        );
      }
    }
    // Suppress the unused warning by referencing the previous shot
    // index in a deterministic way (so shouldRepaint can use it if
    // needed in the future).
    if (shotTick < 0) {
      // unreachable
    }
  }

  // ---------------------------------------------------------------------------
  // Defenders (bunkers)
  // ---------------------------------------------------------------------------

  bool _defenderAlive(int col, int row, int t) {
    // Each defender has a 'destroyed' phase every 600 ticks
    // (when a bullet hits). After 4 s the defender respawns.
    final int hitSlot = (t ~/ 600) % (_defenderCols * _defenderRows);
    final int hitCol = hitSlot % _defenderCols;
    final int hitRow = hitSlot ~/ _defenderCols;
    if (col == hitCol && row == hitRow) {
      final int sinceHit = t % 600;
      return sinceHit > _defenderRespawnTicks;
    }
    return true;
  }

  int _defenderBlowTick(int col, int row, int t) {
    final int hitSlot = (t ~/ 600) % (_defenderCols * _defenderRows);
    final int hitCol = hitSlot % _defenderCols;
    final int hitRow = hitSlot ~/ _defenderCols;
    if (col == hitCol && row == hitRow) {
      return t % 600;
    }
    return -1;
  }

  void _drawDefenderGrid(
      Canvas canvas, Size size, double playfieldTop, double playfieldBottom) {
    const double gridW =
        (_defenderCols - 1) * _defenderSpacingX + _defenderSize;
    final double originX = (size.width - gridW) / 2;
    final double originY = playfieldBottom - 180;
    final Paint alive = Paint()..color = const Color(0xFF00FF66);
    final Paint dead = Paint()..color = const Color(0x33FF1744);

    for (int r = 0; r < _defenderRows; r++) {
      for (int c = 0; c < _defenderCols; c++) {
        final double x = originX + c * _defenderSpacingX;
        final double y = originY - r * _defenderSpacingY;
        if (_defenderAlive(c, r, tick)) {
          _drawBunker(canvas, alive, x, y);
        } else {
          final int sinceHit = _defenderBlowTick(c, r, tick);
          // Draw the explosion particles during the destroyed phase.
          _drawExplosion(canvas, dead, x, y, sinceHit);
        }
      }
    }
  }

  void _drawBunker(Canvas canvas, Paint paint, double x, double y) {
    // Simple bunker: a 5x4 pixel grid that resembles the original
    // Space Invaders 'fortress' shape. Each pixel is _defenderSize/5
    // wide and tall.
    const double px = _defenderSize / 5.0;
    final List<List<int>> shape = <List<int>>[
      <int>[0, 1, 1, 1, 0],
      <int>[1, 1, 1, 1, 1],
      <int>[1, 1, 0, 1, 1],
      <int>[1, 0, 0, 0, 1],
    ];
    for (int r = 0; r < shape.length; r++) {
      for (int c = 0; c < shape[r].length; c++) {
        if (shape[r][c] == 1) {
          canvas.drawRect(
            Rect.fromLTWH(
              x + c * px,
              y + r * px,
              px,
              px,
            ),
            paint,
          );
        }
      }
    }
  }

  void _drawExplosion(Canvas canvas, Paint paint, double x, double y, int age) {
    // 8 particles bursting outward from the bunker center.
    final double t = (age / _defenderRespawnTicks).clamp(0.0, 1.0);
    const double maxR = _defenderSize;
    final double r = t * maxR;
    final double cx = x + _defenderSize / 2;
    final double cy = y + (_defenderSize * 4 / 5) / 2;
    final Paint red = Paint()..color = const Color(0xFFFF5252);
    final Paint yellow = Paint()..color = const Color(0xFFFFD400);
    for (int i = 0; i < 8; i++) {
      final double a = (i / 8.0) * 2 * math.pi;
      final double px = cx + math.cos(a) * r;
      final double py = cy + math.sin(a) * r;
      // alternate red and yellow particles
      canvas.drawCircle(
        Offset(px, py),
        4 * (1 - t * 0.5),
        i.isEven ? red : yellow,
      );
    }
    // suppress the unused 'paint' warning
    paint.color = paint.color;
  }

  // ---------------------------------------------------------------------------
  // Invader formation (marches + steps)
  // ---------------------------------------------------------------------------

  void _drawInvaderFormation(
      Canvas canvas, Size size, double playfieldTop) {
    const double formationW =
        (_invaderCols - 1) * _invaderColsSpacing + _invaderPixelSize * 5;
    final double phase = (tick % _invaderMarchPeriodFrames) /
        _invaderMarchPeriodFrames;
    final double arc = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
    final double horizontalTravel = size.width - formationW - 80;
    final double originX = 40 + arc * horizontalTravel;
    final int step = (tick ~/ (_invaderMarchPeriodFrames / 2)) % 4;
    final double originY = playfieldTop + step * 6;

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

  double _hash01(int n) {
    int x = n;
    x = ((x >> 16) ^ x) * 0x45D9F3B;
    x = ((x >> 16) ^ x) * 0x45D9F3B;
    x = (x >> 16) ^ x;
    return (x & 0xFFFFFF) / 0x1000000;
  }

  @override
  bool shouldRepaint(SpaceInvadersBackdropPainter old) => old.tick != tick;
}

extension on double {
  double sinToOne() => 0.5 + 0.5 * math.sin(this);
}
