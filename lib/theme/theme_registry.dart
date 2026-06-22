/// Theme registry — maps the persisted theme id to a concrete
/// [KioskTheme] instance.
///
/// Why a registry instead of `switch (id)` in `ConfigStore`? The
/// registry inverts the dependency: `ConfigStore` does not need to
/// know which theme classes exist. To add a new theme, register it
/// here and `ConfigStore` is none the wiser.
///
/// Order in [allThemes] is the order shown in the admin picker.
library;

import 'kiosk_theme.dart';
import 'themes/classic_theme.dart';

/// Every theme shipped with the kiosk. Order = admin picker order.
/// PR3 adds the `WorldcupTheme` here; until then the picker shows
/// only the classic theme.
final List<KioskTheme> allThemes = <KioskTheme>[
  const ClassicTheme(),
];

/// Default theme id when the operator has never picked one
/// (first boot, fresh SharedPreferences). PR3 will switch this to
/// `'worldcup'` once the worldcup theme is shippable.
const String kDefaultThemeId = 'classic';

/// Returns the theme with the given [id], or the default theme
/// if [id] is null, empty, or not registered. Never throws — the
/// kiosk must always have a theme, even after a corrupt pref or
/// a downgrade that removes a previously-shipped theme.
KioskTheme themeFor(String? id) {
  if (id != null && id.isNotEmpty) {
    for (final KioskTheme t in allThemes) {
      if (t.id == id) return t;
    }
  }
  return themeFor(kDefaultThemeId);
}
