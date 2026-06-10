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
/// hit 10.000s or overshot by at most 10 ms). Coming in SHORT
/// (elapsed < 10.000s) is always a miss — the game punishes hesitation,
/// not slop on the late side.
const double kVictoryOvershootSeconds = 0.010;

/// Backward-compatible alias. The active rule is asymmetric (see above);
/// this constant is kept only so older call sites that read
/// `|delta| < kVictoryToleranceSeconds` still type-check. AppRoot
/// must NOT rely on it — it must use [isVictory] from the spec contract.
const double kVictoryToleranceSeconds = kVictoryOvershootSeconds;

/// Exact zero-delta easter-egg threshold (raw microsecond comparison).
const double kEasterEggToleranceSeconds = 0.000001;

// ---------------------------------------------------------------------------
// Admin / UX
// ---------------------------------------------------------------------------

/// Long-press duration required to open the admin panel from the gear icon.
const Duration kAdminLongPressDuration = Duration(seconds: 3);

/// Hard cap on persisted leaderboard entries.
const int kMaxLeaderboardEntries = 20;
