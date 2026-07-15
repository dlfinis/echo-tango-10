// PR3 — tests for the WorldcupTheme.
//
// Coverage:
//   * Identity (id, displayName) — stable strings the operator
//     sees in the admin picker and that we serialize to prefs.
//   * Colombian flag palette — colors match the brief
//     (#0E1A4A blue, #FFCD00 yellow, #CE1126 red).
//   * Copy in es-CO with football lingo — pinned strings so a
//     copy edit doesn't silently change the kiosk's voice.
//   * Verdict presentation — "¡GOOOOL!" / "¡AL PALO!" /
//     "¡AFUERA!" / "¡SE PITÓ FINAL!" map 1:1 to the four
//     VerdictKind tiers.
//   * Painter delegation — worldcup returns its own painter
//     implementations (FootballMarchPainter,
//     FootballSpritePainter), not the classic ones.
//   * Painter mapping — each VerdictKind maps to the right
//     FootballExpression.

import 'package:arcade_timer_10s/services/config_store.dart';
import 'package:arcade_timer_10s/services/leaderboard.dart';
import 'package:arcade_timer_10s/theme/kiosk_theme.dart';
import 'package:arcade_timer_10s/theme/theme_registry.dart';
import 'package:arcade_timer_10s/theme/themes/worldcup_theme.dart';
import 'package:arcade_timer_10s/widgets/admin_screen.dart';
import 'package:arcade_timer_10s/widgets/football_march_painter.dart';
import 'package:arcade_timer_10s/widgets/football_sprite_painter.dart';
import 'package:arcade_timer_10s/widgets/invader_sprite.dart';
import 'package:arcade_timer_10s/widgets/waiting_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('WorldcupTheme — identity', () {
    const KioskTheme theme = WorldcupTheme();

    test('id and displayName are stable', () {
      expect(theme.id, 'worldcup');
      expect(theme.displayName, 'Selección Colombia');
    });
  });

  group('WorldcupTheme — Selección Colombia palette', () {
    const KioskTheme theme = WorldcupTheme();

    test('azul bandera as background', () {
      expect(theme.backgroundColor, const Color(0xFF0E1A4A));
      expect(theme.waitingScaffoldColor, const Color(0xFF06112E));
    });

    test('amarillo bandera as accent', () {
      expect(theme.accentColor, const Color(0xFFFFCD00));
    });

    test('white text on dark background', () {
      expect(theme.textColor, const Color(0xFFFFFFFF));
    });

    test('playing background stays white for chronograph contrast', () {
      expect(theme.playingBackgroundColor, const Color(0xFFFFFFFF));
    });

    test('playing palette cycles through Selección colors', () {
      expect(theme.playingColorPalette.first, const Color(0xFF000000));
      expect(theme.playingColorPalette, contains(const Color(0xFFFFCD00)));
      expect(theme.playingColorPalette, contains(const Color(0xFFCE1126)));
    });

    test('verdict palette uses Selección colors', () {
      // victoria: amarillo oscuro (gol)
      expect(theme.verdictBackground(VerdictKind.victoria),
          const Color(0xFF3A2E00));
      expect(theme.verdictColor(VerdictKind.victoria),
          const Color(0xFFFFCD00));
      // misses: rojo bandera family
      expect(theme.verdictColor(VerdictKind.niPorAsomo),
          const Color(0xFFFF6B6B));
      expect(theme.verdictColor(VerdictKind.tePasaste),
          const Color(0xFFCE1126));
    });
  });

  group('WorldcupTheme — copy (es-CO, football lingo)', () {
    const KioskTheme theme = WorldcupTheme();

    test('splash and material app titles', () {
      expect(theme.splashTitle, 'PENAL PERFECTO');
      expect(theme.materialAppTitle, 'Penal Perfecto');
    });

    test('invitation messages reference gol / penal', () {
      expect(theme.invitationMessages, hasLength(3));
      expect(
        theme.invitationMessages.any((String m) => m.toLowerCase().contains('gol')),
        isTrue,
        reason: 'invitation copy must mention gol',
      );
      expect(
        theme.invitationMessages.any((String m) => m.contains('penal')),
        isTrue,
        reason: 'invitation copy must mention penal',
      );
    });

    test('sub-taglines are football exclamations', () {
      expect(theme.subTaglines, hasLength(5));
      expect(theme.subTaglines, contains('¡GOOOOL!'));
      expect(
        theme.subTaglines.any((String m) => m.contains('GOL')),
        isTrue,
      );
    });

    test('playing prep / urgency messages in es-CO', () {
      expect(theme.playingPreparationMessages, contains('CONCENTRACIÓN'));
      expect(theme.playingUrgencyMessages, contains('¡PEGALÉ!'));
      expect(theme.playingUrgencyMessages, contains('¡DISPARÁ!'));
    });

    test('verdict labels are the brief\'s football verdict set', () {
      expect(theme.verdictLabel(VerdictKind.victoria), '¡GOOOOL!');
      expect(theme.verdictLabel(VerdictKind.casi), '¡AL PALO!');
      expect(theme.verdictLabel(VerdictKind.niPorAsomo), '¡AFUERA!');
      expect(theme.verdictLabel(VerdictKind.tePasaste), '¡SE PITÓ FINAL!');
    });

    test('CASI caption matches the verdict label for cohesion', () {
      expect(theme.casiCaption(), '¡AL PALO!');
    });
  });

  group('WorldcupTheme — painter delegation', () {
    const KioskTheme theme = WorldcupTheme();

    test('backgroundMarchPainter returns a FootballMarchPainter', () {
      final AnimationController c = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(seconds: 1),
      );
      addTearDown(c.dispose);
      final CustomPainter p = theme.backgroundMarchPainter(listenable: c);
      expect(p, isA<FootballMarchPainter>(),
          reason: 'worldcup theme must use its own painter, not classic');
    });

    test('backgroundMarchPainter does NOT return the classic invader', () {
      final AnimationController c = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(seconds: 1),
      );
      addTearDown(c.dispose);
      final CustomPainter p = theme.backgroundMarchPainter(listenable: c);
      expect(p, isNot(isA<InvaderMarchPainter>()),
          reason: 'worldcup and classic must produce distinct painters');
    });

    test('resultSpritePainter returns a FootballSpritePainter', () {
      final CustomPainter p = theme.resultSpritePainter(
        verdict: VerdictKind.victoria,
        pixelSize: 8.0,
        t: 0.0,
        colors: const <Color>[Color(0xFFFFCD00), Color(0xFF000000)],
      );
      expect(p, isA<FootballSpritePainter>());
      expect(p, isNot(isA<InvaderSpritePainter>()),
          reason: 'worldcup and classic must produce distinct painters');
    });

    test('resultSpritePainter maps VerdictKind -> FootballExpression 1:1',
        () {
      CustomPainter pick(VerdictKind k) => theme.resultSpritePainter(
            verdict: k,
            pixelSize: 8.0,
            t: 0.0,
            colors: const <Color>[Color(0xFF000000), Color(0xFF000000)],
          );
      expect(
        (pick(VerdictKind.victoria) as FootballSpritePainter).expression,
        FootballExpression.victoria,
      );
      expect(
        (pick(VerdictKind.casi) as FootballSpritePainter).expression,
        FootballExpression.casi,
      );
      expect(
        (pick(VerdictKind.niPorAsomo) as FootballSpritePainter).expression,
        FootballExpression.niPorAsomo,
      );
      expect(
        (pick(VerdictKind.tePasaste) as FootballSpritePainter).expression,
        FootballExpression.tePasaste,
      );
    });
  });

  group('ThemeRegistry — worldcup registered + default', () {
    test('allThemes contains worldcup and classic', () {
      final List<String> ids =
          allThemes.map((KioskTheme t) => t.id).toList(growable: false);
      expect(ids, containsAll(<String>['classic', 'worldcup']));
    });

    test('worldcup is the default theme id', () {
      expect(kDefaultThemeId, 'worldcup');
    });

    test('themeFor("worldcup") returns WorldcupTheme', () {
      final KioskTheme t = themeFor('worldcup');
      expect(t.id, 'worldcup');
      expect(t, isA<WorldcupTheme>());
    });

    test('themeFor("classic") returns ClassicTheme', () {
      final KioskTheme t = themeFor('classic');
      expect(t.id, 'classic');
    });

    test('themeFor(null) returns the default — worldcup', () {
      expect(themeFor(null).id, 'worldcup');
    });

    test('themeFor("garbage") falls back to default — worldcup', () {
      expect(themeFor('garbage-id').id, 'worldcup');
    });
  });

  group('AdminScreen — theme picker', () {
    testWidgets('renders the theme picker dropdown with both themes',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final store = await ConfigStore.load();
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: AdminScreen(
          configStore: store,
          leaderboard: Leaderboard(store),
          onExit: () {},
        ),
      ));
      await tester.pumpAndSettle();

      // Section header is on screen.
      expect(find.text('Tema activo'), findsOneWidget);
      // Both themes appear in the dropdown. Tap to open.
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      // Each theme label appears at least once (dropdown shows
      // the active selection AND the menu items).
      expect(find.text('Selección Colombia'), findsWidgets);
      expect(find.text('Arcade Clásico'), findsWidgets);
    });

    testWidgets(
        'selecting a theme persists via ConfigStore and fires onThemeChanged',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final store = await ConfigStore.load();
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      String? notified;
      await tester.pumpWidget(MaterialApp(
        home: AdminScreen(
          configStore: store,
          leaderboard: Leaderboard(store),
          onExit: () {},
          onThemeChanged: (String id) => notified = id,
        ),
      ));
      await tester.pumpAndSettle();

      // Open the dropdown and pick "Arcade Clásico".
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Arcade Clásico').last);
      await tester.pumpAndSettle();

      // Persisted + notified.
      expect(store.activeThemeId(), 'classic');
      expect(notified, 'classic');
    });
  });
}
