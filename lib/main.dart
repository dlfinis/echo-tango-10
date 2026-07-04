/// Entry point for the Arcade Timer 10s kiosk.
///
/// `kIsWeb` fork point (see tech_specs §2 and design "Compilación
/// Condicional"):
///   * Web     → `KeyboardInput` service + `KeyboardInputWidget` adapter.
///               PR2 adds the Web Serial gate.
///   * Android → `UsbSerialInput` reading bytes from the Arduino
///               (single-byte 0x01 protocol, 200ms debounce).
///
/// WAKELOCK NOTE: PR1 does NOT call `WakelockPlus.enable()`. The Android
/// branch is a TODO until PR3, which will also wire
/// `SystemUiMode.immersiveSticky` and the touch-block layer.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'services/audio_service.dart';
import 'services/input_service.dart';
import 'services/keyboard_input.dart';
import 'services/usb_serial_input.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final InputService input = kIsWeb ? KeyboardInput() : UsbSerialInput();
  final AudioService audio = AudioService();
  // Best-effort preload. Missing assets are tolerated by the
  // service (it just logs); the kiosk works without audio.
  await audio.preload();
  await audio.startWaitingMusic();

  runApp(AppRoot(input: input, audio: audio));
}
