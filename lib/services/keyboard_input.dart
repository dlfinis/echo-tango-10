/// Web keyboard input for the arcade timer.
///
/// Pure [InputService] implementation (not a widget). Pairs with the
/// [KeyboardInputWidget] adapter that lives in the widget tree and
/// pumps `Focus`/`onKeyEvent` Space presses into this service.
///
/// PR2 will extend this class with the Web Serial API gated behind a
/// "Connect USB" button (see design risk #5).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/stopwatch_controller.dart';
import 'input_service.dart';

/// Web keyboard input: a thin debounce-gated callback dispatcher.
///
/// The actual key listening lives in [KeyboardInputWidget], which calls
/// [triggerPulse] on Space. The debounce lives here so the contract
/// matches the spec regardless of input source.
class KeyboardInput implements InputService {
  void Function()? _callback;
  final StopwatchController _debounce;

  KeyboardInput({StopwatchController? debounce})
      : _debounce = debounce ?? StopwatchController();

  @override
  void onPulse(void Function() cb) {
    _callback = cb;
  }

  /// Pumps a key event through the debounce gate. Returns whether the
  /// pulse was accepted (true) or suppressed (false).
  bool triggerPulse() {
    if (!_debounce.tryPulse()) return false;
    _callback?.call();
    return true;
  }

  @override
  void dispose() {
    _callback = null;
    _debounce.dispose();
  }
}

/// Widget adapter that listens for the Space key and forwards it to a
/// [KeyboardInput] service. Re-claims focus on user interaction so the
/// listener survives route changes / dialogs stealing focus.
class KeyboardInputWidget extends StatefulWidget {
  const KeyboardInputWidget({super.key, required this.service, this.child});

  final KeyboardInput service;
  final Widget? child;

  @override
  State<KeyboardInputWidget> createState() => _KeyboardInputWidgetState();
}

class _KeyboardInputWidgetState extends State<KeyboardInputWidget> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'arcade-input');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _claimFocus());
  }

  void _claimFocus() {
    if (!mounted) return;
    _focusNode.requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.space) {
      return KeyEventResult.ignored;
    }
    widget.service.triggerPulse();
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (_) => _claimFocus(),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _claimFocus(),
        child: Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: _onKey,
          child: widget.child ?? const SizedBox.expand(),
        ),
      ),
    );
  }
}
