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

import 'services/audio_service.dart';
import 'services/config_store.dart';
import 'services/input_service.dart';
import 'services/keyboard_input.dart';
import 'services/leaderboard.dart';
import 'services/usb_serial_input.dart';
import 'services/web_serial.dart' as web_serial;
import 'models/leaderboard_entry.dart';
import 'state/app_state.dart';
import 'state/stopwatch_controller.dart';
import 'theme/kiosk_theme.dart';
import 'theme/theme_registry.dart';
import 'utils/constants.dart';
import 'widgets/admin_screen.dart';
import 'widgets/error_screen.dart';
import 'widgets/playing_screen.dart';
import 'widgets/result_screen.dart';
import 'widgets/splash_screen.dart';
import 'widgets/waiting_screen.dart';
import 'widgets/winner_name_screen.dart';

class AppRoot extends StatefulWidget {
  const AppRoot({super.key, required this.input, required this.audio});

  final InputService input;
  final AudioService audio;

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  AppState _state = AppState.waiting;
  final StopwatchController _stopwatch = StopwatchController();
  double _lastElapsedSeconds = 0.0;
  final ValueNotifier<int> _pulseCountNotifier = ValueNotifier<int>(0);
  FocusNode? _volumeUpFallbackFocusNode;

  // Persistence — null until [ConfigStore.load] resolves on the first
  // post-frame callback. The build method renders a thin loader while
  // these are still null.
  ConfigStore? _configStore;
  Leaderboard? _leaderboard;
  _BootStatus _bootStatus = _BootStatus.booting;
  String? _bootError;

  // The active kiosk theme. Defaults to the registered default
  // (classic) so the first frame never depends on async prefs.
  // Re-resolved on every rebuild once _configStore is loaded, so
  // the operator can switch themes from the admin panel without
  // restarting the app.
  KioskTheme _theme = themeFor(null);

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

    if (!kIsWeb && kDebugMode) {
      _volumeUpFallbackFocusNode = FocusNode(debugLabel: 'volume-up-fallback');
    }

    // Async init — SharedPreferences is async, so we can't await it in
    // initState. Defer to the first post-frame callback.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initPersistence();
    });
  }

  Future<void> _initPersistence() async {
    try {
      final ConfigStore store = await ConfigStore.load();
      if (!mounted) return;
      setState(() {
        _configStore = store;
        _leaderboard = Leaderboard(store);
        _theme = themeFor(store.activeThemeId());
        _bootStatus = _BootStatus.ready;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _bootError = e.toString();
        _bootStatus = _BootStatus.error;
      });
    }
  }

  void _handlePulse() {
    _pulseCountNotifier.value++;
    // Audio feedback for the physical button press. Fired BEFORE
    // the debounce check so the operator hears something even on a
    // rejected double-tap.
    widget.audio.playPulse();
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
        // Victory is decided against the operator-configured range in
        // SharedPreferences (admin panel). The same range is passed
        // to the ResultScreen widget so the verdict label and the
        // leaderboard gate stay in lockstep.
        final ConfigStore? store = _configStore;
        final bool rawVictory = store != null &&
            _lastElapsedSeconds >= store.victoryRangeStart() &&
            _lastElapsedSeconds <= store.victoryRangeEnd();
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
    final AppState prevState = _state;
    setState(() => _state = nextState);
    // Audio cue when transitioning INTO the result screen. We
    // classify against the same range passed to ResultScreen so the
    // sound matches the verdict label the player sees.
    if (prevState == AppState.playing && nextState == AppState.result) {
      final ConfigStore? store = _configStore;
      final double start = store?.victoryRangeStart() ?? kDefaultVictoryRangeStart;
      final double end = store?.victoryRangeEnd() ?? kDefaultVictoryRangeEnd;
      final double elapsed = _lastElapsedSeconds;
      if (elapsed >= start && elapsed <= end) {
        widget.audio.playVictory();
      } else if (elapsed < start) {
        // Within 50ms of victory start = CASI; otherwise NI POR ASOMO.
        if ((start - elapsed).abs() < 0.050) {
          widget.audio.playCasi();
        } else {
          widget.audio.playNiPorAsomo();
        }
      } else {
        widget.audio.playTePasaste();
      }
    }
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

  /// Called by the admin theme picker after the operator
  /// switches the active theme. Re-resolves [KioskTheme] from
  /// the registry and triggers a rebuild so the new theme
  /// applies on the next frame.
  void _handleThemeChanged(String themeId) {
    setState(() {
      _theme = themeFor(themeId);
    });
  }

  // USB connect entry point used by the admin "Connect" button.
  //
  // Behaviour by platform:
  //   * Android (Fire HD 8 + Arduino) — calls [UsbSerialInput.connect]
  //     which opens the CDC-ACM port at 9600 8N1 and starts reading.
  //   * Web (dev only)               — opens the Web Serial picker
  //     and pipes any 'P'/'p' bytes into the InputService.
  //   * Any other platform            — throws [UnsupportedError]
  //     so the admin can show a SnackBar.
  Future<void> _connectUsbSerial() async {
    if (widget.input is UsbSerialInput) {
      final UsbSerialInput usb = widget.input as UsbSerialInput;
      await usb.connect();
      return;
    }
    if (!kIsWeb) {
      throw UnsupportedError(
        'Conectar USB solo disponible en Android (Arduino) o Web.',
      );
    }
    await web_serial.connectUsbSerial(widget.input);
  }

  @override
  void dispose() {
    _volumeUpFallbackFocusNode?.dispose();
    _pulseCountNotifier.dispose();
    widget.input.dispose();
    _stopwatch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _theme.materialAppTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _theme.backgroundColor,
        // The chronograph digits use the DSEG7-Classic-Bold font
        // (declared in pubspec.yaml), a 7-segment LCD display face
        // bundled locally so the kiosk works offline. The default
        // body text falls back to the platform sans-serif.
        textTheme: ThemeData.dark().textTheme.apply(
              bodyColor: _theme.textColor,
              displayColor: _theme.textColor,
            ),
      ),
      home: _buildBootGate(child: _buildInputLayer(child: _buildScreen())),
    );
  }

  /// Routes between splash / error / normal flow based on [_bootStatus].
  Widget _buildBootGate({required Widget child}) {
    switch (_bootStatus) {
      case _BootStatus.booting:
        return const SplashScreen();
      case _BootStatus.error:
        return ErrorScreen(
          message: _bootError ?? 'Error desconocido',
          onRetry: _retryBoot,
        );
      case _BootStatus.ready:
        return child;
    }
  }

  void _retryBoot() {
    setState(() {
      _bootStatus = _BootStatus.booting;
      _bootError = null;
      _configStore = null;
      _leaderboard = null;
    });
    _initPersistence();
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

    if (!kIsWeb && kDebugMode) {
      return Focus(
        focusNode: _volumeUpFallbackFocusNode!,
        autofocus: true,
        onKeyEvent: (FocusNode node, KeyEvent event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey != LogicalKeyboardKey.audioVolumeUp) {
            return KeyEventResult.ignored;
          }
          widget.input.triggerPulse();
          return KeyEventResult.handled;
        },
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
      return Scaffold(
        backgroundColor: _theme.backgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            color: _theme.accentColor,
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
          theme: _theme,
        );

      case AppState.playing:
        return PlayingScreen(
          controller: _stopwatch,
          onTimeout: _handlePlayingTimeout,
          theme: _theme,
        );

      case AppState.result:
        return ResultScreen(
          elapsedSeconds: _lastElapsedSeconds,
          resultTimeoutSeconds: _configStore!.resultAutoReturnSeconds(),
          victoryRangeStart: _configStore!.victoryRangeStart(),
          victoryRangeEnd: _configStore!.victoryRangeEnd(),
          onNext: _handlePulse,
          theme: _theme,
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
          onConnectUsb: (kIsWeb || widget.input is UsbSerialInput)
              ? _connectUsbSerial
              : null,
          onThemeChanged: _handleThemeChanged,
          arduinoConnected: (widget.input is UsbSerialInput)
              ? (widget.input as UsbSerialInput).isConnected
              : null,
          arduinoPulseCountNotifier: _pulseCountNotifier,
          onTestPulse: widget.input.triggerPulse,
        );
    }
  }
}

/// Boot state machine for the app root.
///
/// `booting` is the initial state shown while SharedPreferences
/// loads. `ready` is the normal app. `error` is shown if the load
/// throws (e.g. permission denied, corrupt JSON).
enum _BootStatus { booting, ready, error }
