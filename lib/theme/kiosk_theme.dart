/// Kiosk theme abstraction.
///
/// Every visible aspect of the kiosk — copy, colors, painter style for
/// the waiting-screen march, painter for the result-screen sprite —
/// lives behind this interface. The screens depend on [KioskTheme],
/// not on any concrete theme implementation, so adding a new theme
/// does not require changes in the screens (Open/Closed).
///
/// Two concrete themes ship with the kiosk:
///
///   * `classic`            — the original Space Invaders look.
///                            Source of truth for the v0.1.0-arcade
///                            release. Add new themes beside it; do
///                            not mutate it.
///   * `worldcup`           — Selección Colombia (see
///                            `themes/worldcup_theme.dart`).
///
/// Themes are registered in `theme_registry.dart`. The active theme
/// id is persisted via [ConfigStore.activeThemeId] (see PR3).
library;

import 'package:flutter/material.dart';

/// The four verdict tiers the game logic can produce. The mapping
/// from raw `elapsed` to one of these is FIXED — it lives in the
/// gameplay code (kFarShortThresholdSeconds, kVictoryOvershootSeconds,
/// etc.). What changes between themes is the PRESENTATION of each
/// tier: label text, color, and sprite.
enum VerdictKind { victoria, casi, niPorAsomo, tePasaste }

/// Contract every kiosk theme must satisfy.
///
/// Implementations are stateless singletons — all accessors return
/// constants. There is no `init` / `dispose` because the painters
/// are created per-paint and own no resources.
abstract class KioskTheme {
  /// Stable identifier persisted to SharedPreferences. Never change
  /// the id of a theme once shipped: it would orphan the operator's
  /// saved selection. New themes must pick a new id.
  String get id;

  /// Human-readable name shown in the admin theme picker.
  String get displayName;

  // -- Identity / palette --------------------------------------------------

  /// App-wide background (admin + winner screens).
  Color get backgroundColor;

  /// Background of the WAITING screen Scaffold, shown only as a
  /// fallback before the [backgroundMarchPainter] paints its first
  /// frame (and during transitions). The marching painter draws
  /// over it on every tick.
  Color get waitingScaffoldColor;

  /// App-wide body text.
  Color get textColor;

  /// App-wide accent: victory glow, focus rings, primary CTA buttons.
  Color get accentColor;

  /// Background of the PLAYING screen. Most themes use a near-white
  /// "paper" so the chronograph digits have maximum contrast.
  Color get playingBackgroundColor;

  /// Rotation palette for the playing-screen chronograph digits.
  /// Cycles every [kPlayingColorShiftInterval] seconds.
  List<Color> get playingColorPalette;

  // -- Copy -----------------------------------------------------------------

  String get splashTitle;
  String get materialAppTitle;
  List<String> get invitationMessages;
  List<String> get subTaglines;
  List<String> get playingPreparationMessages;
  List<String> get playingUrgencyMessages;

  // -- Verdict presentation ------------------------------------------------

  /// Big headline shown under the chronograph on the result screen
  /// (e.g. "¡GANASTE!" for classic, "¡GOOOOL!" for worldcup).
  String verdictLabel(VerdictKind kind);

  /// CASI-specific small caption shown next to the sprite
  /// (e.g. "¡POR UN PELO!" for classic, "¡AL PALO!" for worldcup).
  /// Ignored for verdicts other than [VerdictKind.casi].
  String casiCaption();

  /// Background tint of the result screen for a given verdict.
  Color verdictBackground(VerdictKind kind);

  /// Foreground (sprite body + verdict label) color of the result
  /// screen for a given verdict.
  Color verdictColor(VerdictKind kind);

  // -- Painters ------------------------------------------------------------

  /// Full-screen march painter for the waiting screen. Owns the
  /// background, scanlines/stars, and the themed formation that
  /// sweeps the viewport. Driven by [listenable] — the parent
  /// screen hands its [AnimationController] in.
  CustomPainter backgroundMarchPainter({required Listenable listenable});

  /// Background painter shown as a small inset in the upper
  /// right corner of the PLAYING screen. Themes that don't
  /// have a themed scene (e.g. the classic Space Invaders
  /// look) return an empty painter; themes with a scene
  /// (e.g. worldcup's penalty scene) return their own
  /// implementation. The painter receives a `t` value in
  /// `[0, 1]` so the scene can have idle animation while the
  /// player is winding up.
  CustomPainter playingScenePainter({required double t});

  /// True if the theme wants the CRT scanlines overlay drawn
  /// over the PLAYING / RESULT screens. Worldcup = true
  /// (retro arcade feel); classic = false (preserves the
  /// v0.1.0-arcade look).
  bool get appliesCrtOverlay;

  /// Body sprite painter shown in the result screen for a given
  /// verdict. [pixelSize] is the size of a single "pixel" cell of
  /// the underlying bitmap (the painter handles scaling). [t] is
  /// the animation phase in `[0, 1]` — the painter reads it and
  /// renders the corresponding frame. [colors] is `[body, cavity]`
  /// — the body color and the cut-out color for eyes/mouth/etc.
  CustomPainter resultSpritePainter({
    required VerdictKind verdict,
    required double pixelSize,
    required double t,
    required List<Color> colors,
  });

  /// Background scene painter shown on the RESULT screen,
  /// behind the sprite. [verdict] picks the ball trajectory
  /// (goal / post / wide / over); [t] is the animation phase
  /// in `[0, 1]`. Themes without a themed scene (classic)
  /// return an empty painter; themes with a scene (worldcup's
  /// penalty scene) render the trajectory + shake / post-bounce
  /// that matches the verdict.
  CustomPainter resultScenePainter({
    required VerdictKind verdict,
    required double t,
  });
}
