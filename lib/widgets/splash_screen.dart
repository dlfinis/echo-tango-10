/// Full-screen splash shown while the kiosk loads its persistent
/// state. Background = theme.backgroundColor; title and spinner
/// stroke = theme.accentColor; title text = theme.splashTitle.
///
/// Used by [AppRoot] as the boot state before [ConfigStore.load]
/// completes. The optional [theme] parameter defaults to
/// [ClassicTheme] so existing tests and call sites keep working
/// without a theme argument.
library;

import 'package:flutter/material.dart';

import '../theme/kiosk_theme.dart';
import '../theme/themes/classic_theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.theme = const ClassicTheme()});

  final KioskTheme theme;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              theme.splashTitle,
              style: TextStyle(
                color: theme.accentColor,
                fontSize: 48,
                fontFamily: 'BungeeInline',
                fontFamilyFallback: <String>['Bungee'],
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 32),
            CircularProgressIndicator(color: theme.accentColor),
          ],
        ),
      ),
    );
  }
}
