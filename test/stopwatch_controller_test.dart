// PR1 smoke tests for the stopwatch controller wrapper.

import 'package:arcade_timer_10s/state/stopwatch_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StopwatchController', () {
    test('accepts the first pulse', () {
      final c = StopwatchController();
      expect(c.tryPulse(), isTrue);
      c.dispose();
    });

    test('suppresses a second pulse inside the debounce window', () {
      final c = StopwatchController();
      expect(c.tryPulse(), isTrue);
      expect(c.tryPulse(), isFalse, reason: '200ms debounce is active');
      c.dispose();
    });

    test('start() resets the debounce window', () {
      final c = StopwatchController();
      // Saturate the window.
      expect(c.tryPulse(), isTrue);
      expect(c.tryPulse(), isFalse);
      // start() opens it again.
      c.start();
      expect(c.tryPulse(), isTrue);
      c.dispose();
    });
  });
}
