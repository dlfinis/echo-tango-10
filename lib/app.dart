/// Root widget that owns the arcade-timer state machine.
///
/// Responsibilities:
///   * Hold the single [AppState] and the latest [StopwatchController].
///   * Listen to the [InputService] and forward accepted pulses to [next].
///   * Render the right screen for the current state.
///   * Apply the 60 s PLAYING timeout and call [next] with `TimerEvent.timeout`.
///   * On Web, mount a [KeyboardInputWidget] adapter around the active screen
///     so Space key events reach the [InputService].
///
/// This widget is the *only* place that calls `setState` — all child
/// screens are pure presentations of the data passed in.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/input_service.dart';
import 'services/keyboard_input.dart';
import 'state/app_state.dart';
import 'state/stopwatch_controller.dart';
import 'utils/constants.dart';
import 'widgets/playing_screen.dart';
import 'widgets/result_screen.dart';
import 'widgets/waiting_screen.dart';

class AppRoot extends StatefulWidget {
  const AppRoot({super.key, required this.input});

  final InputService input;

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  AppState _state = AppState.waiting;
  final StopwatchController _stopwatch = StopwatchController();
  double _lastElapsedSeconds = 0.0;

  @override
  void initState() {
    super.initState();

    // Force landscape (no-op on Web, real on Android). Doing it here keeps
    // the kIsWeb fork centralized in the app root for PR1; main.dart can
    // still re-assert platform-specific concerns.
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations(<DeviceOrientation>[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }

    widget.input.onPulse(_handlePulse);
  }

  void _handlePulse() {
    // Debounce happens inside the stopwatch controller / input service.
    // The state machine itself only sees filtered events.
    if (!_stopwatch.tryPulse()) return;

    final AppState nextState;
    switch (_state) {
      case AppState.waiting:
        _stopwatch.start();
        nextState = next(_state, TimerEvent.pulse);
        break;

      case AppState.playing:
        _stopwatch.stop();
        _lastElapsedSeconds = _stopwatch.elapsedMicroseconds / 1000000.0;
        nextState = next(_state, TimerEvent.pulse);
        break;

      case AppState.result:
        _stopwatch.reset();
        // PR1 simplification: the WINNER_NAME branch is wired in the pure
        // state machine but always returns to WAITING from the screen.
        // PR2 will feed `isVictory: true` when the delta is in range.
        nextState = next(_state, TimerEvent.pulse);
        break;

      case AppState.winnerName:
      case AppState.admin:
        // No-op until PR2 lands the corresponding screens.
        return;
    }

    if (!mounted) return;
    setState(() => _state = nextState);
  }

  void _handlePlayingTimeout() {
    if (_state != AppState.playing) return;
    _stopwatch.reset();
    if (!mounted) return;
    setState(() => _state = next(_state, TimerEvent.timeout));
  }

  @override
  void dispose() {
    widget.input.dispose();
    _stopwatch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arcade Timer 10s',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(kDefaultBgColorHex),
      ),
      home: _buildInputLayer(child: _buildScreen()),
    );
  }

  /// Wraps the active screen in a transparent input layer.
  ///
  /// On Web this mounts the keyboard listener so Space keys reach the
  /// [InputService]. On Android PR1 the layer is a no-op until PR3 wires
  /// the USB serial listener.
  Widget _buildInputLayer({required Widget child}) {
    if (widget.input is KeyboardInput) {
      return KeyboardInputWidget(
        service: widget.input as KeyboardInput,
        child: child,
      );
    }
    return child;
  }

  Widget _buildScreen() {
    switch (_state) {
      case AppState.waiting:
      case AppState.admin:
      case AppState.winnerName:
        // PR1: admin + winner-name screens not yet built; render WAITING.
        return const WaitingScreen();

      case AppState.playing:
        return PlayingScreen(
          controller: _stopwatch,
          onTimeout: _handlePlayingTimeout,
        );

      case AppState.result:
        return ResultScreen(
          elapsedSeconds: _lastElapsedSeconds,
          onNext: _handlePulse,
        );
    }
  }
}
