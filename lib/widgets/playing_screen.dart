/// PLAYING screen — shows the live stopwatch in microsecond resolution.
///
/// The timer is rendered fullscreen via [FittedBox] + a very large base
/// fontSize (320sp), so it scales to fill the available width on any
/// device (Chrome laptop, Fire HD 8, etc.) without manual tweaking.
///
/// 4-decimal display (`/1e6`) honors spec requirement 3.
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
      // FittedBox + scaleDown means the digits always fit the screen
      // width but grow as large as possible. BoxFit.scaleDown never
      // upscales beyond the parent's constraints.
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Text(
            _formatted(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(kDefaultTextColorHex),
              fontSize: 320,
              fontWeight: FontWeight.w900,
              letterSpacing: -8,
              height: 1.0,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}
