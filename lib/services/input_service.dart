/// Source-agnostic input contract for the arcade timer.
///
/// Pure Dart, no Flutter widgets — the widget layer is just a thin
/// adapter that pumps key events into this interface.
///
/// Concrete implementations live in `keyboard_input.dart` (Web) and
/// `usb_serial_input.dart` (Android, PR3).
library;

/// Source-agnostic input contract.
abstract class InputService {
  /// Registers a callback to be invoked on every accepted pulse.
  ///
  /// Implementations MUST apply the 200 ms debounce window before
  /// invoking [cb] (see spec requirement 2: "Bounce suppressed").
  void onPulse(void Function() cb);

  /// Manually triggers a pulse through the debounce gate.
  ///
  /// Exposed for debug fallbacks (volume key) and admin test button.
  /// Default implementation is a no-op; concrete services override it.
  void triggerPulse() {}

  /// Releases listeners, timers, native resources. Idempotent.
  void dispose();
}
