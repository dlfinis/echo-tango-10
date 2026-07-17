/// Web stub for the USB serial input.
///
/// The Android USB host plugin is unavailable on Web. The kiosk never runs
/// on Web in production (it's an Android-only Fire HD 8 app), but we keep a
/// stub so `flutter build web` succeeds — useful for local development.
///
/// The stub throws on [connect] so any code path that exercises
/// the real connect path on Web will fail loudly instead of
/// silently doing nothing.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../state/stopwatch_controller.dart';
import 'input_service.dart';
import 'usb_connection_diagnostics.dart';

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
  bool _isDisposed = false;
  final ValueNotifier<UsbConnectionDiagnostics> diagnostics =
      ValueNotifier<UsbConnectionDiagnostics>(const UsbConnectionDiagnostics());

  @override
  void onPulse(void Function() cb) {
    _callback = cb;
  }

  @override
  void triggerPulse() {
    if (_isDisposed) return;
    if (_debounce.tryPulse()) {
      _callback?.call();
    }
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
    _isDisposed = true;
    _callback = null;
    _debounce.dispose();
  }

  /// Test-only entry point. Mirrors the dispatch path of the
  /// Android implementation so protocol tests run on both
  /// platforms.
  @visibleForTesting
  void feedBytesForTest(Uint8List data) {
    if (_isDisposed || data.isEmpty) return;
    diagnostics.value = diagnostics.value.copyWith(
      lastByte: data.last,
      receivedByteCount: diagnostics.value.receivedByteCount + data.length,
    );
    for (final int byte in data) {
      if (byte == 0x01) {
        if (_debounce.tryPulse()) {
          _callback?.call();
          diagnostics.value = diagnostics.value.copyWith(
            acceptedPulseCount: diagnostics.value.acceptedPulseCount + 1,
          );
        }
      }
    }
  }
}
