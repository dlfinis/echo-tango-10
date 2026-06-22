// PR1 — tests for the KioskTheme abstraction and the registry.
//
// Coverage:
//   * `VerdictKind` has the four expected values.
//   * `ClassicTheme` exposes the same values v0.1.0-arcade hardcoded:
//     colors, copy, verdict labels, palette.
//   * `ClassicTheme.backgroundMarchPainter(...)` returns an
//     `InvaderMarchPainter` (proves the theme delegates to the
//     original implementation, not a re-implementation).
//   * `ClassicTheme.resultSpritePainter(...)` returns an
//     `InvaderSpritePainter` for every verdict kind.
//   * `themeFor(id)` returns the matching theme.
//   * `themeFor(null)` / `themeFor('')` / `themeFor('nope')` falls
//     back to the default — never throws.

import 'package:arcade_timer_10s/theme/kiosk_theme.dart';
import 'package:arcade_timer_10s/theme/theme_registry.dart';
import 'package:arcade_timer_10s/theme/themes/classic_theme.dart';
import 'package:arcade_timer_10s/widgets/invader_sprite.dart';
import 'package:arcade_timer_10s/widgets/waiting_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VerdictKind', () {
    test('exposes the four fixed tiers', () {
      expect(
        VerdictKind.values,
        containsAll(<VerdictKind>[
          VerdictKind.victoria,
          VerdictKind.casi,
          VerdictKind.niPorAsomo,
          VerdictKind.tePasaste,
        ]),
      );
      expect(VerdictKind.values.length, 4);
    });
  });

  group('ClassicTheme — v0.1.0-arcade parity', () {
    const KioskTheme theme = ClassicTheme();

    test('id and displayName are stable', () {
      expect(theme.id, 'classic');
      expect(theme.displayName, 'Arcade Clásico');
    });

    test('colors match the v0.1.0-arcade defaults', () {
      expect(theme.backgroundColor, const Color(0xFF121212));
      expect(theme.textColor, const Color(0xFFFFFFFF));
      expect(theme.accentColor, const Color(0xFF00FF00));
      expect(theme.playingBackgroundColor, const Color(0xFFFFFFFF));
    });

    test('playing palette starts at black and ends back at black', () {
      expect(theme.playingColorPalette.first, const Color(0xFF000000));
      expect(theme.playingColorPalette.last, const Color(0xFF000000));
      expect(theme.playingColorPalette.length, 6);
    });

    test('splash and material app titles are pinned to v0.1.0 strings', () {
      expect(theme.splashTitle, 'ARCADE TIMER 10s');
      expect(theme.materialAppTitle, 'Arcade Timer 10s');
    });

    test('invitation messages are the original es-AR list', () {
      expect(theme.invitationMessages, <String>[
        '¡Presioná el botón para jugar!',
        '¿Te animás a los 10 segundos exactos?',
        '¡El que pega en 10.000s gana!',
      ]);
    });

    test('sub-taglines are the original es-AR list', () {
      expect(theme.subTaglines, <String>[
        '¡JUGÁ Y GANÁ EL PREMIO!',
        '¿PODÉS ROMPER EL RÉCORD?',
        '¿TENÉS HABILIDAD?',
        '¿SOS CAPAZ DEL RÉCORD?',
        '¡APUNTÁ AL 10 EXACTO!',
      ]);
    });

    test('playing prep/urgency messages are the original lists', () {
      expect(theme.playingPreparationMessages, <String>[
        'PREPARATÉ',
        'YA VIENE',
        'PODRÁS',
        'ENFOQUE',
        'CONCENTRACIÓN',
      ]);
      expect(theme.playingUrgencyMessages, <String>[
        '¡YA!',
        '¡APURATÉ!',
        '¡PRESIONA!',
        '¡AHORA!',
        '¡DALE YA!',
      ]);
    });

    test('verdict labels match the v0.1.0 strings', () {
      expect(theme.verdictLabel(VerdictKind.victoria), '¡GANASTE!');
      expect(theme.verdictLabel(VerdictKind.casi), '¡CASI, CASI!');
      expect(theme.verdictLabel(VerdictKind.niPorAsomo), '¡NI POR ASOMO!');
      expect(theme.verdictLabel(VerdictKind.tePasaste), '¡TE PASASTE!');
    });

    test('casi caption is the v0.1.0 string', () {
      expect(theme.casiCaption(), '¡POR UN PELO!');
    });

    test('verdict background palette matches v0.1.0 (deep green/amber/red)',
        () {
      expect(theme.verdictBackground(VerdictKind.victoria),
          const Color(0xFF003A0A));
      expect(theme.verdictBackground(VerdictKind.casi),
          const Color(0xFF3A1F00));
      expect(theme.verdictBackground(VerdictKind.niPorAsomo),
          const Color(0xFF2A0505));
      expect(theme.verdictBackground(VerdictKind.tePasaste),
          const Color(0xFF1A0303));
    });

    test('verdict foreground palette matches v0.1.0 (green/amber/reds)', () {
      expect(theme.verdictColor(VerdictKind.victoria),
          const Color(0xFF00FF00));
      expect(theme.verdictColor(VerdictKind.casi),
          const Color(0xFFFFC107));
      expect(theme.verdictColor(VerdictKind.niPorAsomo),
          const Color(0xFFFF7070));
      expect(theme.verdictColor(VerdictKind.tePasaste),
          const Color(0xFFFF5252));
    });
  });

  group('ClassicTheme — painter delegation', () {
    const KioskTheme theme = ClassicTheme();

    test(
        'backgroundMarchPainter returns an InvaderMarchPainter (no re-impl)',
        () {
      final AnimationController c = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(seconds: 1),
      );
      addTearDown(c.dispose);
      final CustomPainter p = theme.backgroundMarchPainter(listenable: c);
      expect(p, isA<InvaderMarchPainter>(),
          reason: 'classic theme must delegate to the original painter');
    });

    test('resultSpritePainter returns an InvaderSpritePainter for every kind',
        () {
      for (final VerdictKind k in VerdictKind.values) {
        final CustomPainter p = theme.resultSpritePainter(
          verdict: k,
          pixelSize: 8.0,
          t: 0.0,
          colors: const <Color>[Color(0xFF00FF66), Color(0xFF000000)],
        );
        expect(p, isA<InvaderSpritePainter>(),
            reason: 'kind=$k must produce an InvaderSpritePainter');
      }
    });

    test('resultSpritePainter maps VerdictKind -> InvaderExpression 1:1', () {
      // Pin the mapping so a refactor that swaps the expression order
      // does not silently change which painter is used for which
      // verdict.
      CustomPainter pick(VerdictKind k) => theme.resultSpritePainter(
            verdict: k,
            pixelSize: 8.0,
            t: 0.0,
            colors: const <Color>[Color(0xFF000000), Color(0xFF000000)],
          );
      expect(
        (pick(VerdictKind.victoria) as InvaderSpritePainter).expression,
        InvaderExpression.victoria,
      );
      expect(
        (pick(VerdictKind.casi) as InvaderSpritePainter).expression,
        InvaderExpression.casi,
      );
      expect(
        (pick(VerdictKind.niPorAsomo) as InvaderSpritePainter).expression,
        InvaderExpression.niPorAsomo,
      );
      expect(
        (pick(VerdictKind.tePasaste) as InvaderSpritePainter).expression,
        InvaderExpression.tePasaste,
      );
    });
  });

  group('ThemeRegistry', () {
    test('allThemes is non-empty and contains classic', () {
      expect(allThemes, isNotEmpty);
      expect(allThemes.map((KioskTheme t) => t.id), contains('classic'));
    });

    test('all theme ids are unique', () {
      final List<String> ids =
          allThemes.map((KioskTheme t) => t.id).toList(growable: false);
      expect(ids.toSet().length, ids.length,
          reason: 'every registered theme must have a unique id');
    });

    test('themeFor(id) returns the matching theme', () {
      final KioskTheme t = themeFor('classic');
      expect(t.id, 'classic');
    });

    test('themeFor(null) falls back to the default', () {
      final KioskTheme t = themeFor(null);
      expect(t.id, kDefaultThemeId);
    });

    test('themeFor("") falls back to the default', () {
      final KioskTheme t = themeFor('');
      expect(t.id, kDefaultThemeId);
    });

    test('themeFor(unknown-id) falls back to the default — never throws', () {
      final KioskTheme t = themeFor('not-a-real-theme-id');
      expect(t.id, kDefaultThemeId);
    });
  });
}
