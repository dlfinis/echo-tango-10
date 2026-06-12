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

import 'dart:async';

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
  static const Duration _autoSkipTimeout = Duration(seconds: 15);

  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  late final AnimationController _confettiController;
  late final AnimationController _flashController;
  Timer? _autoSkipTimer;

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

    // Force the typed text to uppercase. TextCapitalization only
    // suggests uppercase on the soft keyboard — the actual stored
    // value respects what the user types, so we listen and rewrite
    // the value to its upper-case form. This keeps the visual in
    // sync with the input formatters (which only allow A-Z).
    _nameController.addListener(_forceUppercase);

    // Autofocus the name field on the next frame so the soft keyboard
    // appears without stealing the initial paint.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocus.requestFocus();
    });

    // 15s auto-skip: if the user does not press ACEPTAR or SALTAR
    // within the window, treat it as Saltar (return to WAITING
    // without saving). Cancelled by Aceptar/Saltar or dispose.
    _autoSkipTimer = Timer(_autoSkipTimeout, () {
      if (!mounted) return;
      widget.onAccept();
    });
  }

  @override
  void dispose() {
    _autoSkipTimer?.cancel();
    _confettiController.dispose();
    _flashController.dispose();
    _nameController.removeListener(_forceUppercase);
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  /// Force the controller's text to its upper-case form. The
  /// `inputFormatters` already strip anything that is not A-Z, so
  /// this listener only has to upper-case the surviving letters.
  void _forceUppercase() {
    final String current = _nameController.text;
    final String upper = current.toUpperCase();
    if (upper == current) return;
    _nameController.value = TextEditingValue(
      text: upper,
      selection: TextSelection.collapsed(offset: upper.length),
    );
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
    _autoSkipTimer?.cancel();
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

  void _handleSkip() {
    _autoSkipTimer?.cancel();
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
                    const Text(
                      '😀',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 96,
                        fontFamily: 'AppleColorEmoji',
                        fontFamilyFallback: <String>[
                          'NotoColorEmoji',
                          'Segoe UI Emoji',
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
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
                    const SizedBox(height: 8),
                    const Text(
                      '¡INGRESÁ TU NOMBRE!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(kDefaultTextColorHex),
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 16),
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
                        maxLength: 5,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(kDefaultAccentColorHex),
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
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
                          // Solo letras A-Z y máximo 5 caracteres.
                          // Aceptamos A-Z y a-z para que el listener
                          // [_forceUppercase] pueda convertir minúsculas
                          // a mayúsculas antes de renderizar; el
                          // resultado visible siempre es A-Z.
                          LengthLimitingTextInputFormatter(5),
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[A-Za-z]'),
                            replacementString: '',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        ElevatedButton(
                          onPressed: _handleAccept,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(kDefaultAccentColorHex),
                            foregroundColor:
                                const Color(kDefaultBgColorHex),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          child: const Text('Aceptar'),
                        ),
                        const SizedBox(width: 16),
                        OutlinedButton(
                          onPressed: _handleSkip,
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                const Color(kDefaultTextColorHex),
                            side: const BorderSide(
                              color: Color(kDefaultTextColorHex),
                              width: 2,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          child: const Text('SALTAR'),
                        ),
                      ],
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
