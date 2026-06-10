/// Entry point for the Arcade Timer 10s kiosk.
///
/// `kIsWeb` fork point (see tech_specs §2 and design "Compilación
/// Condicional"):
///   * Web     → `KeyboardInput` service + `KeyboardInputWidget` adapter.
///               PR2 adds the Web Serial gate.
///   * Android → `UsbSerialInput` stub for now; real impl in PR3.
///
/// WAKELOCK NOTE: PR1 does NOT call `WakelockPlus.enable()`. The Android
/// branch is a TODO until PR3, which will also wire
/// `SystemUiMode.immersiveSticky` and the touch-block layer.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'services/input_service.dart';
import 'services/keyboard_input.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final InputService input = kIsWeb
      ? KeyboardInput()
      : _AndroidInputStub();

  runApp(AppRoot(input: input));
}

/// Temporary Android input placeholder. Replaced by the real
/// `UsbSerialInput` in PR3 (task T10).
class _AndroidInputStub implements InputService {
  @override
  void onPulse(void Function() cb) {
    // TODO(PR3): wire usb_serial CDC ACM stream here. The 'P' byte (0x50)
    // advances the state machine; everything else is discarded.
  }

  @override
  void dispose() {
    // No native resources to release yet.
  }
}
