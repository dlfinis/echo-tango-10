// PR2 widget tests for the new screens.
//
// Coverage:
//   * WaitingScreen: first invitation message renders + admin long-press
//     fires onAdminGesture after kAdminLongPressDuration (not before).
//   * WinnerNameScreen: Aceptar writes an entry; default name is ANONIMO;
//     easter-egg flag toggles UI between "VICTORIA" and "¡EXACTO!".
//   * AdminScreen: confirm dialog, Borrar todo wipes prefs + leaderboard
//     + shows snackbar, Salir calls onExit.
//   * ConfettiPainter: shouldRepaint respects value/seed/intensity.

import 'package:arcade_timer_10s/models/leaderboard_entry.dart';
import 'package:arcade_timer_10s/services/config_store.dart';
import 'package:arcade_timer_10s/services/leaderboard.dart';
import 'package:arcade_timer_10s/utils/constants.dart';
import 'package:arcade_timer_10s/widgets/admin_screen.dart';
import 'package:arcade_timer_10s/widgets/confetti_painter.dart';
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
      await tester.pumpAndSettle();
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
      await tester.pump();
      // The "Rotación de mensajes" field is the first numeric field,
      // visible in the default viewport (no scroll needed).
      final Finder field = find.widgetWithText(TextFormField, 'Rotación de mensajes');
      expect(field, findsOneWidget);
      await tester.enterText(field, '45');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(pair.store.messageRotationSeconds(), 45);
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
}
