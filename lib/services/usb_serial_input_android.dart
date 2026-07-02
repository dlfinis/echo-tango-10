/// Android-only implementation of [UsbSerialInput].
///
/// Reads bytes from an Arduino over USB OTG using the
/// `flutter_libserialport` plugin. The Arduino protocol is: send
/// a single byte (0x01) on each button press. Anything else is
/// discarded. The 200ms debounce is applied by the [StopwatchController]
/// (same primitive as the Web [KeyboardInput]), so the
/// [InputService] contract is identical regardless of source.
///
/// This file uses `dart:ffi` transitively (via the libserialport
/// package), so it MUST NOT be compiled for Web. The facade
/// `usb_serial_input.dart` uses a conditional import to pick this
/// file on Android only.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

import '../state/stopwatch_controller.dart';
import 'input_service.dart';

class UsbSerialInputImpl implements InputService {
  UsbSerialInputImpl({StopwatchController? debounce})
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

  /// Enumerates the available serial ports and opens the first
  /// one at 9600 8N1 for reading.
  ///
  /// Throws [StateError] when no device is found or the port cannot
  /// be opened. The caller (admin "Connect USB" button) surfaces
  /// the error via SnackBar.
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
        triggerPulse();
        return; // one pulse per chunk is enough
      }
    }
  }

  @override
  bool triggerPulse() {
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
  /// dispatch + debounce path the real USB stream uses.
  @visibleForTesting
  void feedBytesForTest(Uint8List data) => _onData(data);
}
