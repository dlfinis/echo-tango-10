/// PLAYING screen — shows the live stopwatch in microsecond resolution.
///
/// Renders `elapsedMicroseconds / 1e6` with 4 decimals (spec requirement 3).
/// Schedules a 60 s `Timer` that calls back to the orchestrator if the
/// player never stops — the orchestrator transitions WAITING via the
/// pure state machine.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../state/stopwatch_controller.dart';
import '../utils/constants.dart';

class PlayingScreen extends StatefulWidget {
  const PlayingScreen({
    super.key,
    required this.controller,
    required this.onTimeout,
  });

  final StopwatchController controller;
  final VoidCallback onTimeout;

  @override
  State<PlayingScreen> createState() => _PlayingScreenState();
}

class _PlayingScreenState extends State<PlayingScreen> {
  Timer? _ticker;
  Timer? _timeoutGuard;
  Duration _rendered = Duration.zero;

  @override
  void initState() {
    super.initState();
    // 30 fps is plenty for 4-decimal display and is cheap.
    _ticker = Timer.periodic(
      const Duration(milliseconds: 33),
      (_) => _onTick(),
    );
    _timeoutGuard = Timer(kPlayingTimeout, () {
      if (!mounted) return;
      widget.onTimeout();
    });
  }

  void _onTick() {
    if (!mounted) return;
    setState(() {
      _rendered = widget.controller.elapsed;
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _timeoutGuard?.cancel();
    super.dispose();
  }

  String _formatted() {
    final seconds = _rendered.inMicroseconds / 1000000.0;
    return seconds.toStringAsFixed(4);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(kDefaultBgColorHex),
      body: Center(
        child: Text(
          _formatted(),
          style: const TextStyle(
            color: Color(kDefaultTextColorHex),
            fontSize: 96,
            fontWeight: FontWeight.w900,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
