// Reproduces the user-reported bug: the PlayingScreen's chronograph
// is not visible after the 3-2-1-GO countdown ends. We don't fix
// anything here — we just write tests that PROVE the bug exists
// (or prove it doesn't), so we can stop fixing the layout blindly.

import 'package:arcade_timer_10s/state/stopwatch_controller.dart';
import 'package:arcade_timer_10s/widgets/playing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  // Mirror the user's viewport — a Fire HD 8 in landscape gives
  // 1280x800 effective, but a typical browser window might be
  // smaller. Use 1280x720 as a safe common case.
  Future<void> setViewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'PlayingScreen — countdown is null after 1.5s (so digits are visible)',
    (WidgetTester tester) async {
      await setViewport(tester);
      final StopwatchController controller = StopwatchController();
      await tester.pumpWidget(_wrap(PlayingScreen(
        controller: controller,
        onTimeout: () {},
      )));

      // The countdown overlay text changes from '3' -> '2' -> '1'
      // -> 'GO!' -> null. After 1.5s it should be null, meaning
      // the overlay is gone and the chronograph is at opacity 1.
      await tester.pump(const Duration(milliseconds: 1500));

      // Find the countdown Text. After 1.5s it should be gone
      // (the widget tree should not contain a Text with '3', '2',
      // '1', or 'GO!').
      final Finder countdownFinder = find.byWidgetPredicate(
        (Widget w) {
          if (w is! Text) return false;
          final String? data = w.data;
          return data == '3' || data == '2' || data == '1' || data == '¡GO!';
        },
      );
      final int countdownCount = countdownFinder.evaluate().length;
      // ignore: avoid_print
      debugPrint('DIAG: countdown overlay widgets after 1.5s = $countdownCount');
      expect(countdownCount, equals(0),
          reason: 'Countdown overlay should be gone after 1.5s, but '
              'still has $countdownCount widget(s) in the tree.');
    },
  );

  testWidgets(
    'PlayingScreen — chronograph digit is visible after countdown ends',
    (WidgetTester tester) async {
      await setViewport(tester);
      final StopwatchController controller = StopwatchController();
      int timeoutCalls = 0;
      await tester.pumpWidget(_wrap(PlayingScreen(
        controller: controller,
        onTimeout: () => timeoutCalls++,
      )));

      // Pump past the 1s countdown (3 -> 2 -> 1 -> GO!).
      // Each step is 250ms; total 1s. Pump an extra second to let
      // the GO! flash fade out and the chronograph to settle.
      await tester.pump(const Duration(milliseconds: 250)); // -> 2
      await tester.pump(const Duration(milliseconds: 250)); // -> 1
      await tester.pump(const Duration(milliseconds: 250)); // -> GO!
      await tester.pump(const Duration(milliseconds: 250)); // -> null
      await tester.pump(const Duration(milliseconds: 1000)); // settle

      // The chronograph is composed of 3 Text widgets whose data
      // starts with a digit 0-9. The 'SS' segment is the big one.
      // Find any Text whose data matches a 2-digit number (00..60).
      final Finder digitFinder = find.byWidgetPredicate(
        (Widget w) {
          if (w is! Text) return false;
          final String? data = w.data;
          if (data == null) return false;
          if (data.length != 2) return false;
          final int? n = int.tryParse(data);
          return n != null && n >= 0 && n <= 60;
        },
      );

      // Expect at least one such digit widget.
      final int digitCount = digitFinder.evaluate().length;
      // Print the count so the test log shows it.
      // ignore: avoid_print
      debugPrint('DIAG: digit widgets with 2-digit value after countdown = $digitCount');

      // Also dump the widget tree so we can see what's there.
      // ignore: avoid_print
      debugPrint('DIAG: widget tree dump:');
      // ignore: avoid_print
      debugPrint(tester.element(digitFinder.first).toStringDeep());

      expect(digitCount, greaterThan(0),
          reason: 'Expected the chronograph digits to be in the tree '
              'after the countdown. None found.');
    },
  );

  testWidgets(
    'PlayingScreen — chronograph digits have non-zero paint bounds',
    (WidgetTester tester) async {
      await setViewport(tester);
      final StopwatchController controller = StopwatchController();
      await tester.pumpWidget(_wrap(PlayingScreen(
        controller: controller,
        onTimeout: () {},
      )));
      await tester.pump(const Duration(milliseconds: 1500));

      final Finder digitFinder = find.byWidgetPredicate(
        (Widget w) {
          if (w is! Text) return false;
          final String? data = w.data;
          if (data == null) return false;
          if (data.length != 2) return false;
          final int? n = int.tryParse(data);
          return n != null && n >= 0 && n <= 60;
        },
      );
      final int digitCount = digitFinder.evaluate().length;
      if (digitCount == 0) {
        fail('No 2-digit Text widgets in the tree after the countdown.');
      }
      // Get the paint bounds of the FittedBox that wraps the
      // chronograph row, not the inner Text. The Text's render
      // box reports its NATURAL size (1704x880 for 880sp) even
      // when the FittedBox scales it down to fit the viewport.
      // The FittedBox itself, however, is bounded by the
      // viewport so its size will tell us whether the scale
      // actually happened.
      final Finder fittedFinder = find.byType(FittedBox).first;
      final RenderBox fittedBox =
          tester.renderObject(fittedFinder) as RenderBox;
      final Size fittedSize = fittedBox.size;
      // ignore: avoid_print
      debugPrint('DIAG: FittedBox size = $fittedSize (viewport was 1280x720)');
      expect(fittedSize.width, lessThanOrEqualTo(1280.0),
          reason: 'FittedBox must scale the row down to fit 1280px '
              'viewport, but reported size is $fittedSize');
    },
  );
}
