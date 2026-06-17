/// Full-screen error state. Black background, an accent-colored
/// error icon, the message in BungeeInline, and an optional retry
/// button.
///
/// Shown by [AppRoot] when [ConfigStore.load] throws (e.g. corrupt
/// SharedPreferences on Android, or a permission error).
library;

import 'package:flutter/material.dart';

import '../utils/constants.dart';

class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(
                  Icons.error_outline,
                  color: Color(kDefaultAccentColorHex),
                  size: 64,
                ),
                const SizedBox(height: 24),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(kDefaultTextColorHex),
                    fontSize: 24,
                    fontFamily: 'BungeeInline',
                    fontFamilyFallback: <String>['Bungee'],
                  ),
                ),
                if (onRetry != null) ...<Widget>[
                  const SizedBox(height: 32),
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(
                      Icons.refresh,
                      color: Color(kDefaultAccentColorHex),
                    ),
                    label: const Text(
                      'Reintentar',
                      style: TextStyle(
                        color: Color(kDefaultAccentColorHex),
                        fontFamily: 'BungeeInline',
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: Color(kDefaultAccentColorHex),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
