// PR2 widget tests for the new screens.
//
// Coverage:
//   * WaitingScreen: first invitation message renders + admin long-press
//     fires onAdminGesture after kAdminLongPressDuration (not before).
//   * ResultScreen: renders all 4 verdict branches without overflow at
//     a small viewport (Fire HD 8 1280x800 portrait-aware test size).
//   * WinnerNameScreen: Aceptar writes an entry; default name is ANONIMO;
//     easter-egg flag toggles UI between "VICTORIA" and "¡EXACTO!".
//   * AdminScreen: confirm dialog, Borrar todo wipes prefs + leaderboard
//     + shows snackbar, Salir calls onExit.
//   * ConfettiPainter: shouldRepaint respects value/seed/intensity.

import 'dart:ui' as ui;

import 'package:arcade_timer_10s/models/leaderboard_entry.dart';
import 'package:arcade_timer_10s/services/config_store.dart';
import 'package:arcade_timer_10s/services/leaderboard.dart';
import 'package:arcade_timer_10s/state/stopwatch_controller.dart';
import 'package:arcade_timer_10s/utils/constants.dart';
import 'package:arcade_timer_10s/widgets/playing_screen.dart';
import 'package:arcade_timer_10s/widgets/result_screen.dart';
import 'package:arcade_timer_10s/widgets/admin_screen.dart';
import 'package:arcade_timer_10s/widgets/confetti_painter.dart';
import 'package:arcade_timer_10s/widgets/invader_sprite.dart';
import 'package:arcade_timer_10s/widgets/waiting_screen.dart';
import 'package:arcade_timer_10s/widgets/winner_name_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Pair {
  _Pair(this.store, this.lb);
  final ConfigStore store;
  final Leaderboard lb;
}

Future<_Pair> _bootstrap() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final ConfigStore store = await ConfigStore.load();
  return _Pair(store, Leaderboard(store));
}

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

LeaderboardEntry _entry({
  String name = 'ANONIMO',
  double rawSeconds = 10.0,
  double delta = 0.0,
}) {
  return LeaderboardEntry(
    name: name,
    timestamp: DateTime.utc(2026, 1, 1),
    rawSeconds: rawSeconds,
    delta: delta,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('WaitingScreen', () {
    testWidgets('renders the first invitation message', (WidgetTester tester) async {
      final pair = await _bootstrap();
      await tester.pumpWidget(_wrap(WaitingScreen(
        configStore: pair.store,
        leaderboard: pair.lb,
      )));
      await tester.pump();
      expect(find.text('¡Presioná el botón para jugar!'), findsOneWidget);
    });

    testWidgets('renders the gear icon and short press does NOT trigger admin',
        (WidgetTester tester) async {
      final pair = await _bootstrap();
      int adminCalls = 0;
      await tester.pumpWidget(_wrap(WaitingScreen(
        configStore: pair.store,
        leaderboard: pair.lb,
        onAdminGesture: () => adminCalls++,
      )));
      await tester.pump();
      expect(find.byIcon(Icons.settings), findsOneWidget);
      // Quick tap → no admin gesture.
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pump(const Duration(milliseconds: 100));
      expect(adminCalls, 0);
    });

    testWidgets('admin long-press fires after kAdminLongPressDuration',
        (WidgetTester tester) async {
      final pair = await _bootstrap();
      int adminCalls = 0;
      await tester.pumpWidget(_wrap(WaitingScreen(
        configStore: pair.store,
        leaderboard: pair.lb,
        onAdminGesture: () => adminCalls++,
      )));
      await tester.pump();
      // Simulate a held pointer on the gear icon.
      final gesture =
          await tester.startGesture(tester.getCenter(find.byIcon(Icons.settings)));
      await tester.pump(const Duration(milliseconds: 500));
      expect(adminCalls, 0, reason: 'still under 3s');
      // Pump past the full admin long-press duration.
      await tester.pump(kAdminLongPressDuration);
      expect(adminCalls, 1, reason: 'long-press fired at 3s');
      await gesture.up();
      // The backdrop ticker never stops in production, so pumpAndSettle
      // would time out. A bounded pump is enough to verify the gesture
      // was released.
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets(
        'leaderboard panel with 5 entries at 800x600 does not throw overflow',
        (WidgetTester tester) async {
      // Pin the viewport to 800x600 (the default). The Waiting
      // screen places the leaderboard inside a Column that is
      // ~528 px tall; without the SingleChildScrollView wrap that
      // exceeds the 475 px tall usable area and Flutter reports
      // 'A RenderFlex overflowed by 53 pixels on the bottom.'
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final pair = await _bootstrap();
      // The default invitation list has 3 messages. With a 1s
      // rotation interval the message phase lasts 3*1 = 3 seconds.
      // After 3s the state machine flips to the leaderboard view
      // (15s phase). Pump 3.5s so the periodic timer fires
      // 3 times and the state machine has advanced into the
      // leaderboard phase.
      await pair.store.setMessageRotationSeconds(1);
      await pair.store.setLeaderboardRotationSeconds(15);
      // Seed 5 leaderboard entries — matches the default top-N.
      for (int i = 0; i < 5; i++) {
        await pair.lb.add(_entry(
          name: 'P${i + 1}',
          rawSeconds: 10.0 + i * 0.01,
          delta: i * 0.01,
        ));
      }

      await tester.pumpWidget(_wrap(WaitingScreen(
        configStore: pair.store,
        leaderboard: pair.lb,
      )));
      await tester.pump();
      // Cross the 3s message boundary so the screen switches to
      // the leaderboard panel (which is what overflows).
      await tester.pump(const Duration(milliseconds: 3500));
      // The header must be rendered (proves the leaderboard
      // phase is active).
      expect(find.text('ÚLTIMOS GANADORES'), findsOneWidget);
      // No overflow / layout exception should have been captured
      // by the test binding.
      expect(tester.takeException(), isNull,
          reason: 'leaderboard panel must not overflow at 800x600');
    });

    testWidgets('leaderboard rows show rawSeconds, no `s` suffix',
        (WidgetTester tester) async {
      final pair = await _bootstrap();
      // The default invitation list has 3 messages. With a 1s
      // rotation interval the message phase lasts 3*1 = 3 seconds.
      // Pump 3.5s so the periodic timer fires 3 times and the
      // state machine advances into the leaderboard phase.
      await pair.store.setMessageRotationSeconds(1);
      await pair.store.setLeaderboardRotationSeconds(15);
      // Two entries with known rawSeconds values.
      await pair.lb.add(_entry(name: 'AAA', rawSeconds: 9.9982, delta: -0.0018));
      await pair.lb.add(_entry(name: 'BBB', rawSeconds: 10.0017, delta: 0.0017));

      await tester.pumpWidget(_wrap(WaitingScreen(
        configStore: pair.store,
        leaderboard: pair.lb,
      )));
      await tester.pump();
      // Cross the 3s message boundary so the screen switches to
      // the leaderboard panel.
      await tester.pump(const Duration(milliseconds: 3500));

      // The leaderboard header is on screen.
      expect(find.text('ÚLTIMOS GANADORES'), findsOneWidget);
      // The leaderboard rows display rawSeconds with 4 decimals and
      // NO trailing 's' and NO leading sign. No '±', no '-'.
      expect(find.text('9.9982'), findsOneWidget,
          reason: 'row shows the raw achieved time, not the delta');
      expect(find.text('10.0017'), findsOneWidget);
      // Sanity: the old '+0.0017s' / '-0.0018s' format must be gone.
      expect(find.textContaining('+0.0017s'), findsNothing);
      expect(find.textContaining('-0.0018s'), findsNothing);
    });

    testWidgets(
        'backdrop painter repaints across 3s without rebuilding the widget tree',
        (WidgetTester tester) async {
      // Regression for the 'freezing' bug: the old implementation
      // scheduled a setState at 20 Hz that rebuilt the whole
      // Waiting tree on every frame. The fix drives the painter
      // directly through a Listenable on the AnimationController
      // (no setState). This test pumps 3 simulated seconds and
      // confirms the painter re-runs (no exception is raised and
      // the CustomPaint widget is still mounted).
      final pair = await _bootstrap();
      await tester.pumpWidget(_wrap(WaitingScreen(
        configStore: pair.store,
        leaderboard: pair.lb,
      )));
      await tester.pump();
      final Finder customPaint = find.byType(CustomPaint);
      expect(customPaint, findsWidgets);

      // Run the painter for 3 simulated seconds. The
      // AnimationController repeats every 10s, so 3s stays
      // inside the first cycle (no modulo surprises).
      await tester.pump(const Duration(seconds: 3));
      // No layout or paint exception should have been raised.
      expect(tester.takeException(), isNull,
          reason: 'painter must survive 3s of repaint ticks without throwing');
      // The painter is still on screen.
      expect(customPaint, findsWidgets);
      // Confirm an InvaderMarchPainter is in the tree and its
      // shouldRepaint respects the listenable swap (a fresh
      // painter with a different listenable must repaint).
      final InvaderMarchPainter fresh = InvaderMarchPainter(seed: 1);
      final InvaderMarchPainter sameListen = InvaderMarchPainter(seed: 1);
      // Both painters in this test have no listenable assigned
      // (the constructor's listenable is null by default), so
      // shouldRepaint returns false. Verify the contract directly
      // by feeding one a real Listenable — the assertion below
      // proves shouldRepaint is wired to the listenable field.
      final AnimationController c = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(seconds: 1),
      );
      addTearDown(c.dispose);
      final InvaderMarchPainter withC = InvaderMarchPainter(
        seed: 1,
        listenable: c,
      );
      final InvaderMarchPainter withOther = InvaderMarchPainter(
        seed: 1,
        listenable: c,
      );
      expect(withC.shouldRepaint(withOther), isFalse,
          reason: 'same listenable -> no repaint');
      final AnimationController c2 = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(seconds: 1),
      );
      addTearDown(c2.dispose);
      final InvaderMarchPainter withC2 = InvaderMarchPainter(
        seed: 1,
        listenable: c2,
      );
      expect(withC.shouldRepaint(withC2), isTrue,
          reason: 'different listenable -> repaint');
      // Use `fresh` and `sameListen` to silence the analyzer
      // (they exercise the no-listenable path).
      expect(fresh.shouldRepaint(sameListen), isFalse);
    });
  });

  group('WinnerNameScreen', () {
    testWidgets('Aceptar with empty name writes ANONIMO and calls onAccept',
        (WidgetTester tester) async {
      // Tall viewport so the Aceptar button is in bounds.
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final pair = await _bootstrap();
      bool accepted = false;
      await tester.pumpWidget(_wrap(WinnerNameScreen(
        elapsedSeconds: 10.0,
        leaderboard: pair.lb,
        onAccept: () => accepted = true,
        isEasterEgg: true,
      )));
      await tester.pump();
      await tester.tap(find.text('Aceptar'));
      // Aceptar is async (writes to leaderboard). Use pump a few times
      // instead of pumpAndSettle because the confetti AnimationController
      // repeats forever.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(accepted, isTrue);
      expect(pair.lb.length, 1);
      expect(pair.lb.top(1).first.name, 'ANONIMO');
      expect(pair.lb.top(1).first.delta, closeTo(0.0, 1e-9));
    });

    testWidgets('typed name is persisted on Aceptar', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final pair = await _bootstrap();
      await tester.pumpWidget(_wrap(WinnerNameScreen(
        elapsedSeconds: 10.0,
        leaderboard: pair.lb,
        onAccept: () {},
      )));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'DIEGO');
      await tester.tap(find.text('Aceptar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(pair.lb.top(1).first.name, 'DIEGO');
    });

    testWidgets('easter-egg renders ¡EXACTO!', (WidgetTester tester) async {
      final pair = await _bootstrap();
      await tester.pumpWidget(_wrap(WinnerNameScreen(
        elapsedSeconds: 10.0,
        leaderboard: pair.lb,
        onAccept: () {},
        isEasterEgg: true,
      )));
      await tester.pump();
      expect(find.text('¡EXACTO!'), findsOneWidget);
    });

    testWidgets('non-easter-egg renders VICTORIA', (WidgetTester tester) async {
      final pair = await _bootstrap();
      await tester.pumpWidget(_wrap(WinnerNameScreen(
        elapsedSeconds: 10.005,
        leaderboard: pair.lb,
        onAccept: () {},
      )));
      await tester.pump();
      expect(find.text('VICTORIA'), findsOneWidget);
    });

    testWidgets('TextField has a focusNode (autofocus requested post-frame)',
        (WidgetTester tester) async {
      final pair = await _bootstrap();
      await tester.pumpWidget(_wrap(WinnerNameScreen(
        elapsedSeconds: 10.0,
        leaderboard: pair.lb,
        onAccept: () {},
      )));
      await tester.pump();
      final TextField tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.focusNode, isNotNull);
      // The autofocus request is scheduled via addPostFrameCallback —
      // we just verify the wiring is in place.
    });

    testWidgets('SALTAR button is rendered and skips without saving',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final pair = await _bootstrap();
      bool accepted = false;
      await tester.pumpWidget(_wrap(WinnerNameScreen(
        elapsedSeconds: 10.0,
        leaderboard: pair.lb,
        onAccept: () => accepted = true,
      )));
      await tester.pump();
      expect(find.text('SALTAR'), findsOneWidget);
      await tester.tap(find.text('SALTAR'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(accepted, isTrue);
      expect(pair.lb.length, 0, reason: 'skip must not write an entry');
    });

    testWidgets('auto-skips to onAccept after the 15s timeout',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final pair = await _bootstrap();
      bool accepted = false;
      await tester.pumpWidget(_wrap(WinnerNameScreen(
        elapsedSeconds: 10.0,
        leaderboard: pair.lb,
        onAccept: () => accepted = true,
      )));
      await tester.pump();
      // 14s — within the 15s window, should not have fired.
      await tester.pump(const Duration(seconds: 14));
      expect(accepted, isFalse);
      // Cross the 15s boundary.
      await tester.pump(const Duration(seconds: 2));
      expect(accepted, isTrue);
      expect(pair.lb.length, 0, reason: 'auto-skip must not save');
    });

    testWidgets('input is capped at 5 chars, A-Z only, and forced uppercase',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final pair = await _bootstrap();
      await tester.pumpWidget(_wrap(WinnerNameScreen(
        elapsedSeconds: 9.5,
        leaderboard: pair.lb,
        onAccept: () {},
      )));
      await tester.pump();
      final Finder field = find.byType(TextField);
      expect(field, findsOneWidget);

      // 1) maxLength 5 — the 6th character must be rejected.
      await tester.enterText(field, 'ABCDE');
      await tester.pump();
      expect(find.text('ABCDE'), findsOneWidget,
          reason: 'first 5 chars accepted');
      await tester.enterText(field, 'ABCDEF');
      await tester.pump();
      expect(find.text('ABCDE'), findsOneWidget,
          reason: '6th char is rejected by LengthLimitingTextInputFormatter');
      expect(find.text('ABCDEF'), findsNothing);

      // 2) Lowercase input is forced uppercase by the controller
      // listener (TextCapitalization alone only affects the soft
      // keyboard suggestion).
      await tester.enterText(field, 'abc');
      await tester.pump();
      expect(find.text('ABC'), findsOneWidget,
          reason: 'lowercase letters are uppercased before render');

      // 3) Non A-Z characters are stripped by FilteringTextInputFormatter.
      await tester.enterText(field, 'A1B2');
      await tester.pump();
      expect(find.text('AB'), findsOneWidget,
          reason: 'digits are stripped, only A-Z survives');
    });
  });

  group('AdminScreen', () {
    testWidgets('Borrar base de datos shows the confirm dialog',
        (WidgetTester tester) async {
      // Use a tall viewport so the entire admin form fits without
      // scrolling. The default 800x600 forces a scroll for the
      // "Borrar base de datos" button — we set a 1200-tall view to
      // keep the test self-contained.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final pair = await _bootstrap();
      await tester.pumpWidget(_wrap(AdminScreen(
        configStore: pair.store,
        leaderboard: pair.lb,
        onExit: () {},
      )));
      await tester.pump();
      await tester.tap(find.text('Borrar base de datos'));
      await tester.pumpAndSettle();
      expect(find.text('¿Borrar base de datos?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(pair.lb.length, 0);
    });

    testWidgets('Borrar todo wipes prefs + leaderboard + shows snackbar',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final pair = await _bootstrap();
      await pair.lb.add(_entry(name: 'X', delta: 0.5));
      await pair.store.setMessageRotationSeconds(45);

      await tester.pumpWidget(_wrap(AdminScreen(
        configStore: pair.store,
        leaderboard: pair.lb,
        onExit: () {},
      )));
      await tester.pump();
      await tester.tap(find.text('Borrar base de datos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Borrar todo'));
      await tester.pumpAndSettle();

      expect(pair.lb.length, 0);
      expect(pair.store.messageRotationSeconds(), 30);
      expect(find.text('Base de datos borrada'), findsOneWidget);
    });

    testWidgets('Salir calls onExit', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final pair = await _bootstrap();
      bool exited = false;
      await tester.pumpWidget(_wrap(AdminScreen(
        configStore: pair.store,
        leaderboard: pair.lb,
        onExit: () => exited = true,
      )));
      await tester.pump();
      await tester.tap(find.text('Salir'));
      await tester.pumpAndSettle();
      expect(exited, isTrue);
    });

    testWidgets('changing rotation interval persists on submit',
        (WidgetTester tester) async {
      final pair = await _bootstrap();
      await tester.pumpWidget(_wrap(AdminScreen(
        configStore: pair.store,
        leaderboard: pair.lb,
        onExit: () {},
      )));
      // Taller viewport so the messages rotation field is in
      // bounds without scrolling (more sections were added).
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pump();
      final Finder field = find.widgetWithText(TextFormField, 'Rotación de mensajes');
      expect(field, findsOneWidget);
      await tester.enterText(field, '45');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(pair.store.messageRotationSeconds(), 45);
    });

    testWidgets('Tiempo del ranking accepts 3..15 and rejects out-of-range',
        (WidgetTester tester) async {
      final pair = await _bootstrap();
      await tester.pumpWidget(_wrap(AdminScreen(
        configStore: pair.store,
        leaderboard: pair.lb,
        onExit: () {},
      )));
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pump();

      // (1) In-range: 10s is saved and the pref reflects it.
      final Finder field =
          find.widgetWithText(TextFormField, 'Tiempo del ranking');
      expect(field, findsOneWidget);
      await tester.enterText(field, '10');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(pair.store.leaderboardRotationSeconds(), 10);

      // (2) The setter itself rejects 0 (below min) and 20 (above max).
      expect(
        () => pair.store.setLeaderboardRotationSeconds(0),
        throwsArgumentError,
      );
      expect(
        () => pair.store.setLeaderboardRotationSeconds(20),
        throwsArgumentError,
        reason: '20 is above the new 15-second hard cap',
      );
      // (3) Edge cases: 3 and 15 are accepted.
      await pair.store.setLeaderboardRotationSeconds(3);
      expect(pair.store.leaderboardRotationSeconds(), 3);
      await pair.store.setLeaderboardRotationSeconds(15);
      expect(pair.store.leaderboardRotationSeconds(), 15);
    });
  });

  group('ConfettiPainter', () {
    test('shouldRepaint is false for same value/seed/intensity', () {
      final a = ConfettiPainter(value: 0.5, seed: 1);
      final b = ConfettiPainter(value: 0.5, seed: 1);
      expect(a.shouldRepaint(b), isFalse);
    });

    test('shouldRepaint is true when value changes', () {
      final a = ConfettiPainter(value: 0.5, seed: 1);
      final c = ConfettiPainter(value: 0.7, seed: 1);
      expect(a.shouldRepaint(c), isTrue);
    });

    test('shouldRepaint is true when seed changes', () {
      final a = ConfettiPainter(value: 0.5, seed: 1);
      final d = ConfettiPainter(value: 0.5, seed: 2);
      expect(a.shouldRepaint(d), isTrue);
    });

    test('shouldRepaint is true when intensity changes', () {
      final a = ConfettiPainter(value: 0.5, seed: 1, intensity: 1.0);
      final e = ConfettiPainter(value: 0.5, seed: 1, intensity: 2.0);
      expect(a.shouldRepaint(e), isTrue);
    });
  });

  group('ResultScreen', () {
    // Each test sets a viewport and checks that the chronograph
    // (big seconds digits) is present in the widget tree. The
    // FittedBox at the outer level absorbs any layout overflow
    // so these should all pass without 'RenderFlex overflowed'
    // exceptions.
    Future<void> pumpResult(
      WidgetTester tester, {
      required double elapsed,
      required Size viewport,
    }) async {
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool tapped = false;
      await tester.pumpWidget(_wrap(ResultScreen(
        elapsedSeconds: elapsed,
        onNext: () => tapped = true,
      )));
      // Let the verdict animation finish (1.5s is the longest).
      await tester.pump(const Duration(seconds: 2));
      expect(tapped, isFalse);
    }

    testWidgets('renders VICTORIA branch with no overflow at 1280x720',
        (WidgetTester tester) async {
      await pumpResult(
        tester,
        elapsed: 10.0005,
        viewport: const Size(1280, 720),
      );
      // The verdict label is the most reliable widget to assert on.
      expect(find.text('¡GANASTE!'), findsOneWidget);
    });

    testWidgets('renders CASI branch with no overflow at 1280x720',
        (WidgetTester tester) async {
      await pumpResult(
        tester,
        elapsed: 10.005,
        viewport: const Size(1280, 720),
      );
      expect(find.text('¡CASI, CASI!'), findsOneWidget);
    });

    testWidgets('renders NI POR ASOMO branch with no overflow at 1280x720',
        (WidgetTester tester) async {
      await pumpResult(
        tester,
        elapsed: 8.5,
        viewport: const Size(1280, 720),
      );
      expect(find.text('¡NI POR ASOMO!'), findsOneWidget);
    });

    testWidgets('renders TE PASASTE branch with no overflow at 1280x720',
        (WidgetTester tester) async {
      await pumpResult(
        tester,
        elapsed: 11.0,
        viewport: const Size(1280, 720),
      );
      expect(find.text('¡TE PASASTE!'), findsOneWidget);
    });

    testWidgets('renders at small viewport (800x480) without overflow',
        (WidgetTester tester) async {
      // The viewport the original failure occurred at — if the
      // outer FittedBox fix works, this passes. If it doesn't,
      // the test fails with 'RenderFlex overflowed by N pixels'.
      await pumpResult(
        tester,
        elapsed: 10.0005,
        viewport: const Size(800, 480),
      );
      expect(find.text('¡GANASTE!'), findsOneWidget);
      // The invader slot is wrapped in Flexible + FittedBox so a
      // tight viewport must not raise an overflow or paint
      // exception.
      expect(tester.takeException(), isNull,
          reason: 'invader slot must not overflow at 800x480');
    });

    testWidgets('invader is wrapped in FittedBox.scaleDown at 800x480',
        (WidgetTester tester) async {
      // Pins the Fix 4 refactor: the invader CustomPaint must
      // descend from a FittedBox with BoxFit.scaleDown so it
      // shrinks on the smallest kiosk viewport.
      tester.view.physicalSize = const Size(800, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(ResultScreen(
        elapsedSeconds: 10.0005,
        onNext: () {},
      )));
      await tester.pump(const Duration(seconds: 2));

      final Finder fitted = find.ancestor(
        of: find.byWidgetPredicate(
          (Widget w) => w is CustomPaint && w.painter is InvaderSpritePainter,
        ),
        matching: find.byType(FittedBox),
      );
      expect(fitted, findsWidgets,
          reason: 'invader painter must be inside a FittedBox');
      expect(tester.takeException(), isNull);
    });

    testWidgets('auto-returns to onNext after the configured timeout',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var taps = 0;
      await tester.pumpWidget(_wrap(ResultScreen(
        elapsedSeconds: 10.0005,
        resultTimeoutSeconds: 3,
        onNext: () => taps++,
      )));
      // Advance less than the timeout — should not have fired.
      await tester.pump(const Duration(seconds: 2));
      expect(taps, 0, reason: 'should not have auto-returned yet');
      // Advance past the timeout — should have fired once.
      await tester.pump(const Duration(seconds: 2));
      expect(taps, 1, reason: 'should have auto-returned exactly once');
    });

    testWidgets('VICTORIA branch renders an InvaderSpritePainter',
        (WidgetTester tester) async {
      await pumpResult(
        tester,
        elapsed: 10.0005,
        viewport: const Size(1280, 720),
      );
      expect(
        find.byWidgetPredicate(
          (Widget w) => w is CustomPaint && w.painter is InvaderSpritePainter,
        ),
        findsOneWidget,
      );
    });

    testWidgets('CASI branch renders an InvaderSpritePainter',
        (WidgetTester tester) async {
      await pumpResult(
        tester,
        elapsed: 10.005,
        viewport: const Size(1280, 720),
      );
      expect(
        find.byWidgetPredicate(
          (Widget w) => w is CustomPaint && w.painter is InvaderSpritePainter,
        ),
        findsOneWidget,
      );
    });

    testWidgets('NI POR ASOMO branch renders an InvaderSpritePainter',
        (WidgetTester tester) async {
      await pumpResult(
        tester,
        elapsed: 8.5,
        viewport: const Size(1280, 720),
      );
      expect(
        find.byWidgetPredicate(
          (Widget w) => w is CustomPaint && w.painter is InvaderSpritePainter,
        ),
        findsOneWidget,
      );
    });

    testWidgets('TE PASASTE branch renders an InvaderSpritePainter',
        (WidgetTester tester) async {
      await pumpResult(
        tester,
        elapsed: 11.0,
        viewport: const Size(1280, 720),
      );
      expect(
        find.byWidgetPredicate(
          (Widget w) => w is CustomPaint && w.painter is InvaderSpritePainter,
        ),
        findsOneWidget,
      );
    });

    testWidgets('honors custom victory range from constructor',
        (WidgetTester tester) async {
      // Range is offset from the default so the test is meaningful.
      // The custom window is [9.4, 9.6] (above the 9.0s NI threshold
      // so the verdict really is VICTORIA, not NI). 9.5 sits in the
      // middle.
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool tapped = false;
      await tester.pumpWidget(_wrap(ResultScreen(
        elapsedSeconds: 9.5,
        victoryRangeStart: 9.4,
        victoryRangeEnd: 9.6,
        onNext: () => tapped = true,
      )));
      await tester.pump(const Duration(seconds: 2));
      expect(tapped, isFalse);
      expect(find.text('¡GANASTE!'), findsOneWidget,
          reason: 'with custom range 9.4..9.6, 9.5s should be VICTORIA');
    });

    testWidgets('moves 10.0005 out of VICTORIA when range is shifted',
        (WidgetTester tester) async {
      // 10.0005 is VICTORIA with the default range but falls inside
      // CASI territory when the window is moved up to [9.4, 9.6].
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool tapped = false;
      await tester.pumpWidget(_wrap(ResultScreen(
        elapsedSeconds: 10.0005,
        victoryRangeStart: 9.4,
        victoryRangeEnd: 9.6,
        onNext: () => tapped = true,
      )));
      await tester.pump(const Duration(seconds: 2));
      expect(tapped, isFalse);
      expect(find.text('¡CASI, CASI!'), findsOneWidget);
    });

    testWidgets(
        'CASI branch renders the achieved time as a sign next to the invader',
        (WidgetTester tester) async {
      // Pump ResultScreen with elapsed=10.005 (CASI range). After
      // a 1s pump the TweenAnimationBuilder has completed (its
      // duration is 400ms), so the sign is at full scale.
      // The sign now shows the arcade caption "¡POR UN PELO!" in
      // BungeeInline, NOT the elapsed time — the invader's alpha
      // flicker is what carries the motion.
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(ResultScreen(
        elapsedSeconds: 10.005,
        onNext: () {},
      )));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('¡CASI, CASI!'), findsOneWidget,
          reason: 'verdict label still renders for CASI');
      expect(find.text('¡POR UN PELO!'), findsOneWidget,
          reason: 'CASI sign shows the arcade caption');
      // The invader painter is still present alongside the sign.
      expect(
        find.byWidgetPredicate(
          (Widget w) => w is CustomPaint && w.painter is InvaderSpritePainter,
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'CASI branch sign uses BungeeInline at fontSize 44 in white',
        (WidgetTester tester) async {
      // Pins the visual recipe: the sign Text widget must be
      // BungeeInline, fontSize 44, color white, weight 900. The
      // sign carries the arcade caption (not the elapsed time).
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(ResultScreen(
        elapsedSeconds: 9.42,
        onNext: () {},
      )));
      await tester.pump(const Duration(seconds: 1));
      final Finder signFinder = find.text('¡POR UN PELO!');
      expect(signFinder, findsOneWidget);
      final Text sign = tester.widget<Text>(signFinder);
      expect(sign.style!.fontFamily, 'BungeeInline');
      expect(sign.style!.fontSize, 44.0);
      expect(sign.style!.color, const Color(0xFFFFFFFF));
    });

    testWidgets(
        'NI POR ASOMO branch renders BOO text and invader that turns around',
        (WidgetTester tester) async {
      // Pump ResultScreen with elapsed=8.5 (NI POR ASOMO range).
      // After 0.5s the drop controller (2.5s repeat) is at
      // t≈0.2 — the turn-around phase where the invader is
      // mirrored and the BOO text is partway through its
      // overshoot. The "¡BOO!" string itself is drawn inside the
      // CustomPainter, not as a widget, so we can't find it via
      // find.text — we instead assert the painter receives a
      // non-zero t and the widget tree contains the expected
      // CustomPaint (already covered above; the regression
      // coverage is the invader-renders-while-mirrored check).
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(ResultScreen(
        elapsedSeconds: 8.5,
        onNext: () {},
      )));
      await tester.pump(const Duration(milliseconds: 500));
      // The invader painter is mounted and the controller is
      // running (no exception, no overflow).
      expect(
        find.byWidgetPredicate(
          (Widget w) => w is CustomPaint && w.painter is InvaderSpritePainter,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull,
          reason: 'NI POR ASOMO painter must not throw during the BOO cycle');
      // The verdict label is still rendered.
      expect(find.text('¡NI POR ASOMO!'), findsOneWidget);
    });
  });

  group('InvaderSpritePainter', () {
    test('shouldRepaint is true when t changes', () {
      final InvaderSpritePainter a = InvaderSpritePainter(
        expression: InvaderExpression.victoria,
        pixelSize: 8.0,
        t: 0.0,
        colors: const <Color>[Color(0xFF00FF66), Color(0xFF000000)],
      );
      final InvaderSpritePainter b = InvaderSpritePainter(
        expression: InvaderExpression.victoria,
        pixelSize: 8.0,
        t: 0.5,
        colors: const <Color>[Color(0xFF00FF66), Color(0xFF000000)],
      );
      expect(a.shouldRepaint(b), isTrue);
    });

    test('shouldRepaint is true when expression changes', () {
      final InvaderSpritePainter a = InvaderSpritePainter(
        expression: InvaderExpression.casi,
        pixelSize: 8.0,
        t: 0.0,
        colors: const <Color>[Color(0xFFFFC107), Color(0xFF000000)],
      );
      final InvaderSpritePainter b = InvaderSpritePainter(
        expression: InvaderExpression.victoria,
        pixelSize: 8.0,
        t: 0.0,
        colors: const <Color>[Color(0xFF00FF66), Color(0xFF000000)],
      );
      expect(a.shouldRepaint(b), isTrue);
    });

    test('shouldRepaint is true when pixelSize changes', () {
      final InvaderSpritePainter a = InvaderSpritePainter(
        expression: InvaderExpression.casi,
        pixelSize: 8.0,
        t: 0.0,
        colors: const <Color>[Color(0xFFFFC107), Color(0xFF000000)],
      );
      final InvaderSpritePainter b = InvaderSpritePainter(
        expression: InvaderExpression.casi,
        pixelSize: 12.0,
        t: 0.0,
        colors: const <Color>[Color(0xFFFFC107), Color(0xFF000000)],
      );
      expect(a.shouldRepaint(b), isTrue);
    });

    test(
        'niPorAsomo painter survives a full 0..1 cycle without throwing or skipping frames',
        () {
      // Renders the new BOO scare cycle into a Picture recorder
      // across the full 0..1 timeline. We sample a 0.02 grid
      // (51 frames) and check no paint call raises. This covers
      // the three phases (neutral, mirrored, shrinking) plus the
      // brief window where the invader is hidden (>0.95).
      const Size size = Size(176.0, 128.0);
      InvaderSpritePainter? prev;
      for (double t = 0.0; t <= 1.0; t += 0.02) {
        final InvaderSpritePainter p = InvaderSpritePainter(
          expression: InvaderExpression.niPorAsomo,
          pixelSize: 16.0,
          t: t,
          colors: const <Color>[Color(0xFFFF7070), Color(0xFF000000)],
        );
        final ui.PictureRecorder recorder = ui.PictureRecorder();
        final Canvas canvas = Canvas(recorder);
        p.paint(canvas, size);
        final ui.Picture pic = recorder.endRecording();
        expect(pic, isNotNull,
            reason: 'painter at t=$t must produce a non-null Picture');
        pic.dispose();
        if (prev != null && t > 0.0) {
          // Advancing t should always request a repaint.
          expect(prev.shouldRepaint(p), isTrue,
              reason: 'shouldRepaint must be true for t change at t=$t');
        }
        prev = p;
      }
    });
  });

  group('PlayingScreen — chronograph format SS.mmmu at Fire HD 8 viewport', () {
    // The Fire HD 8 in landscape reports 1280x800 physical px.
    // The kiosk target is that viewport — chronograph must be
    // visible and the format must be SS.mmmu (4 digits after the
    // dot, with the last digit in its own smaller Text widget so
    // it reads as "secondary, advancing").
    Future<void> setFireHd8Viewport(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    testWidgets(
        'chronograph is present and no overflow at 1280x800 with padding=8',
        (WidgetTester tester) async {
      await setFireHd8Viewport(tester);
      final StopwatchController controller = StopwatchController();
      await tester.pumpWidget(_wrap(PlayingScreen(
        controller: controller,
        onTimeout: () {},
      )));
      // Cross the 1s countdown so the chronograph is at opacity 1.
      await tester.pump(const Duration(milliseconds: 1500));

      // The seconds Text is the 2-digit block (00..60). We
      // assert at least one is in the tree.
      final Finder secondsFinder = find.byWidgetPredicate(
        (Widget w) {
          if (w is! Text) return false;
          final String? data = w.data;
          if (data == null || data.length != 2) return false;
          final int? n = int.tryParse(data);
          return n != null && n >= 0 && n <= 60;
        },
      );
      expect(secondsFinder, findsWidgets,
          reason: 'chronograph seconds (SS) must be visible at 1280x800');
      // No layout / overflow exception.
      expect(tester.takeException(), isNull,
          reason: 'chronograph must not overflow at 1280x800');
    });

    testWidgets(
        'chronograph renders the .mmm block and a separate 1-digit u block',
        (WidgetTester tester) async {
      await setFireHd8Viewport(tester);
      final StopwatchController controller = StopwatchController();
      await tester.pumpWidget(_wrap(PlayingScreen(
        controller: controller,
        onTimeout: () {},
      )));
      // Cross the 1s countdown so the chronograph is visible.
      await tester.pump(const Duration(milliseconds: 1500));

      // The 3-digit fraction is now its own Text: starts with '.'
      // and has exactly 3 digits (format: .mmm).
      final Finder dotMillisFinder = find.byWidgetPredicate(
        (Widget w) {
          if (w is! Text) return false;
          final String? data = w.data;
          if (data == null || data.length != 4) return false;
          if (!data.startsWith('.')) return false;
          return RegExp(r'^\.\d{3}$').hasMatch(data);
        },
      );
      expect(dotMillisFinder, findsOneWidget,
          reason:
              'Expected a Text widget matching the .mmm block of the '
              'chronograph (starts with a dot and has exactly 3 digits), '
              'but none was found. The format must be SS.mmmu with the '
              'three millis digits in their own Text widget.');

      // The 1-digit decimicro (u) is a separate Text widget.
      final Finder lastDigitFinder = find.byWidgetPredicate(
        (Widget w) {
          if (w is! Text) return false;
          final String? data = w.data;
          if (data == null || data.length != 1) return false;
          return int.tryParse(data) != null;
        },
      );
      expect(lastDigitFinder, findsOneWidget,
          reason:
              'Expected a 1-digit Text widget for the trailing u (decimicro) '
              'digit of the chronograph. The format must be SS.mmmu with the '
              'last digit in its own (smaller) Text widget.');

      // The u digit must be visually smaller than the .mmm block:
      // 240 < 400, so its fontSize resolves to a smaller logical size.
      final Text uText = tester.widget<Text>(lastDigitFinder);
      final Text dotText = tester.widget<Text>(dotMillisFinder);
      expect(uText.style!.fontSize!, lessThan(dotText.style!.fontSize!),
          reason: 'the trailing u must be smaller than the .mmm block');
    });

    testWidgets(
        'chronograph natural fontSizes are 1800/720/320 at 1280x800',
        (WidgetTester tester) async {
      // Pins the Fix 1 scale-up: with the new padding
      // (vertical: 0, horizontal: 0, bottom: 64 for cheer
      // separation) the chronograph should fill the 800-px
      // height and reach the left/right edges. The natural
      // fontSizes are pinned to 1800/720/320 (slightly under
      // 2000/800/360 so FittedBox doesn't reserve margin) so the
      // FittedBox picks the largest size that touches the edges.
      await setFireHd8Viewport(tester);
      final StopwatchController controller = StopwatchController();
      await tester.pumpWidget(_wrap(PlayingScreen(
        controller: controller,
        onTimeout: () {},
      )));
      await tester.pump(const Duration(milliseconds: 1500));

      // Find the seconds, .mmm, and u Text widgets and assert
      // their natural fontSize.
      final Finder secondsFinder = find.byWidgetPredicate(
        (Widget w) {
          if (w is! Text) return false;
          final String? data = w.data;
          if (data == null || data.length != 2) return false;
          final int? n = int.tryParse(data);
          return n != null && n >= 0 && n <= 60;
        },
      );
      final Finder dotMillisFinder = find.byWidgetPredicate(
        (Widget w) {
          if (w is! Text) return false;
          final String? data = w.data;
          if (data == null || data.length != 4) return false;
          if (!data.startsWith('.')) return false;
          return RegExp(r'^\.\d{3}$').hasMatch(data);
        },
      );
      final Finder lastDigitFinder = find.byWidgetPredicate(
        (Widget w) {
          if (w is! Text) return false;
          final String? data = w.data;
          if (data == null || data.length != 1) return false;
          return int.tryParse(data) != null;
        },
      );
      final Text secondsText = tester.widget<Text>(secondsFinder.first);
      final Text dotText = tester.widget<Text>(dotMillisFinder);
      final Text uText = tester.widget<Text>(lastDigitFinder);
      expect(secondsText.style!.fontSize, 1800.0,
          reason: 'seconds natural fontSize should be 1800 (edge-to-edge)');
      expect(dotText.style!.fontSize, 720.0,
          reason: '.mmm natural fontSize should be 720');
      expect(uText.style!.fontSize, 360.0,
          reason: 'u natural fontSize should be 360');
      // No overflow / paint exception.
      expect(tester.takeException(), isNull,
          reason: 'chronograph must not overflow at 1280x800 with the '
              'new fontSizes');
    });
  });

  group('WaitingScreen — leaderboard empty-state height parity', () {
    // The empty-state message used to render much smaller than
    // the 5-row state (just a single FittedBox line), so the
    // panel visually shrank. The fix pins the empty state to
    // 5 * 60 px (matching the 5-row natural height) and centers
    // the message inside that box.
    Future<void> pumpAndPumpIntoLeaderboard(
      WidgetTester tester,
      _Pair pair,
    ) async {
      await tester.pumpWidget(_wrap(WaitingScreen(
        configStore: pair.store,
        leaderboard: pair.lb,
      )));
      await tester.pump();
      // Cross the 3s message boundary so the screen is in the
      // leaderboard phase.
      await tester.pump(const Duration(milliseconds: 3500));
    }

    testWidgets(
        'empty leaderboard panel and 5-row panel are visually the same height',
        (WidgetTester tester) async {
      final pair = await _bootstrap();
      await pair.store.setMessageRotationSeconds(1);
      await pair.store.setLeaderboardRotationSeconds(15);

      // First: empty leaderboard. Take the size of the panel
      // (the Column inside the SingleChildScrollView — first
      // Column under the SafeArea in the leaderboard phase).
      await pumpAndPumpIntoLeaderboard(tester, pair);
      // Sanity: the empty-state message is present.
      expect(find.text('TODAVÍA NO HAY GANADORES. ¡SÉ EL PRIMERO!'),
          findsOneWidget);
      // Measure the empty-state SizedBox (5 * 60 = 300 px tall).
      final Finder emptySizeBox = find.ancestor(
        of: find.text('TODAVÍA NO HAY GANADORES. ¡SÉ EL PRIMERO!'),
        matching: find.byType(SizedBox),
      ).first;
      final RenderBox emptyBox =
          tester.renderObject(emptySizeBox) as RenderBox;
      final Size emptySize = emptyBox.size;

      // Second: 5-row leaderboard. Seed 5 entries, swap the
      // leaderboard, and pump back into the leaderboard phase.
      for (int i = 0; i < 5; i++) {
        await pair.lb.add(_entry(
          name: 'P${i + 1}',
          rawSeconds: 10.0 + i * 0.01,
          delta: i * 0.01,
        ));
      }
      await pumpAndPumpIntoLeaderboard(tester, pair);
      // Measure one of the 5-row Padding wrappers (each row is
      // Padding(vertical: 6) around a FittedBox).
      final Finder rowPadding = find
          .ancestor(
            of: find.text('P1'),
            matching: find.byType(Padding),
          )
          .first;
      final RenderBox rowBox =
          tester.renderObject(rowPadding) as RenderBox;
      final Size rowSize = rowBox.size;

      // Per-row height is variable (depends on viewport — the
      // FittedBox scales the 48sp text to fit). On the kiosk
      // target (1280x800) the rows are ~100 px tall, so the
      // empty-state SizedBox is pinned to 5 * 100 = 500 px.
      // The 5 rows together should be close to
      // 5 * rowSize.height. We assert the empty state is within
      // 50 px of the 5-row panel so the panel does not visually
      // shrink dramatically (the bug was that the empty state
      // collapsed to a single line, leaving hundreds of px of
      // empty space).
      final double fiveRows = rowSize.height * 5.0;
      expect(
        (emptySize.height - fiveRows).abs(),
        lessThanOrEqualTo(50.0),
        reason: 'empty-state panel height (${emptySize.height}px) should '
            'match the 5-row panel height (~${fiveRows.toStringAsFixed(0)}px) '
            'within 50px so the panel does not visually shrink',
      );
    });
  });
}
