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

import 'package:arcade_timer_10s/models/leaderboard_entry.dart';
import 'package:arcade_timer_10s/services/config_store.dart';
import 'package:arcade_timer_10s/services/leaderboard.dart';
import 'package:arcade_timer_10s/utils/constants.dart';
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
  });
}
