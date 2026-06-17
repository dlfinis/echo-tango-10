/// Source-agnostic facade for the USB serial input.
///
/// Picks the right implementation per platform via conditional
/// imports so `flutter build web` does not pull in the
/// dart:ffi-dependent Android implementation:
///   * Android (and any platform with dart:io + native serial)
///     → usb_serial_input_android.dart (flutter_libserialport).
///   * Web     → usb_serial_input_web.dart (no-op stub that
///     throws on connect; allows local dev builds).
///
/// Both files define a class literally named `UsbSerialInput`
/// implementing [InputService]. Call sites import this facade and
/// write `UsbSerialInput()` regardless of platform.
library;

import 'input_service.dart';
import 'usb_serial_input_web.dart'
    if (dart.library.io) 'usb_serial_input_android.dart';

/// Type alias so call sites don't need to know which backend is
/// active. Both the stub and the Android impl expose the same
/// constructor signature + the same public surface, so this is
/// safe.
typedef UsbSerialInput = UsbSerialInputImpl;
