/// Classic theme — the original Space Invaders look shipped with
/// v0.1.0-arcade. This is the "do not change" baseline: every
/// value here mirrors the constants/painters that were in
/// `lib/utils/constants.dart`, `lib/services/config_store.dart`,
/// `lib/widgets/waiting_screen.dart` and `lib/widgets/invader_sprite.dart`
/// at the time of the v0.1.0-arcade tag.
///
/// The class is a thin delegate — it does not re-implement the
/// painters. Instead it forwards to the existing
/// [InvaderMarchPainter] (waiting screen) and [InvaderSpritePainter]
/// (result screen) so behaviour is byte-identical to v0.1.0-arcade
/// and all existing tests keep passing.
///
/// New themes (e.g. `WorldcupTheme`) live beside this file and do
/// NOT touch it.
library;

import 'package:flutter/material.dart';

import '../kiosk_theme.dart';
import '../../widgets/invader_sprite.dart';
import '../../widgets/waiting_screen.dart';

/// Default accent (victory glow, primary CTA): neon green.
/// Matches `kDefaultAccentColorHex` in v0.1.0-arcade.
const Color _kClassicAccent = Color(0xFF00FF00);

/// Default background: dark grey. Matches `kDefaultBgColorHex`.
const Color _kClassicBackground = Color(0xFF121212);

/// Default body text. Matches `kDefaultTextColorHex`.
const Color _kClassicText = Color(0xFFFFFFFF);

/// Playing-screen background: pure white, like a paper stopwatch.
const Color _kClassicPlayingBackground = Color(0xFFFFFFFF);

/// Playing-screen digit rotation. Each entry is a digit color;
/// the rotation starts at index 0 and advances by one entry every
/// `kPlayingColorShiftInterval` seconds.
const List<Color> _kClassicPlayingPalette = <Color>[
  Color(0xFF000000), // black (initial)
  Color(0xFF00B0FF), // sky blue
  Color(0xFF00C853), // mint green
  Color(0xFFFF6D00), // amber
  Color(0xFFD500F9), // magenta
  Color(0xFF000000), // back to black
];

class ClassicTheme implements KioskTheme {
  const ClassicTheme();

  @override
  String get id => 'classic';

  @override
  String get displayName => 'Arcade Clásico';

  @override
  Color get backgroundColor => _kClassicBackground;

  @override
  Color get waitingScaffoldColor => const Color(0xFF0A0A0A);

  @override
  Color get textColor => _kClassicText;

  @override
  Color get accentColor => _kClassicAccent;

  @override
  Color get playingBackgroundColor => _kClassicPlayingBackground;

  @override
  List<Color> get playingColorPalette => _kClassicPlayingPalette;

  @override
  String get splashTitle => 'ARCADE TIMER 10s';

  @override
  String get materialAppTitle => 'Arcade Timer 10s';

  @override
  List<String> get invitationMessages => const <String>[
        '¡Presioná el botón para jugar!',
        '¿Te animás a los 10 segundos exactos?',
        '¡El que pega en 10.000s gana!',
      ];

  @override
  List<String> get subTaglines => const <String>[
        '¡JUGÁ Y GANÁ EL PREMIO!',
        '¿PODÉS ROMPER EL RÉCORD?',
        '¿TENÉS HABILIDAD?',
        '¿SOS CAPAZ DEL RÉCORD?',
        '¡APUNTÁ AL 10 EXACTO!',
      ];

  @override
  List<String> get playingPreparationMessages => const <String>[
        'PREPARATÉ',
        'YA VIENE',
        'PODRÁS',
        'ENFOQUE',
        'CONCENTRACIÓN',
      ];

  @override
  List<String> get playingUrgencyMessages => const <String>[
        '¡YA!',
        '¡APURATÉ!',
        '¡PRESIONA!',
        '¡AHORA!',
        '¡DALE YA!',
      ];

  @override
  String verdictLabel(VerdictKind kind) {
    switch (kind) {
      case VerdictKind.victoria:
        return '¡GANASTE!';
      case VerdictKind.casi:
        return '¡CASI, CASI!';
      case VerdictKind.niPorAsomo:
        return '¡NI POR ASOMO!';
      case VerdictKind.tePasaste:
        return '¡TE PASASTE!';
    }
  }

  @override
  String casiCaption() => '¡POR UN PELO!';

  @override
  Color verdictBackground(VerdictKind kind) {
    switch (kind) {
      case VerdictKind.victoria:
        return const Color(0xFF003A0A); // deep green
      case VerdictKind.casi:
        return const Color(0xFF3A1F00); // deep amber
      case VerdictKind.niPorAsomo:
        return const Color(0xFF2A0505); // soft red
      case VerdictKind.tePasaste:
        return const Color(0xFF1A0303); // deeper red
    }
  }

  @override
  Color verdictColor(VerdictKind kind) {
    switch (kind) {
      case VerdictKind.victoria:
        return _kClassicAccent;
      case VerdictKind.casi:
        return const Color(0xFFFFC107);
      case VerdictKind.niPorAsomo:
        return const Color(0xFFFF7070);
      case VerdictKind.tePasaste:
        return const Color(0xFFFF5252);
    }
  }

  @override
  CustomPainter backgroundMarchPainter({required Listenable listenable}) {
    return InvaderMarchPainter(seed: 1337, listenable: listenable);
  }

  @override
  CustomPainter playingBackdropPainter({required double t}) {
    return const _EmptyPainter();
  }

  @override
  CustomPainter resultBackdropPainter({
    required VerdictKind verdict,
    required double t,
  }) {
    return const _EmptyPainter();
  }

  @override
  bool get appliesCrtOverlay => false;

  @override
  CustomPainter resultSpritePainter({
    required VerdictKind verdict,
    required double pixelSize,
    required double t,
    required List<Color> colors,
  }) {
    return InvaderSpritePainter(
      expression: _toInvaderExpression(verdict),
      pixelSize: pixelSize,
      t: t,
      colors: colors,
    );
  }

  InvaderExpression _toInvaderExpression(VerdictKind kind) {
    switch (kind) {
      case VerdictKind.victoria:
        return InvaderExpression.victoria;
      case VerdictKind.casi:
        return InvaderExpression.casi;
      case VerdictKind.niPorAsomo:
        return InvaderExpression.niPorAsomo;
      case VerdictKind.tePasaste:
        return InvaderExpression.tePasaste;
    }
  }
}

/// Minimal transparent painter used by themes that don't ship
/// a themed scene behind the chronograph (classic: pure white).
class _EmptyPainter extends CustomPainter {
  const _EmptyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // No-op — leaves the Scaffold background visible.
  }

  @override
  bool shouldRepaint(_EmptyPainter old) => false;
}
