/// Thin wrapper around `dart:core` `Stopwatch` with a debounce gate.
///
/// Why a wrapper?
///   1. The widget layer should not need to know about the 200 ms debounce
///      contract — it just calls [tryPulse].
///   2. It gives us a single seam to unit-test the "is the bounce window
///      open?" invariant in isolation from the actual stopwatch.
library;

import 'dart:async';

import '../utils/constants.dart';

/// Wraps a [Stopwatch] and exposes a pulse-gated API.
///
/// All time math elsewhere in the app is `elapsedMicroseconds / 1e6` to
/// keep microsecond resolution (spec requirement 3).
class StopwatchController {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _debounceTimer;
  bool _acceptingPulses = true;

  /// Whether the controller will accept a new pulse right now.
  bool get isAcceptingPulses => _acceptingPulses;

  /// Mirrors [Stopwatch.isRunning].
  bool get isRunning => _stopwatch.isRunning;

  /// Mirrors [Stopwatch.elapsedMicroseconds] — raw monotonic time.
  int get elapsedMicroseconds => _stopwatch.elapsedMicroseconds;

  /// Mirrors [Stopwatch.elapsed] — convenience for widget tickers.
  Duration get elapsed => _stopwatch.elapsed;

  /// Starts the stopwatch. Opens the debounce window so the next pulse
  /// is accepted (state transition resets the bounce history).
  void start() {
    _stopwatch
      ..reset()
      ..start();
    _resetDebounceWindow();
  }

  /// Stops the stopwatch. Opens the debounce window so the next pulse
  /// (e.g. the Aceptar pulse that leaves RESULT) is accepted cleanly.
  void stop() {
    _stopwatch.stop();
    _resetDebounceWindow();
  }

  /// Resets the stopwatch to zero and stops it. Does NOT touch debounce
  /// (a reset is a controller action, not an input).
  void reset() {
    _stopwatch
      ..stop()
      ..reset();
  }

  /// Attempts to register a pulse.
  ///
  /// Returns `true` if the pulse was accepted (debounce window was open
  /// or was reset by [start]/[stop]); `false` if it was suppressed.
  bool tryPulse() {
    if (!_acceptingPulses) return false;
    _openDebounceWindow();
    return true;
  }

  /// Cancels any pending debounce timer. Call from `dispose()` / teardown.
  void dispose() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _stopwatch.stop();
  }

  void _openDebounceWindow() {
    _acceptingPulses = false;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(kDebounceWindow, () {
      _acceptingPulses = true;
    });
  }

  /// Cancels any pending debounce timer and re-opens the window immediately.
  /// Used by state transitions (start/stop) that should reset the bounce
  /// history rather than start a fresh bounce-suppression window.
  void _resetDebounceWindow() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _acceptingPulses = true;
  }
}
