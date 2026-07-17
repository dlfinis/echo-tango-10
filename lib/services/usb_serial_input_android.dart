/// Android-only implementation of [UsbSerialInput].
///
/// Reads bytes from an Arduino over USB OTG using Android's USB host API
/// through `usb_serial`. The plugin enumerates through `UsbManager` and
/// requests the per-device Android permission before opening the port.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:usb_serial/usb_serial.dart';

import '../state/stopwatch_controller.dart';
import 'input_service.dart';
import 'usb_connection_diagnostics.dart';

class UsbSerialInputImpl implements InputService {
  UsbSerialInputImpl({StopwatchController? debounce})
      : _debounce = debounce ?? StopwatchController();

  final StopwatchController _debounce;
  void Function()? _callback;
  UsbPort? _port;
  StreamSubscription<Uint8List>? _subscription;
  bool _isConnected = false;
  bool _isDisposed = false;

  /// Live operator-facing diagnostics. A connected state alone only proves
  /// that Android opened the port; a received `0x01` proves the full path.
  final ValueNotifier<UsbConnectionDiagnostics> diagnostics =
      ValueNotifier<UsbConnectionDiagnostics>(const UsbConnectionDiagnostics());

  @override
  void onPulse(void Function() cb) {
    _callback = cb;
  }

  /// Finds an Android USB serial device, obtains its runtime permission, and
  /// opens it at 9600 8N1. The caller surfaces failures in the admin panel.
  Future<bool> connect() async {
    if (_isDisposed) {
      throw StateError('El servicio USB ya fue cerrado.');
    }
    await _closePort();
    _update(const UsbConnectionDiagnostics(
      status: UsbConnectionStatus.searching,
    ));

    try {
      final List<UsbDevice> devices = await UsbSerial.listDevices();
      if (devices.isEmpty) {
        throw StateError(
          'No se detectó ningún dispositivo USB. Verificá el adaptador OTG.',
        );
      }

      final UsbDevice device = devices.firstWhere(
        (UsbDevice candidate) => candidate.vid == 0x2341,
        orElse: () => devices.first,
      );
      final String label = _deviceLabel(device);
      _update(UsbConnectionDiagnostics(
        status: UsbConnectionStatus.requestingPermission,
        deviceLabel: label,
      ));

      // create() delegates to Android UsbManager and waits for the user to
      // grant access when it has not already been granted.
      final UsbPort? port = await device.create();
      if (port == null) {
        throw StateError('Android no pudo crear el puerto serial para $label.');
      }

      _update(diagnostics.value.copyWith(
        status: UsbConnectionStatus.connecting,
        clearError: true,
      ));
      if (!await port.open()) {
        throw StateError('No se pudo abrir el puerto serial de $label.');
      }
      await port.setPortParameters(
        9600,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );
      await port.setDTR(true);
      await port.setRTS(true);
      await port.setFlowControl(UsbPort.FLOW_CONTROL_OFF);

      _port = port;
      _isConnected = true;
      _subscription = port.inputStream?.listen(
        _onData,
        onError: _onStreamError,
        onDone: _onStreamDone,
        cancelOnError: false,
      );
      _update(diagnostics.value.copyWith(
        status: UsbConnectionStatus.connected,
        clearError: true,
      ));
      return true;
    } on Object catch (error) {
      await _closePort();
      _update(diagnostics.value.copyWith(
        status: UsbConnectionStatus.error,
        errorMessage: error.toString(),
      ));
      rethrow;
    }
  }

  void _onData(Uint8List data) {
    if (_isDisposed || data.isEmpty) return;
    _update(diagnostics.value.copyWith(
      lastByte: data.last,
      receivedByteCount: diagnostics.value.receivedByteCount + data.length,
    ));
    for (final int byte in data) {
      if (byte == 0x01) {
        if (triggerPulse()) {
          _update(diagnostics.value.copyWith(
            acceptedPulseCount: diagnostics.value.acceptedPulseCount + 1,
          ));
        }
      }
    }
  }

  @override
  bool triggerPulse() {
    if (_isDisposed) return false;
    if (!_debounce.tryPulse()) return false;
    _callback?.call();
    return true;
  }

  /// Indicates whether Android has an open serial port for the Arduino.
  bool get isConnected => _isConnected;

  void _onStreamError(Object error, StackTrace stackTrace) {
    if (_isDisposed) return;
    _isConnected = false;
    _update(diagnostics.value.copyWith(
      status: UsbConnectionStatus.disconnected,
      errorMessage: 'La lectura USB se interrumpió: $error',
    ));
  }

  void _onStreamDone() {
    if (_isDisposed) return;
    _isConnected = false;
    _update(diagnostics.value.copyWith(
      status: UsbConnectionStatus.disconnected,
      errorMessage: 'El Arduino fue desconectado.',
    ));
  }

  Future<void> _closePort() async {
    await _subscription?.cancel();
    _subscription = null;
    await _port?.close();
    _port = null;
    _isConnected = false;
  }

  void _update(UsbConnectionDiagnostics value) {
    diagnostics.value = value;
  }

  String _deviceLabel(UsbDevice device) {
    final String name = device.productName ?? device.deviceName;
    final String vid = (device.vid ?? 0).toRadixString(16).padLeft(4, '0');
    final String pid = (device.pid ?? 0).toRadixString(16).padLeft(4, '0');
    return '$name · $vid:$pid'.toUpperCase();
  }

  @override
  Future<void> dispose() async {
    _isDisposed = true;
    await _closePort();
    _callback = null;
    _debounce.dispose();
  }

  /// Test-only entry point: feeds raw bytes through the same
  /// dispatch + debounce path the real USB stream uses.
  @visibleForTesting
  void feedBytesForTest(Uint8List data) => _onData(data);
}
