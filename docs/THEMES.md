# Themes — Arcade Timer 10s

The kiosk ships with a swappable visual theme system. Themes own
copy (in their language + voice), colors, and the painters used by
the waiting-screen march and the result-screen sprite. The screens
themselves depend on the abstract `KioskTheme` interface, so
adding a new theme does not require changes to any screen.

---

## Shipped themes

| id | Display name | Default | Notes |
|---|---|---|---|
| `worldcup` | Selección Colombia | ✅ (since v0.2.0-themes) | Azul / amarillo / rojo bandera. Copy in es-CO with football lingo. Pelotas marching, player sprite. |
| `classic` | Arcade Clásico |  | The original Space Invaders look from v0.1.0-arcade. Green / cyan / magenta palette. Copy in es-AR. |

The first boot defaults to `worldcup`. The operator can switch
from the admin panel (`Administrar → Tema activo`). The selection
persists in SharedPreferences (`active_theme_id`).

---

## How a theme is structured

Every theme implements the `KioskTheme` interface:

```dart
abstract class KioskTheme {
  String get id;                                  // stable id
  String get displayName;                         // shown in admin
  Color get backgroundColor;
  Color get textColor;
  Color get accentColor;
  Color get playingBackgroundColor;
  List<Color> get playingColorPalette;
  Color get waitingScaffoldColor;
  String get splashTitle;
  String get materialAppTitle;
  List<String> get invitationMessages;
  List<String> get subTaglines;
  List<String> get playingPreparationMessages;
  List<String> get playingUrgencyMessages;
  String verdictLabel(VerdictKind kind);
  String casiCaption();
  Color verdictBackground(VerdictKind kind);
  Color verdictColor(VerdictKind kind);
  CustomPainter backgroundMarchPainter({required Listenable listenable});
  CustomPainter resultSpritePainter({
    required VerdictKind verdict,
    required double pixelSize,
    required double t,
    required List<Color> colors,
  });
}
```

`VerdictKind` has exactly four values: `victoria`, `casi`,
`niPorAsomo`, `tePasaste`. The mapping from raw `elapsed` to a
`VerdictKind` is fixed gameplay logic (lives in `ResultScreen`'s
classify function) — themes only change the presentation, never
the verdict itself.

---

## Adding a new theme (5 steps)

1. **Pick a stable id** — never change a shipped id; renaming
   orphans the operator's saved selection. Use lowercase with
   hyphens (e.g. `navidad`, `halloween`).

2. **Create the file** at `lib/theme/themes/<id>_theme.dart` with
   a class that `implements KioskTheme`. Copy `classic_theme.dart`
   as a starting skeleton.

3. **Implement two painters**. Each theme owns its march
   painter (returned by `backgroundMarchPainter`) and its result
   sprite painter (returned by `resultSpritePainter`). The march
   painter is a `CustomPainter` driven by a `Listenable`; the
   sprite painter takes `(verdict, pixelSize, t, colors)` where
   `t ∈ [0, 1]` is the animation phase. Pixel art is fine — the
   classic theme uses 11x8 invader bitmaps at 3 px each; the
   worldcup theme uses 7x7 ball bitmaps at 3 px each.

4. **Register the theme** in `lib/theme/theme_registry.dart`:
   add it to `allThemes` (order = admin picker order) and, if
   it should be the new default, update `kDefaultThemeId`.

5. **Test** by copying `test/worldcup_theme_test.dart` and
   renaming to `test/<id>_theme_test.dart`. Pin identity,
   palette, copy, painter type (must be its own type, not
   classic), and registry placement.

---

## Precedence rules

- **Colors** — always come from the theme. Operators cannot
  override them per theme (the curated palettes in the admin
  screen now apply only to the `classic` theme's accent if you
  decide to expose them).
- **Copy** — operator override wins over the theme's defaults.
  If the operator has edited `invitation_messages` or
  `sub_taglines` in SharedPreferences, those values are shown
  instead of the theme's defaults. To use a theme's defaults,
  clear the override from the admin form (or "Borrar base de
  datos").
- **Active theme id** — persisted under
  `ConfigStore.kKeyActiveThemeId`. A null or unknown value
  resolves to `kDefaultThemeId` via `themeFor()`. The kiosk
  never crashes on a corrupt id.

---

## Verdict vocabulary (per theme)

| VerdictKind | `classic` | `worldcup` |
|---|---|---|
| `victoria` | "¡GANASTE!" | "¡GOOOOL!" |
| `casi` | "¡CASI, CASI!" (caption: "¡POR UN PELO!") | "¡AL PALO!" (caption: "¡AL PALO!") |
| `niPorAsomo` | "¡NI POR ASOMO!" | "¡AFUERA!" |
| `tePasaste` | "¡TE PASASTE!" | "¡SE PITÓ FINAL!" |

The caption is the small sign that appears next to the sprite
on the CASI branch only.

---

## Tagging

| Tag | Commit | Description |
|---|---|---|
| `v0.1.0-arcade` | pre-tema-futbol-colombia HEAD | The original kiosk. Single theme (the `classic` look, baked into constants). Use this to roll back if the theme abstraction causes any regression in the field. |
| `v0.2.0-themes` | post PR3 HEAD | Theme abstraction + `classic` + `worldcup` shipped. The current `main`. |

To roll back from `v0.2.0-themes` to `v0.1.0-arcade`:

```
git checkout v0.1.0-arcade
```

(The kiosk will not have the `worldcup` theme visible in the
admin. Setting `active_theme_id = 'classic'` on `v0.2.0-themes`
gives equivalent behaviour.)

---

## Architecture notes

- The screens depend on `KioskTheme` (Dependency Inversion) and
  never on a concrete theme class. Tests pass `const ClassicTheme()`
  to keep the test surface stable across releases.
- The registry (`themeFor`) is the only place that knows about
  every shipped theme. `ConfigStore` does not.
- Painter implementations are intentionally **outside** the
  `lib/theme/` directory (in `lib/widgets/`) because they
  import `package:flutter/material.dart` directly. Themes
  import them. This keeps `lib/theme/` free of framework
  dependencies where possible.
