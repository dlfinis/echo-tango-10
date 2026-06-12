// PR2 tests for the pure persistence layer.
//
// Coverage:
//   * LeaderboardEntry: JSON round-trip, compareTo ordering, decode guard.
//   * ConfigStore: defaults on a fresh install, JSON-corruption fallback,
//     write/read round-trip, clear() wipes everything.
//   * Leaderboard: sort + cap, top() clamping, clear().

import 'dart:convert';

import 'package:arcade_timer_10s/models/leaderboard_entry.dart';
import 'package:arcade_timer_10s/services/config_store.dart';
import 'package:arcade_timer_10s/services/leaderboard.dart';
import 'package:arcade_timer_10s/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

LeaderboardEntry _entry({
  String name = 'ANONIMO',
  double rawSeconds = 10.0,
  double delta = 0.0,
  DateTime? ts,
}) {
  return LeaderboardEntry(
    name: name,
    timestamp: ts ?? DateTime.utc(2026, 1, 1),
    rawSeconds: rawSeconds,
    delta: delta,
  );
}

void main() {
  setUp(() {
    // Reset the in-memory mock before every test so pref state does
    // NOT leak across cases.
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('LeaderboardEntry', () {
    test('toJson/fromJson round-trips losslessly', () {
      final original = _entry(
        name: 'Diego',
        rawSeconds: 10.0023,
        delta: 0.0023,
        ts: DateTime.utc(2026, 6, 9, 12, 34, 56),
      );
      final copy = LeaderboardEntry.fromJson(original.toJson());
      expect(copy.name, original.name);
      expect(copy.rawSeconds, original.rawSeconds);
      expect(copy.delta, original.delta);
      expect(copy.timestamp.toUtc(), original.timestamp.toUtc());
    });

    test('encode/decode round-trips through a JSON string', () {
      final original = _entry(name: 'ANA', rawSeconds: 9.9977, delta: -0.0023);
      final copy = LeaderboardEntry.decode(original.encode());
      expect(copy.name, 'ANA');
      expect(copy.rawSeconds, closeTo(9.9977, 1e-9));
    });

    test('compareTo orders by |delta| ascending', () {
      final a = _entry(name: 'A', delta: 0.0050);
      final b = _entry(name: 'B', delta: -0.0020);
      final c = _entry(name: 'C', delta: 0.0100);
      final list = <LeaderboardEntry>[a, c, b]..sort();
      expect(list.map((e) => e.name).toList(), <String>['B', 'A', 'C']);
    });

    test('fromJson tolerates missing name field', () {
      final copy = LeaderboardEntry.fromJson(<String, dynamic>{
        'timestamp': DateTime.utc(2026).toIso8601String(),
        'rawSeconds': 10.0,
        'delta': 0.0,
      });
      expect(copy.name, 'ANONIMO');
    });
  });

  group('ConfigStore (defaults)', () {
    test('returns defaults on a fresh install', () async {
      final store = await ConfigStore.load();
      expect(store.invitationMessages(), kDefaultInvitationMessages);
      expect(store.messageRotationSeconds(), 30);
      expect(store.leaderboardRotationSeconds(), 15);
      expect(store.bgColorArgb(), kDefaultBgColorHex);
      expect(store.textColorArgb(), kDefaultTextColorHex);
      expect(store.accentColorArgb(), kDefaultAccentColorHex);
      expect(store.leaderboard(), isEmpty);
    });
  });

  group('ConfigStore (persistence)', () {
    test('setInvitationMessages + read round-trips', () async {
      final store = await ConfigStore.load();
      await store.setInvitationMessages(<String>['Hola', 'Mundo']);
      expect(store.invitationMessages(), <String>['Hola', 'Mundo']);
    });

    test('setInvitationMessages drops empty strings', () async {
      final store = await ConfigStore.load();
      await store.setInvitationMessages(<String>['A', '', '  ', 'B']);
      expect(store.invitationMessages(), <String>['A', 'B']);
    });

    test('setInvitationMessages restores defaults on empty input', () async {
      final store = await ConfigStore.load();
      await store.setInvitationMessages(<String>['', '  ']);
      expect(store.invitationMessages(), kDefaultInvitationMessages);
    });

    test('rotation interval setters persist', () async {
      final store = await ConfigStore.load();
      await store.setMessageRotationSeconds(45);
      await store.setLeaderboardRotationSeconds(15);
      expect(store.messageRotationSeconds(), 45);
      expect(store.leaderboardRotationSeconds(), 15);
    });

    test('color setters persist', () async {
      final store = await ConfigStore.load();
      await store.setBgColorArgb(0xFF203040);
      await store.setTextColorArgb(0xFFE0E0E0);
      await store.setAccentColorArgb(0xFFFF8800);
      expect(store.bgColorArgb(), 0xFF203040);
      expect(store.textColorArgb(), 0xFFE0E0E0);
      expect(store.accentColorArgb(), 0xFFFF8800);
    });

    test('leaderboard round-trips through JSON', () async {
      final store = await ConfigStore.load();
      await store.setLeaderboard(<LeaderboardEntry>[
        _entry(name: 'A', rawSeconds: 10.005, delta: 0.005),
        _entry(name: 'B', rawSeconds: 9.997, delta: -0.003),
      ]);
      final back = store.leaderboard();
      // setLeaderboard is a raw write — the sort happens in
      // Leaderboard.add(). The JSON round-trip preserves input order.
      expect(back, hasLength(2));
      expect(back[0].name, 'A');
      expect(back[1].name, 'B');
      expect(back[0].rawSeconds, closeTo(10.005, 1e-9));
      expect(back[1].rawSeconds, closeTo(9.997, 1e-9));
    });

    test('leaderboard returns empty list on JSON corruption', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        ConfigStore.kKeyLeaderboard: 'not-json{',
      });
      final store = await ConfigStore.load();
      expect(store.leaderboard(), isEmpty);
    });

    test('invitation messages fall back to defaults on JSON corruption',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        ConfigStore.kKeyInvitationMessages: '{not-a-list',
      });
      final store = await ConfigStore.load();
      expect(store.invitationMessages(), kDefaultInvitationMessages);
    });

    test('clearAll wipes every key', () async {
      final store = await ConfigStore.load();
      await store.setMessageRotationSeconds(99);
      await store.setAccentColorArgb(0xFFAA00CC);
      await store.clearAll();
      // Defaults restored after clear.
      expect(store.messageRotationSeconds(), 30);
      expect(store.accentColorArgb(), kDefaultAccentColorHex);
    });
  });

  group('Leaderboard', () {
    test('top(n) returns at most n entries, best first', () async {
      final store = await ConfigStore.load();
      final lb = Leaderboard(store);
      await lb.add(_entry(name: 'Worst', delta: 0.5));
      await lb.add(_entry(name: 'Best', delta: 0.001));
      await lb.add(_entry(name: 'Mid', delta: 0.05));

      final top3 = lb.top(3);
      expect(top3.map((e) => e.name).toList(), <String>['Best', 'Mid', 'Worst']);
    });

    test('add caps the leaderboard at kMaxLeaderboardEntries', () async {
      final store = await ConfigStore.load();
      final lb = Leaderboard(store);

      // Add 25 entries, all with a unique delta so the sort is stable.
      for (int i = 0; i < 25; i++) {
        await lb.add(_entry(
          name: 'P$i',
          delta: (i + 1) * 0.001, // 0.001..0.025
        ));
      }
      expect(lb.length, kMaxLeaderboardEntries);
      // The worst 5 should have been trimmed.
      final top = lb.top(kMaxLeaderboardEntries);
      expect(top.first.name, 'P0'); // delta 0.001 — best
      expect(top.last.name, 'P19'); // delta 0.020 — last surviving
    });

    test('top(n) clamps to current length and to the cap', () async {
      final store = await ConfigStore.load();
      final lb = Leaderboard(store);
      await lb.add(_entry(name: 'Only', delta: 0.01));

      expect(lb.top(0), isEmpty);
      expect(lb.top(5), hasLength(1));
    });

    test('clear() empties the leaderboard', () async {
      final store = await ConfigStore.load();
      final lb = Leaderboard(store);
      await lb.add(_entry(name: 'X', delta: 0.1));
      expect(lb.length, 1);
      await lb.clear();
      expect(lb.length, 0);
    });

    test('top() is unmodifiable — mutating it throws', () async {
      final store = await ConfigStore.load();
      final lb = Leaderboard(store);
      await lb.add(_entry(name: 'A', delta: 0.01));
      final list = lb.top(1);
      expect(() => list.add(_entry(name: 'B', delta: 0.02)),
          throwsUnsupportedError);
    });

    test('decode survives a JSON-typed map (web casts)', () async {
      // jsonDecode on web can return Map<dynamic, dynamic> in some cases.
      // The service must coerce and still produce a valid list.
      SharedPreferences.setMockInitialValues(<String, Object>{
        ConfigStore.kKeyLeaderboard: jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'Z',
            'timestamp': DateTime.utc(2026).toIso8601String(),
            'rawSeconds': 10.0,
            'delta': 0.0,
          },
        ]),
      });
      final store = await ConfigStore.load();
      final lb = Leaderboard(store);
      expect(lb.top(5), hasLength(1));
    });
  });
}
