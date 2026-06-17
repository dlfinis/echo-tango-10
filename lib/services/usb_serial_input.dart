/// Android USB serial input. Reads bytes from an Arduino over USB OTG.
///
/// The Arduino protocol is: send a single byte (0x01) on each button
/// press. Anything else is discarded. The 200ms debounce is applied
/// by the [StopwatchController] (same primitive as the Web
/// [KeyboardInput]), so the [InputService] contract is identical
/// regardless of source.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:usb_serial/usb_serial.dart';

import '../state/stopwatch_controller.dart';
import 'input_service.dart';

/// Android USB serial [InputService] that pumps Arduino button presses
/// into the kiosk state machine.
///
/// The Arduino is expected to send a single byte `0x01` on every
/// physical button press. Other bytes (startup noise, debug prints)
/// are silently dropped.
class UsbSerialInput implements InputService {
  UsbSerialInput({StopwatchController? debounce})
      : _debounce = debounce ?? StopwatchController();

  final StopwatchController _debounce;
  void Function()? _callback;
  UsbPort? _port;
  StreamSubscription<Uint8List>? _subscription;

  @override
  void onPulse(void Function() cb) {
    _callback = cb;
  }

  /// Scans for USB devices and connects to the first one whose vendor
  /// ID matches a known Arduino/CDC-ACM chipset (CH340, FTDI, CP210x,
  /// or genuine Arduino). Falls back to the first enumerated device
  /// if none of those vendors match — many cheap Arduino clones
  /// re-use the CH340 VID anyway, but a debug-printed Arduino may
  /// show a custom VID.
  ///
  /// Throws [StateError] when no device is found or the port cannot
  /// be opened. The caller (admin "Connect USB" button) is expected
  /// to surface the error via SnackBar.
  Future<bool> connect() async {
    final List<UsbDevice> devices = await UsbSerial.listDevices();
    if (devices.isEmpty) {
      throw StateError('No hay dispositivos USB conectados');
    }
    final UsbDevice device = devices.firstWhere(
      (UsbDevice d) =>
          d.vid == 0x1A86 || // CH340 (most Arduino clones)
          d.vid == 0x0403 || // FTDI
          d.vid == 0x10C4 || // CP210x
          d.vid == 0x2341 || // Arduino
          d.vid == 0x2A03, // Arduino (alternate)
      orElse: () => devices.first,
    );
    final UsbPort? port = await device.create();
    if (port == null) {
      throw StateError('No se pudo abrir el puerto USB');
    }
    await port.open();
    await port.setDTR(true);
    await port.setRTS(true);
    await port.setPortParameters(
      9600,
      UsbPort.DATABITS_8,
      UsbPort.STOPBITS_1,
      UsbPort.PARITY_NONE,
    );
    _port = port;
    _subscription = port.inputStream?.listen(
      _onData,
      onError: (Object _) {
        // Port errors are non-fatal — the caller can re-call
        // [connect]. We do not propagate; the stream may continue
        // after the error.
      },
      cancelOnError: false,
    );
    return true;
  }

  void _onData(Uint8List data) {
    for (final int byte in data) {
      if (byte == 0x01) {
        _triggerPulse();
        return; // one pulse per chunk is enough
      }
    }
  }

  bool _triggerPulse() {
    if (!_debounce.tryPulse()) return false;
    _callback?.call();
    return true;
  }

  /// Test-only entry point: feeds raw bytes through the same
  /// dispatch + debounce path the real USB stream uses. Lets
  /// integration tests validate the protocol without needing
  /// a physical device or a mocked `UsbPort`.
  @visibleForTesting
  void feedBytesForTest(Uint8List data) => _onData(data);

  /// Indicates whether a port is currently open and reading.
  bool get isConnected => _port != null;

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _port?.close();
    _port = null;
    _callback = null;
    _debounce.dispose();
  }
}
