/// Worldcup theme — Selección Colombia look. Ships alongside the
/// `classic` theme; the operator picks one from the admin panel.
///
/// Visual identity:
///   * Background: deep azul bandera (Colombian flag blue).
///   * Accent: amarillo bandera (Colombian flag yellow).
///   * Playing palette starts at black and cycles through yellow /
///     blue / red to keep the chronograph legible while pulling
///     in the Selección palette.
///   * Verdict background tints use yellow for VICTORIA (gol),
///     amber for CASI (al palo), red-bandera for the misses.
///
/// Copy:
///   * Spanish (Colombia, "es-CO"). Football lingo throughout.
///   * Verdict labels: "¡GOOOOL!", "¡AL PALO!", "¡AFUERA!",
///     "¡SE PITÓ FINAL!". All CAPS so they read at kiosk distance.
///
/// Painters:
///   * The waiting-screen march is rendered by
///     [FootballMarchPainter] (soccer balls on a stadium-night
///     background — same marching cadence as the classic invaders
///     so the visual rhythm is preserved).
///   * The result-screen sprite is rendered by
///     [FootballSpritePainter] (player / referee in 4 poses).
library;

import 'package:flutter/material.dart';

import '../kiosk_theme.dart';
import '../../widgets/football_march_painter.dart';
import '../../widgets/football_sprite_painter.dart';
import '../../widgets/goal_backdrop_painter.dart';

/// Colombian flag blue — used as the primary background.
const Color _kAzulBandera = Color(0xFF0E1A4A);

/// Colombian flag yellow — the primary accent.
const Color _kAmarilloBandera = Color(0xFFFFCD00);

/// Colombian flag red — secondary accent and miss indicator.
const Color _kRojoBandera = Color(0xFFCE1126);

/// Body text on dark backgrounds.
const Color _kTextOnDark = Color(0xFFFFFFFF);

/// Playing-screen background — white, like a paper stopwatch.
/// Same as classic because the chronograph needs max contrast
/// regardless of theme.
const Color _kPlayingBackground = Color(0xFFFFFFFF);

/// Digit rotation for the chronograph. Starts at black so the
/// initial frame matches classic, then drifts through the
/// Selección palette.
const List<Color> _kPlayingPalette = <Color>[
  Color(0xFF000000), // black (initial)
  Color(0xFFFFCD00), // amarillo bandera
  Color(0xFF00B0FF), // sky blue
  Color(0xFFCE1126), // rojo bandera
  Color(0xFFFF8F00), // warm amber
  Color(0xFF000000), // back to black
];

/// Background tint of the WAITING screen Scaffold (visible
/// before the painter's first frame).
const Color _kWaitingScaffold = Color(0xFF06112E);

class WorldcupTheme implements KioskTheme {
  const WorldcupTheme();

  @override
  String get id => 'worldcup';

  @override
  String get displayName => 'Selección Colombia';

  @override
  Color get backgroundColor => _kAzulBandera;

  @override
  Color get textColor => _kTextOnDark;

  @override
  Color get accentColor => _kAmarilloBandera;

  @override
  Color get playingBackgroundColor => _kPlayingBackground;

  @override
  List<Color> get playingColorPalette => _kPlayingPalette;

  @override
  Color get waitingScaffoldColor => _kWaitingScaffold;

  @override
  String get splashTitle => 'PENAL PERFECTO';

  @override
  String get materialAppTitle => 'Penal Perfecto';

  @override
  List<String> get invitationMessages => const <String>[
        '¡Gol, en 10s exactos!',
        '¡10s, penal!',
        '¡Demostrá tu pegada!',
      ];

  @override
  List<String> get subTaglines => const <String>[
        '¡GOOOOL!',
        '¡ERES EL CRACK!',
        '¡METÉ ESE GOL!',
        '¡DALE CON FE!',
        '¡TIRÁ EL PENAL!',
      ];

  @override
  List<String> get playingPreparationMessages => const <String>[
        'CONCENTRACIÓN',
        'ENFOQUE',
        'FALTA POCO',
        'PODÉS',
        'RESPIRA',
        'PREPARA',
      ];

  @override
  List<String> get playingUrgencyMessages => const <String>[
        '¡PEGALÉ!',
        '¡DISPARÁ!',
        '¡AHORA!',
        '¡TIRÁ!',
        '¡DALÉ!',
      ];

  @override
  String verdictLabel(VerdictKind kind) {
    switch (kind) {
      case VerdictKind.victoria:
        return '¡GOOOOL!';
      case VerdictKind.casi:
        return '¡AL PALO!';
      case VerdictKind.niPorAsomo:
        return '¡AFUERA!';
      case VerdictKind.tePasaste:
        return '¡SE PITÓ FINAL!';
    }
  }

  @override
  String casiCaption() => '¡AL PALO!';

  @override
  Color verdictBackground(VerdictKind kind) {
    switch (kind) {
      case VerdictKind.victoria:
        return const Color(0xFF3A2E00); // deep amarillo
      case VerdictKind.casi:
        return const Color(0xFF3A1F00); // deep amber (same as classic)
      case VerdictKind.niPorAsomo:
        return const Color(0xFF3A050A); // deep rojo bandera
      case VerdictKind.tePasaste:
        return const Color(0xFF260308); // deeper rojo bandera
    }
  }

  @override
  Color verdictColor(VerdictKind kind) {
    switch (kind) {
      case VerdictKind.victoria:
        return _kAmarilloBandera;
      case VerdictKind.casi:
        return const Color(0xFFFFC107); // amber
      case VerdictKind.niPorAsomo:
        return const Color(0xFFFF6B6B); // light red
      case VerdictKind.tePasaste:
        return _kRojoBandera;
    }
  }

  @override
  CustomPainter backgroundMarchPainter({required Listenable listenable}) {
    return FootballMarchPainter(seed: 1337, listenable: listenable);
  }

  @override
  CustomPainter playingBackdropPainter({required double t}) {
    return GoalBackdropPainter(
      mode: BackdropMode.idle,
      t: t,
      showField: true,
    );
  }

  @override
  CustomPainter resultBackdropPainter({
    required VerdictKind verdict,
    required double t,
  }) {
    return GoalBackdropPainter(
      mode: _verdictToBackdropMode(verdict),
      t: t,
      showField: false,
    );
  }

  @override
  bool get appliesCrtOverlay => true;

  /// Map the gameplay verdict to the ball-trajectory animation.
  BackdropMode _verdictToBackdropMode(VerdictKind kind) {
    switch (kind) {
      case VerdictKind.victoria:
        return BackdropMode.goal;
      case VerdictKind.casi:
        return BackdropMode.post;
      case VerdictKind.niPorAsomo:
        return BackdropMode.wide;
      case VerdictKind.tePasaste:
        return BackdropMode.over;
    }
  }

  @override
  CustomPainter resultSpritePainter({
    required VerdictKind verdict,
    required double pixelSize,
    required double t,
    required List<Color> colors,
  }) {
    return FootballSpritePainter(
      expression: _toFootballExpression(verdict),
      pixelSize: pixelSize,
      t: t,
      colors: colors,
    );
  }

  FootballExpression _toFootballExpression(VerdictKind kind) {
    switch (kind) {
      case VerdictKind.victoria:
        return FootballExpression.victoria;
      case VerdictKind.casi:
        return FootballExpression.casi;
      case VerdictKind.niPorAsomo:
        return FootballExpression.niPorAsomo;
      case VerdictKind.tePasaste:
        return FootballExpression.tePasaste;
    }
  }
}
