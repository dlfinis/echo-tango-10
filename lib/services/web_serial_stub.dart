/// Non-Web stub for the Web Serial API connection.
///
/// Selected by the conditional import in `web_serial.dart` on non-Web
/// targets (Android, iOS, desktop) where `dart:html` is not available.
library;

import 'input_service.dart';

/// Throws on non-Web targets — the call site (admin panel) is
/// platform-guarded and the "Connect USB" button only shows on Web.
Future<void> connectUsbSerial(InputService input) {
  throw UnsupportedError(
    'Web Serial API is only available on the Web target. '
    'On Android, use the `usb_serial` path (PR3, task T10).',
  );
}
