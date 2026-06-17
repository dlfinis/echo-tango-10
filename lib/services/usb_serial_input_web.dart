/// Web stub for the USB serial input.
///
/// On Web we cannot use `dart:ffi` (the underlying libserialport
/// library is native-only). The kiosk never runs on Web in
/// production (it's an Android-only Fire HD 8 app), but we still
/// keep a stub so `flutter build web` succeeds — useful for local
/// development without the device.
///
/// The stub throws on [connect] so any code path that exercises
/// the real connect path on Web will fail loudly instead of
/// silently doing nothing.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../state/stopwatch_controller.dart';
import 'input_service.dart';

/// Web stub class. The Android implementation lives in
/// usb_serial_input_android.dart; both have the same public surface
/// (constructor + onPulse + connect + isConnected + dispose +
/// feedBytesForTest). The facade `usb_serial_input.dart` selects
/// between them via conditional imports.
class UsbSerialInputImpl implements InputService {
  UsbSerialInputImpl({StopwatchController? debounce})
      : _debounce = debounce ?? StopwatchController();

  final StopwatchController _debounce;
  void Function()? _callback;

  @override
  void onPulse(void Function() cb) {
    _callback = cb;
  }

  /// Always throws on Web — USB serial is Android-only.
  Future<bool> connect() async {
    throw UnsupportedError(
      'USB serial no está disponible en Web. Compila para Android.',
    );
  }

  bool get isConnected => false;

  @override
  Future<void> dispose() async {
    _callback = null;
    _debounce.dispose();
  }

  /// Test-only entry point. Mirrors the dispatch path of the
  /// Android implementation so protocol tests run on both
  /// platforms.
  @visibleForTesting
  void feedBytesForTest(Uint8List data) {
    for (final int byte in data) {
      if (byte == 0x01) {
        if (_debounce.tryPulse()) {
          _callback?.call();
        }
        return;
      }
    }
  }
}
