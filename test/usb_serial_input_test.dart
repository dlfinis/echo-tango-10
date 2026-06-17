// Tests for UsbSerialInput that exercise the Arduino protocol path
// (parse bytes, debounce, dispatch callback) WITHOUT needing a real
// USB device or a mocked UsbPort.
//
// We feed bytes through the @visibleForTesting entry point, which is
// the same dispatch path the real inputStream listener uses. This
// validates:
//   * Single 0x01 byte -> fires the callback exactly once.
//   * Junk bytes (anything not 0x01) are ignored.
//   * 200ms debounce is enforced — two 0x01 within the window fire
//     only once.
//
// What this does NOT cover (requires a real device / emulator):
//   * Actual USB enumeration of CH340/FTDI/CP210x/Arduino VIDs.
//   * Port open / setPortParameters / DTR/RTS side effects.
//   * Stream lifecycle (onError, cancelOnError).

import 'dart:typed_data';

import 'package:arcade_timer_10s/services/usb_serial_input.dart';
import 'package:arcade_timer_10s/state/stopwatch_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UsbSerialInput — Arduino protocol', () {
    test('a single 0x01 byte fires the callback exactly once', () {
      final StopwatchController debounce = StopwatchController();
      final UsbSerialInput input = UsbSerialInput(debounce: debounce);
      int pulses = 0;
      input.onPulse(() => pulses++);

      input.feedBytesForTest(Uint8List.fromList(<int>[0x01]));

      expect(pulses, 1);
      expect(input.isConnected, isFalse,
          reason: 'feedBytesForTest must not flip isConnected');
    });

    test('non-0x01 bytes are ignored', () {
      final StopwatchController debounce = StopwatchController();
      final UsbSerialInput input = UsbSerialInput(debounce: debounce);
      int pulses = 0;
      input.onPulse(() => pulses++);

      // Send junk — every byte other than 0x01.
      input.feedBytesForTest(Uint8List.fromList(<int>[
        0x00, 0x02, 0x03, 0x10, 0x42, 0xFF, 0x80, 0x7F,
      ]));

      expect(pulses, 0);
    });

    test('mixed chunk with leading junk then 0x01 fires exactly once',
        () {
      final StopwatchController debounce = StopwatchController();
      final UsbSerialInput input = UsbSerialInput(debounce: debounce);
      int pulses = 0;
      input.onPulse(() => pulses++);

      input.feedBytesForTest(Uint8List.fromList(<int>[
        0x42, 0x99, 0x00, 0x01, 0x01, 0x01, 0xFF,
      ]));

      // The dispatch loop returns on the first 0x01, so trailing
      // bytes (even more 0x01) are not consumed from this chunk.
      // The next call to feedBytesForTest would consume them.
      expect(pulses, 1);
    });

    test('200ms debounce — second 0x01 within window is suppressed',
        () async {
      final StopwatchController debounce = StopwatchController();
      final UsbSerialInput input = UsbSerialInput(debounce: debounce);
      int pulses = 0;
      input.onPulse(() => pulses++);

      input.feedBytesForTest(Uint8List.fromList(<int>[0x01]));
      expect(pulses, 1, reason: 'first press is accepted');

      // Within the 200ms debounce window — should be suppressed.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      input.feedBytesForTest(Uint8List.fromList(<int>[0x01]));
      expect(pulses, 1,
          reason: 'second press within 200ms is debounced');

      // After the window expires — should fire again.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      input.feedBytesForTest(Uint8List.fromList(<int>[0x01]));
      expect(pulses, 2,
          reason: 'third press after 200ms is accepted');
    });

    test('dispose is idempotent and clears the callback', () async {
      final StopwatchController debounce = StopwatchController();
      final UsbSerialInput input = UsbSerialInput(debounce: debounce);
      int pulses = 0;
      input.onPulse(() => pulses++);

      await input.dispose();
      // After dispose, a byte should not fire the callback (the
      // internal callback field was nulled).
      input.feedBytesForTest(Uint8List.fromList(<int>[0x01]));
      expect(pulses, 0);
      // Idempotent — second dispose does not throw.
      await input.dispose();
    });
  });
}
