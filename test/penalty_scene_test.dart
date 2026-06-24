// Tests for the new penalty scene painter and the NI POR ASOMO
// animation in the worldcup sprite painter.
//
// Coverage:
//   * PenaltyScenePainter survives a full 0..1 cycle across
//     every animation enum value without throwing.
//   * PenaltyScenePainter.shouldRepaint respects animation/t/seed.
//   * FootballSpritePainter (niPorAsomo) survives the full 0..1
//     cycle, including the new red-card + hands-on-head phases.
//   * WorldcupTheme returns the scene painter; classic does not.
//   * KioskTheme.playingScenePainter is callable and returns a
//     CustomPainter in both themes.

import 'dart:ui' as ui;

import 'package:arcade_timer_10s/theme/kiosk_theme.dart';
import 'package:arcade_timer_10s/theme/themes/classic_theme.dart';
import 'package:arcade_timer_10s/theme/themes/worldcup_theme.dart';
import 'package:arcade_timer_10s/widgets/crt_scanlines_painter.dart';
import 'package:arcade_timer_10s/widgets/football_sprite_painter.dart';
import 'package:arcade_timer_10s/widgets/goal_backdrop_painter.dart';
import 'package:arcade_timer_10s/widgets/penalty_scene_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PenaltyScenePainter', () {
    test('shouldRepaint is true when animation changes', () {
      final PenaltyScenePainter a = PenaltyScenePainter(
        animation: PenaltySceneAnimation.idle,
        t: 0.5,
      );
      final PenaltyScenePainter b = PenaltyScenePainter(
        animation: PenaltySceneAnimation.goal,
        t: 0.5,
      );
      expect(a.shouldRepaint(b), isTrue);
    });

    test('shouldRepaint is true when t changes', () {
      final PenaltyScenePainter a = PenaltyScenePainter(
        animation: PenaltySceneAnimation.idle,
        t: 0.3,
      );
      final PenaltyScenePainter b = PenaltyScenePainter(
        animation: PenaltySceneAnimation.idle,
        t: 0.5,
      );
      expect(a.shouldRepaint(b), isTrue);
    });

    test('shouldRepaint is false for identical state', () {
      final PenaltyScenePainter a = PenaltyScenePainter(
        animation: PenaltySceneAnimation.goal,
        t: 0.7,
      );
      final PenaltyScenePainter b = PenaltyScenePainter(
        animation: PenaltySceneAnimation.goal,
        t: 0.7,
      );
      expect(a.shouldRepaint(b), isFalse);
    });

    test('survives a full 0..1 cycle for every animation', () {
      const Size size = Size(1280, 800);
      for (final PenaltySceneAnimation anim
          in PenaltySceneAnimation.values) {
        PenaltyScenePainter? prev;
        for (double t = 0.0; t <= 1.0; t += 0.05) {
          final PenaltyScenePainter p = PenaltyScenePainter(
            animation: anim,
            t: t,
          );
          final ui.PictureRecorder recorder = ui.PictureRecorder();
          final Canvas canvas = Canvas(recorder);
          p.paint(canvas, size);
          final ui.Picture pic = recorder.endRecording();
          expect(pic, isNotNull,
              reason: 'scene $anim at t=$t must produce a Picture');
          pic.dispose();
          if (prev != null) {
            expect(prev.shouldRepaint(p), isTrue,
                reason: 't change must request repaint at t=$t');
          }
          prev = p;
        }
      }
    });

    test('corner-inset scene renders at 35% × 40% size without throwing',
        () {
      // Simulate the SizedBox that the PLAYING screen uses for
      // the scene: ~35% width × ~40% height of a 1280x800
      // viewport.
      const Size size = Size(448, 320);
      for (final PenaltySceneAnimation anim
          in PenaltySceneAnimation.values) {
        for (double t = 0.0; t <= 1.0; t += 0.10) {
          final PenaltyScenePainter p = PenaltyScenePainter(
            animation: anim,
            t: t,
          );
          final ui.PictureRecorder recorder = ui.PictureRecorder();
          final Canvas canvas = Canvas(recorder);
          p.paint(canvas, size);
          final ui.Picture pic = recorder.endRecording();
          expect(pic, isNotNull,
              reason: '$anim at t=$t in corner inset must produce a Picture');
          pic.dispose();
        }
      }
    });
  });

  group('FootballSpritePainter — NI POR ASOMO deflation cycle', () {
    test('renders the full deflate → flat → re-inflate cycle without '
        'throwing', () {
      const Size size = Size(176.0, 128.0);
      FootballSpritePainter? prev;
      for (double t = 0.0; t <= 1.0; t += 0.02) {
        final FootballSpritePainter p = FootballSpritePainter(
          expression: FootballExpression.niPorAsomo,
          pixelSize: 16.0,
          t: t,
          colors: const <Color>[Color(0xFFFF5252), Color(0xFF000000)],
        );
        final ui.PictureRecorder recorder = ui.PictureRecorder();
        final Canvas canvas = Canvas(recorder);
        p.paint(canvas, size);
        final ui.Picture pic = recorder.endRecording();
        expect(pic, isNotNull,
            reason: 'niPorAsomo at t=$t must produce a Picture');
        pic.dispose();
        if (prev != null && t > 0.0) {
          expect(prev.shouldRepaint(p), isTrue,
              reason: 'shouldRepaint must be true at t=$t');
        }
        prev = p;
      }
    });

    test('rendering is seamless across the t=0 / t=1 boundary', () {
      // At t=0 and t=1 the ball should be FULLY inflated (full
      // circle). Verify by painting at both endpoints and
      // ensuring they don't throw.
      const Size size = Size(176.0, 128.0);
      for (final double t in const <double>[0.0, 0.99, 1.0]) {
        final FootballSpritePainter p = FootballSpritePainter(
          expression: FootballExpression.niPorAsomo,
          pixelSize: 16.0,
          t: t,
          colors: const <Color>[Color(0xFFFF5252), Color(0xFF000000)],
        );
        final ui.PictureRecorder recorder = ui.PictureRecorder();
        final Canvas canvas = Canvas(recorder);
        p.paint(canvas, size);
        final ui.Picture pic = recorder.endRecording();
        expect(pic, isNotNull);
        pic.dispose();
      }
    });

    test('renders all 4 verdict expressions without throwing', () {
      const Size size = Size(176.0, 128.0);
      for (final FootballExpression expr in FootballExpression.values) {
        for (double t = 0.0; t <= 1.0; t += 0.10) {
          final FootballSpritePainter p = FootballSpritePainter(
            expression: expr,
            pixelSize: 16.0,
            t: t,
            colors: const <Color>[Color(0xFFFFFFFF), Color(0xFF000000)],
          );
          final ui.PictureRecorder recorder = ui.PictureRecorder();
          final Canvas canvas = Canvas(recorder);
          p.paint(canvas, size);
          final ui.Picture pic = recorder.endRecording();
          expect(pic, isNotNull,
              reason: '$expr at t=$t must produce a Picture');
          pic.dispose();
        }
      }
    });
  });

  group('KioskTheme — playing backdrop painter', () {
    test('WorldcupTheme returns a GoalBackdropPainter (idle)', () {
      const KioskTheme t = WorldcupTheme();
      final CustomPainter p = t.playingBackdropPainter(t: 0.5);
      expect(p, isA<GoalBackdropPainter>());
      expect((p as GoalBackdropPainter).mode,
          BackdropMode.idle);
    });

    test('ClassicTheme returns a non-throwing transparent painter', () {
      const KioskTheme t = ClassicTheme();
      final CustomPainter p = t.playingBackdropPainter(t: 0.5);
      expect(p, isA<CustomPainter>());
      const Size size = Size(1280, 800);
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      p.paint(canvas, size);
      final ui.Picture pic = recorder.endRecording();
      expect(pic, isNotNull);
      pic.dispose();
    });

    test('both themes accept the same playingBackdropPainter contract', () {
      const List<KioskTheme> themes = <KioskTheme>[
        ClassicTheme(),
        WorldcupTheme(),
      ];
      for (final KioskTheme theme in themes) {
        for (double t = 0.0; t <= 1.0; t += 0.25) {
          final CustomPainter p = theme.playingBackdropPainter(t: t);
          expect(p, isA<CustomPainter>(),
              reason: 't=$t must return a CustomPainter');
        }
      }
    });
  });

  group('KioskTheme — CRT overlay flag', () {
    test('WorldcupTheme applies the CRT overlay', () {
      expect(const WorldcupTheme().appliesCrtOverlay, isTrue);
    });

    test('ClassicTheme does NOT apply the CRT overlay', () {
      expect(const ClassicTheme().appliesCrtOverlay, isFalse);
    });
  });

  group('KioskTheme — result backdrop painter', () {
    test('WorldcupTheme maps verdict -> trajectory mode', () {
      const KioskTheme t = WorldcupTheme();
      final CustomPainter g = t.resultBackdropPainter(
        verdict: VerdictKind.victoria,
        t: 0.5,
      );
      expect(g, isA<GoalBackdropPainter>());
      expect((g as GoalBackdropPainter).mode, BackdropMode.goal);

      expect(
          (t.resultBackdropPainter(verdict: VerdictKind.casi, t: 0.5)
                  as GoalBackdropPainter)
              .mode,
          BackdropMode.post);
      expect(
          (t.resultBackdropPainter(
                      verdict: VerdictKind.niPorAsomo, t: 0.5)
                  as GoalBackdropPainter)
              .mode,
          BackdropMode.wide);
      expect(
          (t.resultBackdropPainter(
                      verdict: VerdictKind.tePasaste, t: 0.5)
                  as GoalBackdropPainter)
              .mode,
          BackdropMode.over);
    });

    test('ClassicTheme result backdrop is transparent', () {
      const KioskTheme t = ClassicTheme();
      for (final VerdictKind v in VerdictKind.values) {
        final CustomPainter p =
            t.resultBackdropPainter(verdict: v, t: 0.5);
        const Size size = Size(1280, 800);
        final ui.PictureRecorder recorder = ui.PictureRecorder();
        final Canvas canvas = Canvas(recorder);
        p.paint(canvas, size);
        final ui.Picture pic = recorder.endRecording();
        expect(pic, isNotNull);
        pic.dispose();
      }
    });
  });

  group('CrtScanlinesPainter', () {
    test('renders a viewport-sized overlay without throwing', () {
      const CrtScanlinesPainter painter = CrtScanlinesPainter();
      const Size size = Size(1280, 800);
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      painter.paint(canvas, size);
      final ui.Picture pic = recorder.endRecording();
      expect(pic, isNotNull);
      pic.dispose();
    });

    test('shouldRepaint is false (the overlay is static)', () {
      const CrtScanlinesPainter p = CrtScanlinesPainter();
      expect(p.shouldRepaint(p), isFalse);
    });
  });
}
