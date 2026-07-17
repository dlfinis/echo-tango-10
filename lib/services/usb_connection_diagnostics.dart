import 'package:flutter/foundation.dart';

/// Observable state for the Android USB connection shown to the operator.
enum UsbConnectionStatus {
  idle,
  searching,
  requestingPermission,
  connecting,
  connected,
  disconnected,
  error,
}

/// Immutable USB connection snapshot.
///
/// A connection is only considered working after [status] is connected. Bytes
/// and accepted pulses then prove that the Arduino protocol is reaching the
/// application, not merely that Android sees a USB device.
@immutable
class UsbConnectionDiagnostics {
  const UsbConnectionDiagnostics({
    this.status = UsbConnectionStatus.idle,
    this.deviceLabel,
    this.lastByte,
    this.receivedByteCount = 0,
    this.acceptedPulseCount = 0,
    this.errorMessage,
  });

  final UsbConnectionStatus status;
  final String? deviceLabel;
  final int? lastByte;
  final int receivedByteCount;
  final int acceptedPulseCount;
  final String? errorMessage;

  bool get isConnected => status == UsbConnectionStatus.connected;

  String get statusLabel => switch (status) {
        UsbConnectionStatus.idle => 'Sin conectar',
        UsbConnectionStatus.searching => 'Buscando Arduino',
        UsbConnectionStatus.requestingPermission => 'Solicitando permiso USB',
        UsbConnectionStatus.connecting => 'Abriendo puerto serial',
        UsbConnectionStatus.connected => 'Conectado · 9600 8N1',
        UsbConnectionStatus.disconnected => 'Arduino desconectado',
        UsbConnectionStatus.error => 'Error de conexión',
      };

  String get lastByteLabel => lastByte == null
      ? 'Sin bytes todavía'
      : '0x${lastByte!.toRadixString(16).padLeft(2, '0').toUpperCase()}';

  UsbConnectionDiagnostics copyWith({
    UsbConnectionStatus? status,
    String? deviceLabel,
    int? lastByte,
    int? receivedByteCount,
    int? acceptedPulseCount,
    String? errorMessage,
    bool clearDevice = false,
    bool clearLastByte = false,
    bool clearError = false,
  }) {
    return UsbConnectionDiagnostics(
      status: status ?? this.status,
      deviceLabel: clearDevice ? null : (deviceLabel ?? this.deviceLabel),
      lastByte: clearLastByte ? null : (lastByte ?? this.lastByte),
      receivedByteCount: receivedByteCount ?? this.receivedByteCount,
      acceptedPulseCount: acceptedPulseCount ?? this.acceptedPulseCount,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
