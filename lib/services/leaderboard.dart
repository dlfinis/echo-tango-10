/// In-memory + persisted leaderboard, capped and pre-sorted.
///
/// All public methods are async because the persistence layer
/// ([ConfigStore]) writes through `shared_preferences`, which is
/// asynchronous. Reads are sync-ish: `top()` reads the latest snapshot
/// from [ConfigStore], so callers that need the freshest state should
/// re-read after an `await add()`.
library;

import 'dart:async';

import '../models/leaderboard_entry.dart';
import '../utils/constants.dart';
import 'config_store.dart';

/// Leaderboard facade. Persists via [ConfigStore].
class Leaderboard {
  Leaderboard(this._store);

  final ConfigStore _store;

  /// Appends [entry] to the persisted list, re-sorts by `delta.abs()`
  /// ascending, and trims to [kMaxLeaderboardEntries].
  ///
  /// The trimmed tail is the worst entries — the top [kMaxLeaderboardEntries]
  /// always survive. The future completes after the write to disk.
  Future<void> add(LeaderboardEntry entry) async {
    final List<LeaderboardEntry> all = List<LeaderboardEntry>.from(
      _store.leaderboard(),
    )..add(entry);
    all.sort();
    final int keep = all.length < kMaxLeaderboardEntries
        ? all.length
        : kMaxLeaderboardEntries;
    await _store.setLeaderboard(all.sublist(0, keep));
  }

  /// Returns the top [n] entries (best first). [n] is clamped to the
  /// current entry count and to [kMaxLeaderboardEntries].
  List<LeaderboardEntry> top(int n) {
    final List<LeaderboardEntry> all = List<LeaderboardEntry>.from(
      _store.leaderboard(),
    );
    all.sort();
    if (n < 0) n = 0;
    if (n > all.length) n = all.length;
    if (n > kMaxLeaderboardEntries) n = kMaxLeaderboardEntries;
    return List<LeaderboardEntry>.unmodifiable(all.sublist(0, n));
  }

  /// Wipes the persisted leaderboard.
  Future<void> clear() => _store.setLeaderboard(const <LeaderboardEntry>[]);

  /// Returns the current entry count (for the admin "X entradas" label).
  int get length => _store.leaderboard().length;
}
