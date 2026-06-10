/// Domain model for a single persisted leaderboard entry.
///
/// One entry is the result of one completed game:
///   * [name]      — the player's self-typed name (max 16 chars, post-trim).
///   * [timestamp] — wall-clock time of the win (DateTime, UTC).
///   * [rawSeconds]— the raw stopwatch reading (`elapsedMicroseconds / 1e6`).
///   * [delta]     — `rawSeconds - 10.0` (signed; sorting uses `.abs()`).
///
/// The class is `Comparable` by `delta.abs()` ascending — i.e. the closer
/// to 10.000s, the better. This is the ordering the spec uses to display
/// the "top winners" panel.
library;

import 'dart:convert';

class LeaderboardEntry implements Comparable<LeaderboardEntry> {
  LeaderboardEntry({
    required this.name,
    required this.timestamp,
    required this.rawSeconds,
    required this.delta,
  });

  final String name;
  final DateTime timestamp;
  final double rawSeconds;
  final double delta;

  /// Returns the absolute error vs the 10.000s target. Smallest is best.
  double get deltaAbs => delta.abs();

  /// Lower `deltaAbs` sorts first (best score first).
  @override
  int compareTo(LeaderboardEntry other) {
    return deltaAbs.compareTo(other.deltaAbs);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        // ISO-8601 keeps the wall-clock time human-readable in the JSON
        // and round-trips cleanly through `DateTime.parse`.
        'timestamp': timestamp.toUtc().toIso8601String(),
        'rawSeconds': rawSeconds,
        'delta': delta,
      };

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    final Object? tsRaw = json['timestamp'];
    final DateTime ts;
    if (tsRaw is String) {
      ts = DateTime.parse(tsRaw);
    } else if (tsRaw is int) {
      // Backwards-compat: older shapes may have stored a Unix epoch.
      ts = DateTime.fromMillisecondsSinceEpoch(tsRaw, isUtc: true);
    } else {
      ts = DateTime.now().toUtc();
    }
    return LeaderboardEntry(
      name: (json['name'] as String?) ?? 'ANONIMO',
      timestamp: ts,
      rawSeconds: (json['rawSeconds'] as num).toDouble(),
      delta: (json['delta'] as num).toDouble(),
    );
  }

  /// Convenience for tests and `jsonEncode` pipelines.
  String encode() => jsonEncode(toJson());

  /// Convenience inverse of [encode]. Throws on malformed input — callers
  /// that need to fall back to an empty list should wrap in try/catch.
  factory LeaderboardEntry.decode(String source) {
    final Object? raw = jsonDecode(source);
    if (raw is! Map<String, dynamic>) {
      throw const FormatException(
        'LeaderboardEntry.decode expected a JSON object',
      );
    }
    return LeaderboardEntry.fromJson(raw);
  }

  @override
  String toString() =>
      'LeaderboardEntry(name: $name, rawSeconds: ${rawSeconds.toStringAsFixed(4)}, '
      'delta: ${delta.toStringAsFixed(4)})';
}
