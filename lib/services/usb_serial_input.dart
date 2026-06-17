/// Android USB serial input. Reads bytes from an Arduino over USB OTG.
///
/// The Arduino protocol is: send a single byte (0x01) on each button
/// press. Anything else is discarded. The 200ms debounce is applied
/// by the [StopwatchController] (same primitive as the Web
/// [KeyboardInput]), so the [InputService] contract is identical
/// regardless of source.
///
/// Uses `package:flutter_libserialport` for the serial-port
/// enumeration + reading. The first available port is picked on
/// [connect] — on a real Android device with an Arduino over USB
/// OTG this resolves to `/dev/ttyUSB0` or `/dev/ttyACM0`.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

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
  SerialPort? _port;
  SerialPortReader? _reader;
  StreamSubscription<Uint8List>? _subscription;

  @override
  void onPulse(void Function() cb) {
    _callback = cb;
  }

  /// Enumerates the available serial ports and opens the first one
  /// at 9600 8N1 for reading.
  ///
  /// Throws [StateError] when no device is found or the port cannot
  /// be opened. The caller (admin "Connect USB" button) is expected
  /// to surface the error via SnackBar.
  Future<bool> connect() async {
    final List<String> ports = SerialPort.availablePorts;
    if (ports.isEmpty) {
      throw StateError('No hay dispositivos seriales conectados');
    }
    final String name = ports.first;
    final SerialPort port = SerialPort(name);
    if (!port.openRead()) {
      throw StateError('No se pudo abrir el puerto serial "$name"');
    }
    // 9600 8N1 is the canonical Arduino bootloader rate.
    port.config = SerialPortConfig()
      ..baudRate = 9600
      ..bits = 8
      ..stopBits = 1
      ..parity = SerialPortParity.none
      ..setFlowControl(SerialPortFlowControl.none);
    _port = port;
    _reader = SerialPortReader(port);
    _subscription = _reader!.stream.listen(
      _onData,
      onError: (Object _) {
        // Stream errors are non-fatal — caller can re-call [connect].
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

  /// Indicates whether a port is currently open and reading.
  bool get isConnected => _port != null && _port!.isOpen;

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _reader?.close();
    _reader = null;
    _port?.close();
    _port?.dispose();
    _port = null;
    _callback = null;
    _debounce.dispose();
  }

  /// Test-only entry point: feeds raw bytes through the same
  /// dispatch + debounce path the real USB stream uses. Lets
  /// integration tests validate the protocol without needing
  /// a physical device or a mocked [SerialPort].
  @visibleForTesting
  void feedBytesForTest(Uint8List data) => _onData(data);
}
