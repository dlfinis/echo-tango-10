/// Constants and visual defaults for the Arcade Timer 10s kiosk.
///
/// All numeric/color defaults live here so they are easy to find, easy to
/// reference in tests, and easy to swap (eventually from the admin panel)
/// without scattering magic values across the codebase.
library;

/// Hex helper: turn an `#RRGGBB` string into a `Color`-compatible 0xAARRGGBB int.
int hexFromString(String hex) {
  var clean = hex.replaceAll('#', '').trim();
  if (clean.length == 6) clean = 'FF$clean';
  return int.parse(clean, radix: 16);
}

// ---------------------------------------------------------------------------
// Color palette defaults (see spec requirement 4)
// ---------------------------------------------------------------------------

/// Default background color (`#121212`).
const int kDefaultBgColorHex = 0xFF121212;

/// Default text color (`#FFFFFF`).
const int kDefaultTextColorHex = 0xFFFFFFFF;

/// Default accent / victory color (`#00FF00`).
const int kDefaultAccentColorHex = 0xFF00FF00;

// ---------------------------------------------------------------------------
// Invitation loop timing (see spec requirement 5)
// ---------------------------------------------------------------------------

/// How long a single invitation message is shown before rotating.
const Duration kMessageRotationInterval = Duration(seconds: 30);

/// How long the leaderboard view is shown before rotating back to messages.
const Duration kLeaderboardRotationInterval = Duration(seconds: 300);

// ---------------------------------------------------------------------------
// Gameplay timing & tolerance (see spec requirements 1, 3, 6)
// ---------------------------------------------------------------------------

/// Target stopwatch value. Players try to land exactly this.
const double kTargetSeconds = 10.0;

/// Maximum allowed PLAYING duration before auto-reset to WAITING.
const Duration kPlayingTimeout = Duration(seconds: 60);

/// Debounce window for any input pulse (mechanical bounce suppression).
const Duration kDebounceWindow = Duration(milliseconds: 200);

/// |delta| strictly below this counts as a victory (enters WINNER_NAME).
///
/// Asymmetric rule: a player wins if `elapsed >= kTargetSeconds` AND
/// `elapsed <= kTargetSeconds + kVictoryOvershootSeconds` (i.e. they
/// hit 10.0000s or overshot by at most 1.9 ms). Coming in SHORT
/// (elapsed < 10.0000s) is always a miss — the game punishes hesitation,
/// not slop on the late side.
const double kVictoryOvershootSeconds = 0.0019;

/// Backward-compatible alias. The active rule is asymmetric (see above);
/// this constant is kept only so older call sites that read
/// `|delta| < kVictoryToleranceSeconds` still type-check. AppRoot
/// must NOT rely on it — it must use [isVictory] from the spec contract.
const double kVictoryToleranceSeconds = kVictoryOvershootSeconds;

/// |delta| above which the result is no longer "CASI" but "UPS"
/// (the player was so far off that it's clearly a miss, not a
/// near-miss). Set to 100 ms — the player can hear/feel a 100 ms
/// discrepancy, so anything looser than that doesn't deserve the
/// encouragement of "casi". Below this threshold and above
/// [kVictoryOvershootSeconds] the screen shows CASI.
const double kNearMissUpperBoundSeconds = 0.100;

/// Exact zero-delta easter-egg threshold (raw microsecond comparison).
const double kEasterEggToleranceSeconds = 0.000001;

// ---------------------------------------------------------------------------
// Admin / UX
// ---------------------------------------------------------------------------

/// Long-press duration required to open the admin panel from the gear icon.
const Duration kAdminLongPressDuration = Duration(seconds: 3);

/// Hard cap on persisted leaderboard entries.
const int kMaxLeaderboardEntries = 20;

// ---------------------------------------------------------------------------
// PLAYING screen visual rhythm
// ---------------------------------------------------------------------------

/// How often the playing-screen timer color cycles through the palette.
/// Color rotation is disabled (we now use a single static color), but
/// the constant is kept for backwards compatibility with code that
/// still references the palette length.
const Duration kPlayingColorShiftInterval = Duration(seconds: 3);

/// Color rotation for the live stopwatch digits. Diego asked for the
/// digits to be a single static color during PLAYING (no flashing),
/// so the screen reads as 'calm and focused' instead of 'busy'.
const List<int> kPlayingColorPaletteHex = <int>[
  0xFFFFFFFF, // white — only color used during PLAYING
];

/// Static digit color for the live stopwatch. Same as the first
/// entry in [kPlayingColorPaletteHex], kept as its own constant for
/// readability at the call site.
const int kPlayingDigitColorHex = 0xFFFFFFFF;
