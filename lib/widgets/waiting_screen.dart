/// WAITING screen — invitation loop is shown here.
///
/// In PR1 this is intentionally minimal:
///   * A single hardcoded invitation message (configurable list comes in
///     PR2 via `ConfigStore`).
///   * A gear icon in the bottom-right that prints a placeholder for
///     the admin long-press. The 3 s long-press detection and the full
///     admin screen land in PR2 (task T9).
///   * The `Timer.periodic` for message/leaderboard rotation is added
///     in PR2 once the config store exists.
library;

import 'package:flutter/material.dart';

import '../utils/constants.dart';

class WaitingScreen extends StatefulWidget {
  const WaitingScreen({super.key, this.onAdminGesture});

  /// Forwarded by the parent; placeholder until the admin screen ships.
  final VoidCallback? onAdminGesture;

  @override
  State<WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends State<WaitingScreen> {
  // PR1: hardcoded single message. PR2 will rotate via Timer.periodic.
  static const String _message = '¡Presioná el botón para jugar!';

  void _handleAdminPlaceholder() {
    // PR1 placeholder — PR2 wires the full 3s long-press → AdminScreen.
    // ignore: avoid_print
    print('[admin] long-press detected (PR2 will open AdminScreen)');
    widget.onAdminGesture?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(kDefaultBgColorHex),
      body: SafeArea(
        child: Stack(
          children: [
            // Centered invitation text.
            Center(
              child: Text(
                _message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(kDefaultTextColorHex),
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Gear icon — bottom-right.
            Positioned(
              right: 24,
              bottom: 24,
              child: GestureDetector(
                onLongPress: _handleAdminPlaceholder,
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Icon(
                    Icons.settings,
                    color: Color(kDefaultTextColorHex),
                    size: 32,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
