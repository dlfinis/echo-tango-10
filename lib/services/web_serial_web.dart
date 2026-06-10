/// Web-target implementation of the Web Serial API connection.
///
/// Uses the browser's `navigator.serial` API through `dart:js_interop`.
/// Forwards any ASCII 'P' (0x50) or 'p' (0x70) byte to
/// [InputService.triggerPulse] — the same gate the Spacebar path uses,
/// so the 200 ms debounce contract is honored by the input service.
///
/// **Dev gate**: requires Chrome (HTTPS or localhost). The connection
/// must be initiated from a user gesture; [AdminScreen]'s button is
/// that gesture.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'input_service.dart';

/// Calls `navigator.serial.requestPort()` via JS interop, opens the
/// selected port at 9600 baud, and pumps any 'P'/'p' bytes into
/// [input] (which is expected to be the [KeyboardInput] service).
///
/// Errors (user cancel, no Web Serial support, IO error) are rethrown
/// so the admin panel can show a snackbar.
Future<void> connectUsbSerial(InputService input) async {
  final Object? navigator = globalContext['navigator'];
  if (navigator == null) {
    throw StateError('No hay `navigator` en este entorno.');
  }
  final Object? serial = (navigator as JSObject).getProperty('serial'.toJS);
  if (serial == null) {
    throw StateError(
      'Web Serial API no soportado. Usá Chrome sobre HTTPS o localhost.',
    );
  }
  final JSObject serialJs = serial as JSObject;

  // navigator.serial.requestPort() → Promise<SerialPort>
  final JSPromise<JSAny?> portPromise =
      serialJs.callMethod<JSPromise<JSAny?>>('requestPort'.toJS);
  final JSAny? jsPortAny = await portPromise.toDart;
  if (jsPortAny == null) {
    throw StateError('No se eligió ningún puerto.');
  }
  final JSObject jsPort = jsPortAny as JSObject;

  // port.open({baudRate: 9600}) → Promise<void>
  final JSAny openOptions = <String, Object>{'baudRate': 9600}.jsify()!;
  final JSPromise<JSAny?> openPromise = jsPort.callMethod<JSPromise<JSAny?>>(
    'open'.toJS,
    openOptions,
  );
  await openPromise.toDart;

  // Start the read loop detached so the admin button returns
  // immediately. The loop closes when the port closes.
  unawaited(_readLoop(jsPort, input));
}

Future<void> _readLoop(JSObject jsPort, InputService input) async {
  final JSAny? readableAny = jsPort.getProperty<JSAny?>('readable'.toJS);
  if (readableAny == null) {
    throw StateError('El puerto no expone un stream legible.');
  }
  final JSObject readable = readableAny as JSObject;
  final JSAny? readerAny =
      readable.callMethod<JSAny?>('getReader'.toJS);
  // getReader() is synchronous in the spec (returns a reader object).
  if (readerAny == null) {
    throw StateError('No se pudo obtener el reader del puerto.');
  }
  final JSObject reader = readerAny as JSObject;

  bool closed = false;
  while (!closed) {
    try {
      final JSPromise<JSAny?> readPromise =
          reader.callMethod<JSPromise<JSAny?>>('read'.toJS);
      final JSAny? resultRaw = await readPromise.toDart;
      if (resultRaw == null) {
        closed = true;
        break;
      }
      final JSObject resultObj = resultRaw as JSObject;
      final JSAny? doneAny = resultObj.getProperty<JSAny?>('done'.toJS);
      final bool done = doneAny is JSBoolean && doneAny.toDart;
      if (done) {
        closed = true;
        break;
      }
      final JSAny? valueAny =
          resultObj.getProperty<JSAny?>('value'.toJS);
      _dispatch(valueAny, input);
    } on Object {
      closed = true;
      break;
    }
  }
}

void _dispatch(Object? value, InputService input) {
  if (value == null) return;
  Uint8List? bytes;
  if (value is Uint8List) {
    bytes = value;
  } else if (value is List<int>) {
    bytes = Uint8List.fromList(value);
  } else if (value is JSObject) {
    final JSAny lengthAny = value.getProperty<JSAny>('length'.toJS);
    final int? length = lengthAny is JSNumber ? lengthAny.toDartInt : null;
    if (length == null) return;
    final List<int> out = <int>[];
    for (int i = 0; i < length; i++) {
      final Object? v = value.getProperty(i.toJS);
      if (v is JSNumber) {
        out.add(v.toDartInt);
      } else if (v is num) {
        out.add(v.toInt());
      }
    }
    bytes = Uint8List.fromList(out);
  }
  if (bytes == null) return;
  for (final int byte in bytes) {
    if (byte == 0x50 || byte == 0x70) {
      // triggerPulse is the same gate the Spacebar path uses. Cast
      // through `dynamic` so we don't introduce a hard dep on the
      // concrete KeyboardInput class.
      try {
        (input as dynamic).triggerPulse();
      } on Object {
        // Input did not implement triggerPulse — fall through silently.
      }
      return;
    }
  }
}
