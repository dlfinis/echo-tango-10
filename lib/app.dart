/// Root widget that owns the arcade-timer state machine.
///
/// Responsibilities:
///   * Hold the single [AppState] and the latest [StopwatchController].
///   * Own a [ConfigStore] + [Leaderboard], loaded on first frame.
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

import 'services/config_store.dart';
import 'services/input_service.dart';
import 'services/keyboard_input.dart';
import 'services/leaderboard.dart';
import 'services/web_serial.dart' as web_serial;
import 'models/leaderboard_entry.dart';
import 'state/app_state.dart';
import 'state/stopwatch_controller.dart';
import 'utils/constants.dart';
import 'widgets/admin_screen.dart';
import 'widgets/playing_screen.dart';
import 'widgets/result_screen.dart';
import 'widgets/waiting_screen.dart';
import 'widgets/winner_name_screen.dart';

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

  // Persistence — null until [ConfigStore.load] resolves on the first
  // post-frame callback. The build method renders a thin loader while
  // these are still null.
  ConfigStore? _configStore;
  Leaderboard? _leaderboard;

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

    // Async init — SharedPreferences is async, so we can't await it in
    // initState. Defer to the first post-frame callback.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initPersistence();
    });
  }

  Future<void> _initPersistence() async {
    final ConfigStore store = await ConfigStore.load();
    if (!mounted) return;
    setState(() {
      _configStore = store;
      _leaderboard = Leaderboard(store);
    });
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
        // Asymmetric victory rule (per Diego): win if you hit 10.000s
        // exactly OR overshot by at most 10ms. Coming in short always
        // counts as a miss — the game punishes hesitation, not slop.
        final bool rawVictory = _lastElapsedSeconds >= kTargetSeconds &&
            _lastElapsedSeconds <=
                kTargetSeconds + kVictoryOvershootSeconds;
        // The leaderboard gate: a VICTORIA only advances to
        // WINNER_NAME if the score would crack the top 10. If the
        // leaderboard is full and this score is worse than the
        // worst top-10 entry, the player is shown a single RESULT
        // screen and returned to WAITING.
        final bool isVictory = rawVictory && _qualifiesForTop10(_lastElapsedSeconds);
        nextState = next(_state, TimerEvent.pulse, isVictory: isVictory);
        break;

      case AppState.winnerName:
      case AppState.admin:
        // WinnerName: no pulse should advance — the user types + presses
        // "Aceptar" which calls `_handleAcceptWinner` directly.
        // Admin: inputs are routed through the admin form, not the pulse.
        return;
    }

    if (!mounted) return;
    setState(() => _state = nextState);
  }

  /// Returns true if [elapsedSeconds] would land in the top 10 of the
  /// persisted leaderboard. Empty / short leaderboards always qualify;
  /// a full top-10 only accepts scores better (lower |delta|) than the
  /// 10th-best entry. When the leaderboard is not yet loaded (e.g. a
  /// pulse arriving in the first frame), returns false — i.e. the
  /// player gets a regular RESULT→WAITING cycle, never a missing
  /// name-entry screen.
  bool _qualifiesForTop10(double elapsedSeconds) {
    final Leaderboard? lb = _leaderboard;
    if (lb == null) return false;
    final List<LeaderboardEntry> top = lb.top(10);
    if (top.length < 10) return true;
    final double newDeltaAbs = (elapsedSeconds - kTargetSeconds).abs();
    return newDeltaAbs < top.last.deltaAbs;
  }

  void _handlePlayingTimeout() {
    if (_state != AppState.playing) return;
    _stopwatch.reset();
    if (!mounted) return;
    setState(() => _state = next(_state, TimerEvent.timeout));
  }

  void _openAdmin() {
    if (_state != AppState.waiting) return;
    setState(() => _state = next(_state, TimerEvent.adminGesture));
  }

  void _exitAdmin() {
    if (_state != AppState.admin) return;
    setState(() => _state = next(_state, TimerEvent.exitAdmin));
  }

  void _handleAcceptWinner() {
    if (_state != AppState.winnerName) return;
    setState(() => _state = next(_state, TimerEvent.acceptWinner));
  }

  // WEB SERIAL DEV GATE — requires Chrome HTTPS or localhost
  Future<void> _connectUsbSerial() async {
    if (!kIsWeb) {
      throw UnsupportedError('Web Serial solo disponible en Web.');
    }
    await web_serial.connectUsbSerial(widget.input);
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
        // The chronograph digits use the DSEG7-Classic-Bold font
        // (declared in pubspec.yaml), a 7-segment LCD display face
        // bundled locally so the kiosk works offline. The default
        // body text falls back to the platform sans-serif.
        textTheme: ThemeData.dark().textTheme.apply(
              bodyColor: const Color(kDefaultTextColorHex),
              displayColor: const Color(kDefaultTextColorHex),
            ),
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
    if (_configStore == null || _leaderboard == null) {
      // First-frame loader. Shown for ~1 frame in practice because
      // SharedPreferences mock values are available synchronously on
      // most platforms and the platform channel is fast.
      return const Scaffold(
        backgroundColor: Color(kDefaultBgColorHex),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(kDefaultAccentColorHex),
          ),
        ),
      );
    }
    switch (_state) {
      case AppState.waiting:
        return WaitingScreen(
          configStore: _configStore!,
          leaderboard: _leaderboard!,
          onAdminGesture: _openAdmin,
        );

      case AppState.playing:
        return PlayingScreen(
          controller: _stopwatch,
          onTimeout: _handlePlayingTimeout,
        );

      case AppState.result:
        return ResultScreen(
          elapsedSeconds: _lastElapsedSeconds,
          resultTimeoutSeconds: _configStore!.resultAutoReturnSeconds(),
          onNext: _handlePulse,
        );

      case AppState.winnerName:
        return WinnerNameScreen(
          elapsedSeconds: _lastElapsedSeconds,
          leaderboard: _leaderboard!,
          onAccept: _handleAcceptWinner,
          isEasterEgg: (_lastElapsedSeconds - kTargetSeconds).abs() <
              kEasterEggToleranceSeconds,
        );

      case AppState.admin:
        return AdminScreen(
          configStore: _configStore!,
          leaderboard: _leaderboard!,
          onExit: _exitAdmin,
          onConnectUsb: kIsWeb ? _connectUsbSerial : null,
        );
    }
  }
}
