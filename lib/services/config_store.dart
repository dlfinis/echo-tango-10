/// Typed `shared_preferences` wrapper for the arcade timer.
///
/// Centralizes every pref key, every default, and the JSON shape used to
/// serialize the leaderboard. The rest of the app should never call
/// `SharedPreferences.getInstance()` directly — go through this class so
/// keys and shapes stay in one place.
///
/// The class is **lazy**: the [SharedPreferences] instance is loaded once
/// on first use and cached. All read methods are sync (after the initial
/// load). All write methods are `async` because the underlying plugin
/// writes to disk asynchronously.
library;

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/leaderboard_entry.dart';
import '../utils/constants.dart';

/// Default invitation messages shown during the WAITING loop.
///
/// Spanish (es-AR) — the brief and tech_specs hardcode this locale; no
/// i18n is in scope. Order is the default rotation order.
const List<String> kDefaultInvitationMessages = <String>[
  '¡Presioná el botón para jugar!',
  '¿Te animás a los 10 segundos exactos?',
  '¡El que pega en 10.000s gana!',
];

/// Default sub-tagline shown under the main invitation message, rotated
/// every [kSubTaglineRotationSeconds] seconds. These are the "call to
/// action" lines designed to be read while the player is on the
/// waiting screen.
const List<String> kDefaultSubTaglines = <String>[
  '¡JUGÁ Y GANÁ EL PREMIO!',
  '¿PODÉS ROMPER EL RÉCORD?',
  '¿TENÉS HABILIDAD?',
  '¿SOS CAPAZ DEL RÉCORD?',
  '¡APUNTÁ AL 10 EXACTO!',
];

/// Typed wrapper around [SharedPreferences].
///
/// Instantiate once at app start (e.g. in `AppRoot.initState` via
/// `WidgetsBinding.instance.addPostFrameCallback`) and pass it down to
/// the screens that need to read or write config.
class ConfigStore {
  ConfigStore._(this._prefs);

  /// Future returned by [load] — resolve it before reading any value.
  static Future<ConfigStore> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return ConfigStore._(prefs);
  }

  final SharedPreferences _prefs;

  // ---------------------------------------------------------------------------
  // Keys — keep all string literals here, never inline them at call sites.
  // ---------------------------------------------------------------------------
  static const String kKeyInvitationMessages = 'invitation_messages';
  static const String kKeySubTaglines = 'sub_taglines';
  static const String kKeyMessageRotationSeconds = 'message_rotation_seconds';
  static const String kKeySubTaglineRotationSeconds =
      'sub_tagline_rotation_seconds';
  static const String kKeyLeaderboardRotationSeconds =
      'leaderboard_rotation_seconds';
  static const String kKeyBgColorArgb = 'bg_color_argb';
  static const String kKeyTextColorArgb = 'text_color_argb';
  static const String kKeyAccentColorArgb = 'accent_color_argb';
  static const String kKeyLeaderboard = 'leaderboard';
  static const String kKeyResultAutoReturnSeconds =
      'result_auto_return_seconds';
  static const String kKeyVictoryRangeStart = 'victory_range_start';
  static const String kKeyVictoryRangeEnd = 'victory_range_end';

  // ---------------------------------------------------------------------------
  // Invitation messages
  // ---------------------------------------------------------------------------

  /// Returns the configured invitation message list, falling back to
  /// [kDefaultInvitationMessages] when the pref is missing or corrupted.
  List<String> invitationMessages() {
    final String? raw = _prefs.getString(kKeyInvitationMessages);
    if (raw == null || raw.isEmpty) {
      return List<String>.unmodifiable(kDefaultInvitationMessages);
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is List) {
        final List<String> out = decoded
            .whereType<String>()
            .map((String s) => s.trim())
            .where((String s) => s.isNotEmpty)
            .toList();
        if (out.isNotEmpty) return List<String>.unmodifiable(out);
      }
    } on FormatException {
      // Corrupt JSON — fall through to defaults.
    }
    return List<String>.unmodifiable(kDefaultInvitationMessages);
  }

  Future<void> setInvitationMessages(List<String> messages) async {
    final List<String> cleaned = messages
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .toList();
    await _prefs.setString(
      kKeyInvitationMessages,
      jsonEncode(cleaned.isEmpty ? kDefaultInvitationMessages : cleaned),
    );
  }

  // ---------------------------------------------------------------------------
  // Sub-tagline (call to action, shown under the main invitation message)
  // ---------------------------------------------------------------------------

  /// Returns the configured sub-tagline list, falling back to
  /// [kDefaultSubTaglines] when the pref is missing or corrupted.
  List<String> subTaglines() {
    final String? raw = _prefs.getString(kKeySubTaglines);
    if (raw == null || raw.isEmpty) {
      return List<String>.unmodifiable(kDefaultSubTaglines);
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is List) {
        final List<String> out = decoded
            .whereType<String>()
            .map((String s) => s.trim())
            .where((String s) => s.isNotEmpty)
            .toList();
        if (out.isNotEmpty) return List<String>.unmodifiable(out);
      }
    } on FormatException {
      // fall through
    }
    return List<String>.unmodifiable(kDefaultSubTaglines);
  }

  Future<void> setSubTaglines(List<String> taglines) async {
    final List<String> cleaned = taglines
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .toList();
    await _prefs.setString(
      kKeySubTaglines,
      jsonEncode(cleaned.isEmpty ? kDefaultSubTaglines : cleaned),
    );
  }

  int subTaglineRotationSeconds() =>
      _prefs.getInt(kKeySubTaglineRotationSeconds) ?? 6;

  Future<void> setSubTaglineRotationSeconds(int seconds) =>
      _prefs.setInt(kKeySubTaglineRotationSeconds, seconds);

  // ---------------------------------------------------------------------------
  // Rotation intervals (seconds)
  // ---------------------------------------------------------------------------

  int messageRotationSeconds() =>
      _prefs.getInt(kKeyMessageRotationSeconds) ?? 30;

  Future<void> setMessageRotationSeconds(int seconds) =>
      _prefs.setInt(kKeyMessageRotationSeconds, seconds);

  int leaderboardRotationSeconds() =>
      _prefs.getInt(kKeyLeaderboardRotationSeconds) ??
      kMaxLeaderboardRotationSeconds;

  /// Persists the leaderboard rotation interval. The kiosk uses this
  /// value to decide how long to show the "Últimos ganadores" panel
  /// before rotating back to invitation messages. Must be in
  /// `[kMinLeaderboardRotationSeconds, kMaxLeaderboardRotationSeconds]`
  /// — anything else throws [ArgumentError] and leaves the pref
  /// untouched.
  Future<void> setLeaderboardRotationSeconds(int seconds) {
    if (seconds < kMinLeaderboardRotationSeconds ||
        seconds > kMaxLeaderboardRotationSeconds) {
      throw ArgumentError(
        'leaderboard rotation seconds must be between '
        '$kMinLeaderboardRotationSeconds and '
        '$kMaxLeaderboardRotationSeconds (got $seconds)',
      );
    }
    return _prefs.setInt(kKeyLeaderboardRotationSeconds, seconds);
  }

  // ---------------------------------------------------------------------------
  // RESULT screen auto-return
  // ---------------------------------------------------------------------------

  int resultAutoReturnSeconds() =>
      _prefs.getInt(kKeyResultAutoReturnSeconds) ??
      kDefaultResultAutoReturnSeconds;

  Future<void> setResultAutoReturnSeconds(int seconds) =>
      _prefs.setInt(kKeyResultAutoReturnSeconds, seconds);

  // ---------------------------------------------------------------------------
  // VICTORY verdict range — operator-tunable so the kiosk can be tested
  // with different windows without recompiling. Both bounds are inclusive;
  // `start` must be strictly less than `end` and both must be positive.
  // ---------------------------------------------------------------------------

  double victoryRangeStart() =>
      _prefs.getDouble(kKeyVictoryRangeStart) ?? kDefaultVictoryRangeStart;

  double victoryRangeEnd() =>
      _prefs.getDouble(kKeyVictoryRangeEnd) ?? kDefaultVictoryRangeEnd;

  /// Persists a new VICTORY verdict range. Throws [ArgumentError] when
  /// the bounds are not strictly ordered or are not strictly positive.
  /// Both writes go through; on validation failure no pref is mutated.
  Future<void> setVictoryRange({
    required double start,
    required double end,
  }) async {
    if (start <= 0 || end <= 0) {
      throw ArgumentError(
        'victory range bounds must be positive (got start=$start, end=$end)',
      );
    }
    if (start >= end) {
      throw ArgumentError(
        'victory range start must be strictly less than end '
        '(got start=$start, end=$end)',
      );
    }
    await _prefs.setDouble(kKeyVictoryRangeStart, start);
    await _prefs.setDouble(kKeyVictoryRangeEnd, end);
  }

  // ---------------------------------------------------------------------------
  // Colors (ARGB ints — `Color(0xAARRGGBB)`-compatible)
  // ---------------------------------------------------------------------------

  int bgColorArgb() =>
      _prefs.getInt(kKeyBgColorArgb) ?? kDefaultBgColorHex;
  int textColorArgb() =>
      _prefs.getInt(kKeyTextColorArgb) ?? kDefaultTextColorHex;
  int accentColorArgb() =>
      _prefs.getInt(kKeyAccentColorArgb) ?? kDefaultAccentColorHex;

  Future<void> setBgColorArgb(int argb) =>
      _prefs.setInt(kKeyBgColorArgb, argb);
  Future<void> setTextColorArgb(int argb) =>
      _prefs.setInt(kKeyTextColorArgb, argb);
  Future<void> setAccentColorArgb(int argb) =>
      _prefs.setInt(kKeyAccentColorArgb, argb);

  // ---------------------------------------------------------------------------
  // Leaderboard JSON
  // ---------------------------------------------------------------------------

  /// Returns the persisted leaderboard, falling back to an empty list
  /// when the pref is missing or JSON is corrupted.
  ///
  /// Errors are swallowed by design (spec requirement 4: "leaderboard
  /// JSON corruption → empty fallback"). The caller should not need to
  /// handle a try/catch at the UI layer.
  List<LeaderboardEntry> leaderboard() {
    final String? raw = _prefs.getString(kKeyLeaderboard);
    if (raw == null || raw.isEmpty) {
      return const <LeaderboardEntry>[];
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is List) {
        final List<LeaderboardEntry> out = <LeaderboardEntry>[];
        for (final Object? item in decoded) {
          if (item is Map<String, dynamic>) {
            out.add(LeaderboardEntry.fromJson(item));
          } else if (item is Map) {
            // `jsonDecode` returns `Map<String, dynamic>` on web but
            // may return `Map<dynamic, dynamic>` on some VMs — coerce.
            out.add(LeaderboardEntry.fromJson(
                item.cast<String, dynamic>()));
          }
        }
        return out;
      }
    } on FormatException {
      // Corrupt JSON — fall through to empty.
    } on TypeError {
      // Bad shape — fall through to empty.
    }
    return const <LeaderboardEntry>[];
  }

  Future<void> setLeaderboard(List<LeaderboardEntry> entries) async {
    final List<Map<String, dynamic>> payload =
        entries.map((LeaderboardEntry e) => e.toJson()).toList();
    await _prefs.setString(kKeyLeaderboard, jsonEncode(payload));
  }

  /// Wipes EVERY pref key. Used by the admin "Borrar base de datos"
  /// action. After this returns, the next read on any key returns the
  /// default (because the keys are gone).
  Future<void> clearAll() => _prefs.clear();
}
