/// Full-screen splash shown while the kiosk loads its persistent
/// state. Black background, centered title in BungeeInline, a
/// CircularProgressIndicator below.
///
/// Used by [AppRoot] as the boot state before [ConfigStore.load]
/// completes.
library;

import 'package:flutter/material.dart';

import '../utils/constants.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF000000),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'ARCADE TIMER 10s',
              style: TextStyle(
                color: Color(kDefaultAccentColorHex),
                fontSize: 48,
                fontFamily: 'BungeeInline',
                fontFamilyFallback: <String>['Bungee'],
                letterSpacing: 4,
              ),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(
              color: Color(kDefaultAccentColorHex),
            ),
          ],
        ),
      ),
    );
  }
}
