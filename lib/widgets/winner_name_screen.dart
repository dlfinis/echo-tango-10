/// WINNER_NAME screen — celebration, name entry, persist to leaderboard.
///
/// Stacked layers (back-to-front):
///   1. green flash overlay that fades out (`AnimatedOpacity`)
///   2. confetti painter (full-screen, deterministic)
///   3. Column: "VICTORIA", microsecond result, name TextField, Aceptar
///
/// On `isEasterEgg == true` (|delta| < 1 microsecond) an extra glow ring
/// + "¡EXACTO!" text is rendered above the rest.
///
/// On Aceptar:
///   * validate non-empty name → default to "ANONIMO"
///   * build [LeaderboardEntry] and `Leaderboard.add(entry)`
///   * call [onAccept] to return to WAITING
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/leaderboard_entry.dart';
import '../services/leaderboard.dart';
import '../utils/constants.dart';
import 'confetti_painter.dart';

class WinnerNameScreen extends StatefulWidget {
  const WinnerNameScreen({
    super.key,
    required this.elapsedSeconds,
    required this.leaderboard,
    required this.onAccept,
    this.isEasterEgg = false,
  });

  /// The raw measured time, in seconds.
  final double elapsedSeconds;

  /// Persistence seam — `WinnerNameScreen` only writes here, never to
  /// disk directly.
  final Leaderboard leaderboard;

  /// Forwarded by the parent; called once the name is accepted.
  final VoidCallback onAccept;

  /// True when |delta| is below [kEasterEggToleranceSeconds] (1 µs).
  final bool isEasterEgg;

  @override
  State<WinnerNameScreen> createState() => _WinnerNameScreenState();
}

class _WinnerNameScreenState extends State<WinnerNameScreen>
    with TickerProviderStateMixin {
  static const String _defaultName = 'ANONIMO';
  static const int _maxNameLength = 16;

  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  late final AnimationController _confettiController;
  late final AnimationController _flashController;

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
      value: 1.0,
    )..reverse();

    // Autofocus the name field on the next frame so the soft keyboard
    // appears without stealing the initial paint.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _flashController.dispose();
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  String _resolveName() {
    final String raw = _nameController.text.trim();
    if (raw.isEmpty) return _defaultName;
    if (raw.length > _maxNameLength) {
      return raw.substring(0, _maxNameLength);
    }
    return raw;
  }

  Future<void> _handleAccept() async {
    final String name = _resolveName();
    final double delta = widget.elapsedSeconds - kTargetSeconds;
    final LeaderboardEntry entry = LeaderboardEntry(
      name: name,
      timestamp: DateTime.now().toUtc(),
      rawSeconds: widget.elapsedSeconds,
      delta: delta,
    );
    await widget.leaderboard.add(entry);
    if (!mounted) return;
    widget.onAccept();
  }

  String _formattedRaw() => widget.elapsedSeconds.toStringAsFixed(4);
  String _formattedDelta() {
    final double d = widget.elapsedSeconds - kTargetSeconds;
    final String sign = d >= 0 ? '+' : '-';
    return '$sign${d.abs().toStringAsFixed(4)}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(kDefaultBgColorHex),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Layer 1: green flash overlay.
            AnimatedBuilder(
              animation: _flashController,
              builder: (BuildContext context, Widget? child) {
                return IgnorePointer(
                  child: Container(
                    color: const Color(kDefaultAccentColorHex)
                        .withValues(alpha: 0.35 * _flashController.value),
                  ),
                );
              },
            ),

            // Layer 2: confetti painter (deterministic, time-driven).
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _confettiController,
                builder: (BuildContext context, Widget? child) {
                  return CustomPaint(
                    painter: ConfettiPainter(
                      value: _confettiController.value,
                      seed: 0xC0FFEE,
                      intensity: widget.isEasterEgg ? 2.0 : 1.0,
                    ),
                    size: Size.infinite,
                  );
                },
              ),
            ),

            // Layer 3: easter-egg glow ring + "¡EXACTO!" text.
            if (widget.isEasterEgg)
              IgnorePointer(
                child: Center(
                  child: Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(kDefaultAccentColorHex),
                        width: 8,
                      ),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x6600FF00),
                          blurRadius: 64,
                          spreadRadius: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Layer 4: VICTORIA + result + name entry.
            Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      widget.isEasterEgg ? '¡EXACTO!' : 'VICTORIA',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(kDefaultAccentColorHex),
                        fontSize: widget.isEasterEgg ? 112 : 96,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                        shadows: widget.isEasterEgg
                            ? const <Shadow>[
                                Shadow(
                                  color: Color(0xFF00FF00),
                                  blurRadius: 32,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _formattedRaw(),
                      style: const TextStyle(
                        color: Color(kDefaultTextColorHex),
                        fontSize: 72,
                        fontWeight: FontWeight.w900,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formattedDelta(),
                      style: const TextStyle(
                        color: Color(kDefaultAccentColorHex),
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: 320,
                      child: TextField(
                        controller: _nameController,
                        focusNode: _nameFocus,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.done,
                        maxLength: _maxNameLength,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(kDefaultTextColorHex),
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                        cursorColor: const Color(kDefaultAccentColorHex),
                        decoration: const InputDecoration(
                          hintText: 'Tu nombre',
                          hintStyle: TextStyle(
                            color: Color(0xFF888888),
                            fontSize: 24,
                          ),
                          counterStyle: TextStyle(
                            color: Color(0xFF888888),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Color(kDefaultTextColorHex),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Color(kDefaultAccentColorHex),
                              width: 2,
                            ),
                          ),
                        ),
                        onSubmitted: (_) => _handleAccept(),
                        inputFormatters: <TextInputFormatter>[
                          // Block newline + control chars; allow unicode
                          // letters/digits/punct so es-AR names work.
                          FilteringTextInputFormatter.deny(
                            RegExp(r'[\r\n\t]'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _handleAccept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(kDefaultAccentColorHex),
                        foregroundColor:
                            const Color(kDefaultBgColorHex),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 48,
                          vertical: 16,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      child: const Text('Aceptar'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
