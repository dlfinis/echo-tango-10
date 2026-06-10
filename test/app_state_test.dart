// PR1 smoke tests for the pure pieces of the state machine.
//
// These tests are intentionally minimal: the goal is to prove the file
// compiles in CI and to lock the spec's transition table from day one.
// Heavier coverage (Leaderboard, ConfigStore, widget integration) lands
// alongside the PR2 features they exercise.

import 'package:arcade_timer_10s/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppState.next', () {
    test('WAITING + pulse → PLAYING', () {
      expect(next(AppState.waiting, TimerEvent.pulse), AppState.playing);
    });

    test('PLAYING + pulse → RESULT', () {
      expect(next(AppState.playing, TimerEvent.pulse), AppState.result);
    });

    test('PLAYING + timeout → WAITING', () {
      expect(next(AppState.playing, TimerEvent.timeout), AppState.waiting);
    });

    test('RESULT + pulse (non-victory) → WAITING', () {
      expect(
        next(AppState.result, TimerEvent.pulse, isVictory: false),
        AppState.waiting,
      );
    });

    test('RESULT + pulse (victory) → WINNER_NAME', () {
      expect(
        next(AppState.result, TimerEvent.pulse, isVictory: true),
        AppState.winnerName,
      );
    });

    test('WAITING + adminGesture → ADMIN', () {
      expect(
        next(AppState.waiting, TimerEvent.adminGesture),
        AppState.admin,
      );
    });

    test('ADMIN + exitAdmin → WAITING', () {
      expect(next(AppState.admin, TimerEvent.exitAdmin), AppState.waiting);
    });

    test('WINNER_NAME + acceptWinner → WAITING', () {
      expect(
        next(AppState.winnerName, TimerEvent.acceptWinner),
        AppState.waiting,
      );
    });

    test('unrelated events do not change state', () {
      expect(
        next(AppState.playing, TimerEvent.adminGesture),
        AppState.playing,
      );
      expect(
        next(AppState.waiting, TimerEvent.timeout),
        AppState.waiting,
      );
    });
  });
}
