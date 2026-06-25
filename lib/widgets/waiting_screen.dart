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
import '../theme/kiosk_theme.dart';
import '../theme/themes/classic_theme.dart';
import '../utils/constants.dart';

class WaitingScreen extends StatefulWidget {
  const WaitingScreen({
    super.key,
    required this.configStore,
    required this.leaderboard,
    this.onAdminGesture,
    this.theme = const ClassicTheme(),
  });

  final ConfigStore configStore;
  final Leaderboard leaderboard;
  final VoidCallback? onAdminGesture;
  final KioskTheme theme;

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
    // The backdrop ticker is a single AnimationController whose
    // ONLY purpose is to act as a [Listenable] for the invader-march
    // painter. Its 10s cycle repeats forever; the painter
    // derives its own monotonic tick from `lastElapsedDuration`,
    // and `CustomPaint` re-paints whenever the controller ticks
    // WITHOUT scheduling a widget rebuild. This replaces the
    // previous 20 Hz setState that rebuilt the whole Waiting
    // tree on every frame and produced the user-visible freeze.
    _backdropTicker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    _backdropTicker.repeat();
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
    // Copy precedence: operator override (if any) wins, otherwise
    // the active theme's defaults. This lets a theme ship with its
    // own copy without losing the operator's ability to customise.
    final List<String> messages =
        widget.configStore.invitationMessagesOrNull() ??
            widget.theme.invitationMessages;
    final List<String> taglines =
        widget.configStore.subTaglinesOrNull() ?? widget.theme.subTaglines;

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
    final List<String> messages =
        widget.configStore.invitationMessagesOrNull() ??
            widget.theme.invitationMessages;
    final List<String> taglines =
        widget.configStore.subTaglinesOrNull() ?? widget.theme.subTaglines;
    final List<LeaderboardEntry> top = widget.leaderboard.top(5);

    final String message = messages.isEmpty
        ? '¡Presioná el botón para jugar!'
        : messages[_messageIndex.clamp(0, messages.length - 1)];
    final String tagline = taglines.isEmpty
        ? ''
        : taglines[_subTaglineIndex.clamp(0, taglines.length - 1)];

    return Scaffold(
      // The painter draws the background color as its first layer
      // (it animates between palette entries internally as the
      // formation lands). This avoids any setState cross-talk
      // between the painter and the parent widget.
      backgroundColor: widget.theme.waitingScaffoldColor,
      body: Stack(
        children: <Widget>[
          // Full-screen themed march. The theme owns the painter
          // (Space Invaders for the classic theme, footballs for
          // worldcup). The painter draws everything (background +
          // formation + scanlines + stars) and re-paints on every
          // tick of the backdrop controller — CustomPaint
          // subscribes to the painter's `listenable` and triggers
          // a paint WITHOUT rebuilding this widget. This is the
          // fix for the 20 Hz setState freeze.
          Positioned.fill(
            child: CustomPaint(
              painter: widget.theme.backgroundMarchPainter(
                listenable: _backdropTicker,
              ),
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
                            valueColor: AlwaysStoppedAnimation<Color>(
                              widget.theme.accentColor,
                            ),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: widget.theme.accentColor,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.settings,
                            color: widget.theme.accentColor,
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

  Widget _buildInvitationPanel(String message, String tagline) {
    // SizedBox.expand + FittedBox(BoxFit.contain) makes the text
    // GROW to fill the available space (down to the larger of
    // width and height) and only shrink if the content would
    // overflow. Base fontSize is intentionally larger than the
    // screen can fit so the FittedBox always shrinks the text
    // down to fill — but the natural size keeps growing on
    // bigger screens.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // Main message — neon glow + drop shadow for kiosk
              // impact. The glow pulses gently via a tweened
              // opacity in the shadow layers. Bigger font and
              // tighter letter spacing for BungeeInline readability.
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.6, end: 1.0),
                duration: const Duration(milliseconds: 1800),
                curve: Curves.easeInOut,
                builder: (BuildContext context, double pulse, Widget? _) {
                  return Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: widget.theme.textColor,
                      fontSize: 900,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                      height: 0.95,
                      fontFamily: 'BungeeInline',
                      fontFamilyFallback: <String>['Bungee'],
                      shadows: <Shadow>[
                        // Outer neon glow — accent colour.
                        Shadow(
                          color: widget.theme.accentColor
                              .withValues(alpha: 0.65 * pulse),
                          blurRadius: 30,
                        ),
                        // Mid glow.
                        Shadow(
                          color: widget.theme.accentColor
                              .withValues(alpha: 0.35 * pulse),
                          blurRadius: 15,
                        ),
                        // Tight white inner glow.
                        Shadow(
                          color: const Color(0xFFFFFFFF)
                              .withValues(alpha: 0.70 * pulse),
                          blurRadius: 6,
                        ),
                        // Hard drop shadow for depth.
                        const Shadow(
                          color: Color(0xCC000000),
                          blurRadius: 0,
                          offset: Offset(6, 6),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Text(
                  tagline,
                  key: ValueKey<String>(tagline),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: widget.theme.accentColor,
                    fontSize: 700,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 5,
                    fontFamily: 'BungeeInline',
                    fontFamilyFallback: <String>['Bungee'],
                    shadows: const <Shadow>[
                      Shadow(
                        color: Color(0x99000000),
                        blurRadius: 0,
                        offset: Offset(4, 4),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardPanel(List<LeaderboardEntry> top) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
      // LayoutBuilder gives us the actual viewport constraints.
      // We force the inner Column to fill the FULL viewport height
      // (with IntrinsicHeight) so the panel doesn't collapse to
      // its content's natural height when the leaderboard is
      // empty (single "TODAVÍA NO HAY GANADORES" line). With a
      // single short line, the column otherwise renders at maybe
      // 100px and leaves the rest of the screen black.
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'ÚLTIMOS GANADORES',
                style: TextStyle(
                  color: widget.theme.accentColor,
                  fontSize: 120,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  fontFamily: 'BungeeInline',
                  fontFamilyFallback: <String>['Bungee'],
                  shadows: const <Shadow>[
                    Shadow(
                      color: Color(0xAA000000),
                      blurRadius: 0,
                      offset: Offset(4, 4),
                    ),
                    Shadow(
                      color: Color(0x4400FF00),
                      blurRadius: 16,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (top.isEmpty)
              // The 5-row panel is ~100 px per row on the kiosk
              // target (Padding 6+6 + ~88 px of FittedBox text at
              // its scaled-down size). Pin the empty state to
              // 5 * 100 = 500 logical px and center the message
              // inside that box so the panel does not visually
              // shrink when the leaderboard is empty.
              const SizedBox(
                height: 5 * 100.0,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: Text(
                      'TODAVÍA NO HAY GANADORES. ¡SÉ EL PRIMERO!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFAAAAAA),
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        fontFamily: 'BungeeInline',
                        fontFamilyFallback: <String>['Bungee'],
                      ),
                    ),
                  ),
                ),
              )
            else
              ...top.asMap().entries.map((MapEntry<int, LeaderboardEntry> e) {
                final int rank = e.key + 1;
                final LeaderboardEntry entry = e.value;
                final String rawStr = entry.rawSeconds.toStringAsFixed(4);
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
                            style: TextStyle(
                              color: widget.theme.textColor,
                              fontSize: 56,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'BungeeInline',
                              fontFamilyFallback: <String>['Bungee'],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          rawStr,
                          style: TextStyle(
                            color: widget.theme.accentColor,
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
      ),
    );
  },
      ),
    );
  }
}



// ===========================================================================
// InvaderMarchPainter — full-screen Space Invaders march that draws
// EVERYTHING (background + scanlines + stars + invaders) and
// internally animates the background color when the formation
// lands. Zero painter -> widget communication: the painter is a
// pure render function, the parent just supplies a [Listenable] and
// never has to rebuild for color changes because the painter
// animates them itself.
//
// The painter is the only place that knows the march state. The
// tick is derived inside paint() from the listenable's elapsed
// duration, so the widget tree never rebuilds while the march runs.
// ===========================================================================

class InvaderMarchPainter extends CustomPainter {
  InvaderMarchPainter({
    required this.seed,
    Listenable? listenable,
  })  : _listenable = listenable,
        super(repaint: listenable);

  final int seed;

  /// Kept so [paint] can read the controller's elapsed duration
  /// and synthesize a monotonic tick (in 50ms units, matching
  /// the previous cadence) without any setState. The base class
  /// also subscribes to this same listenable to schedule repaints
  /// on every tick.
  final Listenable? _listenable;

  static const int _invaderCols = 10;
  static const int _invaderRows = 4;
  static const double _invaderColsSpacing = 70.0;
  static const double _invaderRowsSpacing = 58.0;
  static const double _invaderPixelSize = 3.0;
  static const double _invaderMarchPeriodFrames = 220.0;

  // The formation descends _stepsBetweenHalfMarches rows every
  // half-march.
  static const int _stepsBetweenHalfMarches = 1;

  // Stars + scanlines — CRT backdrop behind the invaders.
  static const int _starCount = 60;
  static const double _scanlineSpacing = 8.0;
  static const double _scanlineAlpha = 0.10;

  /// Background-color crossfade duration in frames (~50ms each).
  static const int _bgCrossfadeFrames = 60;

  // Painter-local state. These are mutated by paint() which is
  // technically called on the render thread, but in Flutter the
  // render thread and the UI thread are the same for the canvas
  // commands — the CustomPainter is a UI-thread object whose
  // paint() runs on every frame from the engine. Mutating ints
  // is safe (no widget rebuilds are scheduled) and avoids any
  // cross-thread notification.
  int? _lastLandingTick;
  int _bgColorIndex = 0;
  int _bgCrossfadeStartTick = 0;
  Color _currentBg = _kBgPalette[0];

  /// Soft arcade-tint background palette. Cycled every time the
  /// invader formation reaches the bottom edge.
  static const List<Color> _kBgPalette = <Color>[
    Color(0xFF0A0A0A), // near-black
    Color(0xFF0E0A1A), // deep purple
    Color(0xFF0A1419), // deep teal
    Color(0xFF150A0A), // deep maroon
    Color(0xFF0A0F1A), // deep navy
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // Derive a monotonic tick from the listenable's elapsed time.
    // Each unit is 50ms (matching the previous cadence), so the
    // march period constant (`_invaderMarchPeriodFrames = 220`)
    // still represents 11 seconds. Because `lastElapsedDuration`
    // grows across controller cycles, the tick is monotonic over
    // the painter's lifetime, which is what the landing check
    // and the star-twinkle math rely on.
    final Listenable? l = _listenable;
    final int tick = (l is AnimationController)
        ? (l.lastElapsedDuration?.inMilliseconds ?? 0) ~/ 50
        : 0;

    // 0) Background. Either the current palette entry (during the
    //    crossfade) or a linear interpolation between two
    //    adjacent palette entries.
    final Color bg = _computeCurrentBg(tick);
    final Paint bgPaint = Paint()..color = bg;
    canvas.drawRect(Offset.zero & size, bgPaint);

    // 1) Scanlines — CRT backdrop.
    final Paint scanPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: _scanlineAlpha)
      ..strokeWidth = 1.0;
    for (double y = 0; y < size.height; y += _scanlineSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scanPaint);
    }

    // 2) Twinkling stars — sit behind the invaders.
    _drawStars(canvas, size, tick);

    // 3) Invader formation — sweeps the entire viewport.
    const double formationW =
        (_invaderCols - 1) * _invaderColsSpacing + _invaderPixelSize * 5;
    final double phase = (tick % _invaderMarchPeriodFrames) /
        _invaderMarchPeriodFrames;
    final double arc = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
    final double horizontalTravel = size.width - formationW - 80;
    final double originX = 40 + arc * horizontalTravel;

    final int halfMarches = (tick ~/ (_invaderMarchPeriodFrames / 2)) % 100000;
    final int playfieldHeightRows =
        (size.height / _invaderRowsSpacing).floor();
    final int totalRowOffset = halfMarches * _stepsBetweenHalfMarches;
    final int visibleRowOffset =
        totalRowOffset % (playfieldHeightRows + _invaderRows);
    final double descentOriginY =
        (size.height * 0.05) + visibleRowOffset * _invaderRowsSpacing;
    final double bottomRowY = descentOriginY +
        (_invaderRows - 1) * _invaderRowsSpacing;
    final bool landed = bottomRowY > size.height - 80;
    if (landed && _lastLandingTick != tick) {
      _lastLandingTick = tick;
      // Advance the palette index and start the crossfade.
      // No setState, no ValueNotifier — the painter is
      // responsible for its own visual state from this point on.
      _bgColorIndex = (_bgColorIndex + 1) % _kBgPalette.length;
      _bgCrossfadeStartTick = tick;
    }

    final double originY = landed
        ? size.height - 80 - (_invaderRows - 1) * _invaderRowsSpacing
        : descentOriginY;

    // Per-row color and shape.
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

  /// Linear interpolation between the previous palette entry and
  /// the new one, over [_bgCrossfadeFrames] frames after a landing.
  /// Falls back to the current entry once the crossfade is done.
  Color _computeCurrentBg(int currentTick) {
    if (_bgCrossfadeStartTick == 0) {
      // First paint ever, no crossfade pending.
      _currentBg = _kBgPalette[_bgColorIndex];
      return _currentBg;
    }
    final int elapsed = currentTick - _bgCrossfadeStartTick;
    if (elapsed >= _bgCrossfadeFrames) {
      _currentBg = _kBgPalette[_bgColorIndex];
      return _currentBg;
    }
    final int fromIndex = (_bgColorIndex - 1 + _kBgPalette.length) %
        _kBgPalette.length;
    final Color from = _kBgPalette[fromIndex];
    final Color to = _kBgPalette[_bgColorIndex];
    final double t = (elapsed / _bgCrossfadeFrames).clamp(0.0, 1.0);
    final Color lerped = Color.lerp(from, to, t) ?? to;
    _currentBg = lerped;
    return lerped;
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

  void _drawStars(Canvas canvas, Size size, int tick) {
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
  bool shouldRepaint(InvaderMarchPainter old) =>
      old._listenable != _listenable;
}

extension on double {
  /// Map a radians value to a 0..1 sine wave.
  double sinToOne() => 0.5 + 0.5 * math.sin(this);
}
