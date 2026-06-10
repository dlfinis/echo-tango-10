/// Web Serial API glue — only available on `dart:html` (Web target).
///
/// This file uses a conditional import so the Android build does not
/// attempt to load `dart:html`. The contract lives in
/// `web_serial_stub.dart` (a no-op on non-web) and
/// `web_serial_web.dart` (the real navigator.usb / navigator.serial
/// request).
library;

import 'input_service.dart';
import 'web_serial_stub.dart'
    if (dart.library.html) 'web_serial_web.dart' as impl;

/// Connects a USB serial device via the Web Serial API and pumps any
/// 'P' / 'p' bytes into the given [InputService.triggerPulse] callback.
///
/// Returns when the stream is opened; the stream itself keeps reading
/// asynchronously. Errors (e.g. user cancels the picker, no device
/// selected) are rethrown so the admin UI can show a snackbar.
///
/// **Dev gate**: requires Chrome (HTTPS or localhost).
Future<void> connectUsbSerial(InputService input) {
  return impl.connectUsbSerial(input);
}
