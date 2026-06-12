/// InvaderSpritePainter — single-sprite Space Invader (the classic
/// 11-column x 8-row "crab") rendered as pixel art by [CustomPainter].
///
/// One painter, four expressions. Each expression's animation is
/// driven by a single `t` value in `[0, 1]` that the parent widget
/// feeds in (typically the `value` of an `AnimationController` wrapped
/// in a `CurvedAnimation`). The painter knows nothing about the
/// controller — it just renders whatever the current `t` says.
///
/// Expressions:
///   * `victoria`    — 2-frame dance loop (arms/legs/antennae swap)
///                     + vertical bounce (±4 px at 3 Hz)
///                     + full-body rotation (±5° at 4 Hz).
///                     Wide-open eyes with a single highlight pixel.
///   * `casi`        — static. Flat-line eyes, one arm half-raised,
///                     a "..." bubble above the head. `t` is ignored
///                     (rendering is identical at t=0 and t=1).
///   * `niPorAsomo`  — looping "glitch CRT" corruption effect driven
///                     by a 2.5s repeat controller. The body color
///                     RGB-splits between cyan and red at 2 Hz, each
///                     row wobbles ±3 px horizontally at 8 Hz and
///                     ±1.5 px vertically at 6 Hz, and the X-shape
///                     eyes flicker on/off at ~7 Hz. The invader is
///                     ALWAYS at full size and full alpha — the
///                     "glitch" reads as continuous motion (jitter +
///                     color swap + eye flicker), not a fade.
///                     `t=0` and `t=1` → assembled, full-scale,
///                     full-alpha (loop is seamless).
///   * `tePasaste`   — one-shot explosion. t<0.3: 4 colored squares
///                     pulse outward in a cross pattern. t>=0.3:
///                     squares fly outward and fade. `t=1` → nothing.
///
/// The painter is intentionally stateless across paints (the rotation
/// and bounce are derived from `t` and the column index, not stored
/// across calls). This means the widget only has to keep one
/// `CustomPaint` and re-render at the controller's tick rate.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The four expressions the painter understands. Values match the
/// `_verdict` enum names in `result_screen.dart` (without the leading
/// underscore / enum prefix) so the screen can pass the enum's
/// `name` field directly.
enum InvaderExpression { victoria, casi, niPorAsomo, tePasaste }

/// A single animated Space Invader sprite, drawn from a hard-coded
/// 11-column x 8-row pixel grid. The painter scales the whole grid
/// to fit the supplied canvas via [pixelSize].
class InvaderSpritePainter extends CustomPainter {
  InvaderSpritePainter({
    required this.expression,
    required this.pixelSize,
    required this.t,
    required this.colors,
  });

  /// Which expression to render. Drives both shape and animation.
  final InvaderExpression expression;

  /// Logical px per "pixel" of the sprite. The full sprite is
  /// 11 cols x 8 rows, so the natural on-screen size is
  /// `11 * pixelSize` x `8 * pixelSize`.
  final double pixelSize;

  /// Animation progress in `[0, 1]`. 0 = just-started, 1 = done.
  /// For 'casi' the value is ignored (sprite is static).
  final double t;

  /// Body and cavity colors. `colors[0]` = body fill,
  /// `colors[1]` = eyes/mouth ("carved out" pixels).
  final List<Color> colors;

  // ---- Grid constants -------------------------------------------------------

  static const int _cols = 11;
  static const int _rows = 8;

  // ---- Pixel grids (1 = body, 0 = cavity) -----------------------------------
  // Hand-tuned to match the classic Space Invaders "crab" sprite.
  // The grid is stored as a flat list of (col, row) pairs for fast lookup.
  // See _victoriaFrame0 / _victoriaFrame1 / _casi / _niPorAsomo below.

  /// Frame 0 of the victoria dance. Arms up, legs together, antennae
  /// straight up. The bottom row is the leg "skirt".
  static const List<List<int>> _victoriaFrame0 = <List<int>>[
    // 0  1  2  3  4  5  6  7  8  9  10
    <int>[0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0], // row 0: antennae pair (centred)
    <int>[0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0], // row 1: antennae thicker
    <int>[0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0], // row 2: head crest
    <int>[1, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1], // row 3: eyes carved out
    <int>[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1], // row 4: body
    <int>[0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0], // row 5: body narrows
    <int>[0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0], // row 6: outer legs
    <int>[0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0], // row 7: inner legs (apart)
  ];

  /// Frame 1 of the victoria dance. Arms down/in, legs together,
  /// antennae tilted outward.
  static const List<List<int>> _victoriaFrame1 = <List<int>>[
    // 0  1  2  3  4  5  6  7  8  9  10
    <int>[0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0], // row 0
    <int>[0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0], // row 1: antennae tilted
    <int>[0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0], // row 2
    <int>[1, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1], // row 3
    <int>[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1], // row 4
    <int>[0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0], // row 5: arms pulled in
    <int>[0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0], // row 6: legs together (outside)
    <int>[0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0], // row 7: legs together (inside)
  ];

  /// CASI (confused / sad) — flat-line eyes, one arm half-raised, the
  /// other down. A "..." bubble hovers above the head (drawn as 3
  /// cavity pixels inside the sprite's own grid — see _drawCasiBubble).
  static const List<List<int>> _casi = <List<int>>[
    // 0  1  2  3  4  5  6  7  8  9  10
    <int>[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], // row 0
    <int>[0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0], // row 1: small antenna nub
    <int>[0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0], // row 2
    <int>[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1], // row 3: flat-line eyes = solid row
    <int>[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1], // row 4: body
    <int>[0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0], // row 5: right arm down/half
    <int>[0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0], // row 6: outer legs
    <int>[0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0], // row 7: inner legs
  ];

  /// NI POR ASOMO (falling apart). Static layout — the painter splits
  /// the rows apart at paint time based on `t`. Eyes are X shapes
  /// (drawn as cavity pixels in row 3).
  static const List<List<int>> _niPorAsomo = <List<int>>[
    // 0  1  2  3  4  5  6  7  8  9  10
    <int>[0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0], // row 0: antenna
    <int>[0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0], // row 1
    <int>[0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0], // row 2
    <int>[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1], // row 3: body (X eyes drawn separately)
    <int>[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1], // row 4: body
    <int>[0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0], // row 5
    <int>[0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0], // row 6
    <int>[0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0], // row 7
  ];

  // ---- Eye / cavity pixels drawn AFTER the body (1-pixel overlay) ---------

  /// Open round eyes (carved-out pixels) for `victoria`.
  static final List<List<bool>> _victoriaEyes = _boolGrid(<String>[
    '.X.X.',
    'X.X.X',
  ], invert: true);

  /// The small highlight pixel that sits inside each open victoria eye.
  /// (Carved-out from the body colour so the eye reads as wide-open.)
  static const List<Offset> _victoriaEyeHighlights = <Offset>[
    Offset(1, 4),
    Offset(9, 4),
  ];

  /// Flat-line eyes for `casi`: a 1-pixel-high slit on row 3.
  /// (Already encoded in _casi by being a full row of body pixels —
  /// the "carved" effect is achieved by overlaying a contrasting
  /// 1-pixel line in [_drawCasiEyes].)
  static final List<List<bool>> _casiFlatEyes = _boolGrid(<String>[
    'XXXXX',
    'XXXXX',
  ], invert: true);

  /// X-shape eyes for `niPorAsomo`: 2 crossed pixels per eye.
  static final List<List<bool>> _niXLeftEye = _boolGrid(<String>[
    'X.X',
    '.X.',
    'X.X',
  ], invert: true);

  @override
  void paint(Canvas canvas, Size size) {
    final Color body = colors.isNotEmpty ? colors.first : const Color(0xFF00FF66);
    final Color cavity =
        colors.length > 1 ? colors[1] : const Color(0xFF000000);

    switch (expression) {
      case InvaderExpression.victoria:
        _paintVictoria(canvas, size, body, cavity);
        break;
      case InvaderExpression.casi:
        _paintCasi(canvas, size, body, cavity);
        break;
      case InvaderExpression.niPorAsomo:
        _paintNiPorAsomo(canvas, size, body, cavity);
        break;
      case InvaderExpression.tePasaste:
        _paintTePasaste(canvas, size, body, cavity);
        break;
    }
  }

  // -------------------------------------------------------------------------
  // VICTORIA — dance loop, bounce, rotate, happy eyes
  // -------------------------------------------------------------------------
  void _paintVictoria(Canvas canvas, Size size, Color body, Color cavity) {
    final double tClamped = t.clamp(0.0, 1.0);

    // 2-frame dance loop. At 6 Hz and a 4s repeat-reverse
    // AnimationController the parent drives t back and forth
    // 0..1..0, so we modulo by 1 in a triangular way to pick a
    // frame index.
    // Parent: AnimationController(duration: 4s, repeat(reverse: true))
    // → t goes 0→1→0→1... over 8s. We use the *unsigned* phase
    // (always 0..1) to pick a frame.
    // 2-frame dance loop at 6 Hz: with the parent controller at
    // 1s repeat (t goes 0→1 in 1s), t*6 goes 0→6 over 1s, % 2
    // gives 6 swaps/sec.
    final double frame = (tClamped * 6.0) % 2.0;
    final int frameIndex = frame < 1.0 ? 0 : 1;
    final List<List<int>> grid =
        frameIndex == 0 ? _victoriaFrame0 : _victoriaFrame1;

    // Vertical bounce — the parent controller's t is 0→1→0 in 4s,
    // which is 0.25 Hz. The spec asks for 3 Hz; we derive the bounce
    // from t so it's stable across frame rates.
    final double bounce = math.sin(tClamped * 2 * math.pi * 3.0) * 4.0;

    // Body rotation — 4 Hz, ±5° (0.0873 rad).
    final double rot =
        math.sin(tClamped * 2 * math.pi * 4.0) * (5.0 * math.pi / 180.0);

    final double spriteW = _cols * pixelSize;
    final double spriteH = _rows * pixelSize;
    final double originX = (size.width - spriteW) / 2.0;
    final double originY = (size.height - spriteH) / 2.0 + bounce;

    canvas.save();
    canvas.translate(size.width / 2.0, size.height / 2.0 + bounce);
    canvas.rotate(rot);
    canvas.translate(-size.width / 2.0, -size.height / 2.0);

    _drawBodyGrid(canvas, originX, originY, grid, body);

    // Happy eyes — open round eyes with a single highlight pixel.
    _drawEyePair(
      canvas,
      originX,
      originY,
      body: body,
      cavity: cavity,
      // Eyes are 5 cols wide, centred. With 11 cols they start at col 1
      // and span to col 9. The 3x2 grid of carved-out pixels is at
      // row 3..4.
      leftCol: 1,
      rightCol: 6,
      topRow: 3,
      eyePattern: _victoriaEyes,
    );

    // Add a small highlight pixel inside each eye (carved from the body
    // so it reads as a glint).
    final Paint highlight = Paint()..color = cavity;
    for (final Offset px in _victoriaEyeHighlights) {
      final Rect r = Rect.fromLTWH(
        originX + px.dx * pixelSize,
        originY + px.dy * pixelSize,
        pixelSize,
        pixelSize,
      );
      canvas.drawRect(r, highlight);
    }

    canvas.restore();
  }

  // -------------------------------------------------------------------------
  // CASI — static, flat-line eyes, "..." bubble
  // -------------------------------------------------------------------------
  void _paintCasi(Canvas canvas, Size size, Color body, Color cavity) {
    final double spriteW = _cols * pixelSize;
    final double spriteH = _rows * pixelSize;
    final double originX = (size.width - spriteW) / 2.0;
    final double originY = (size.height - spriteH) / 2.0;

    _drawBodyGrid(canvas, originX, originY, _casi, body);

    // "..." thinking bubble — 3 small cavity dots, drawn 1 row above
    // the head (i.e. one pixelSize above originY - 2*pixelSize, with
    // a 4px gap as the spec requested).
    const double gap = 4.0;
    final double dotY = originY - gap - pixelSize;
    final Paint dot = Paint()..color = cavity;
    final double firstDotX = (size.width / 2.0) - 1.5 * pixelSize;
    for (int i = 0; i < 3; i++) {
      final Rect r = Rect.fromLTWH(
        firstDotX + i * pixelSize,
        dotY,
        pixelSize,
        pixelSize,
      );
      canvas.drawRect(r, dot);
    }

    // Flat-line eyes: carve a horizontal 1-px line on row 3.
    _drawEyePair(
      canvas,
      originX,
      originY,
      body: body,
      cavity: cavity,
      leftCol: 1,
      rightCol: 6,
      topRow: 3,
      eyePattern: _casiFlatEyes,
    );
  }

  // -------------------------------------------------------------------------
  // NI POR ASOMO — glitch CRT corruption
  //
  // The parent controller is a 2.5s `repeat()`, so t goes 0→1 over
  // 2.5s and then loops back to 0. All effects are derived from
  // t inside the painter — no Transform wrappers, no
  // `canvas.save/translate` outside the body draw. At t=0 the
  // sprite is assembled, full-scale, full-alpha and full-color;
  // at t=1 it is the same. The loop is seamless.
  //
  // Effects layered each frame:
  //   1. RGB split      — body color alternates between a +cyan
  //                       blend and a +red blend every 0.2s of t
  //                       (5 swaps per 2.5s cycle = 2 Hz). Gives
  //                       the chromatic aberration look of a
  //                       broken CRT.
  //   2. Per-row jitter — each row shifts horizontally (±3 px at
  //                       8 Hz) and vertically (±1.5 px at 6 Hz),
  //                       phased by row index so adjacent rows
  //                       wobble out of sync. High-frequency
  //                       wobble per row, cheap to draw.
  //   3. Eye flicker    — X-eyes gate visible on/off every ~0.14s
  //                       (~7 Hz). When "off" the body color fills
  //                       the eye pixels. The flicker is a square
  //                       wave, not an alpha fade — the eye is
  //                       either fully there or fully replaced by
  //                       body color.
  //
  // The invader is ALWAYS at full size and full alpha. The
  // "glitch" reads as continuous motion (jitter + color swap +
  // eye flicker) rather than a fade-in / fade-out — that was the
  // previous behavior, which made the sprite look static after
  // the first 200ms of each cycle.
  // -------------------------------------------------------------------------
  void _paintNiPorAsomo(Canvas canvas, Size size, Color body, Color cavity) {
    final double tClamped = t.clamp(0.0, 1.0);

    final double spriteW = _cols * pixelSize;
    final double spriteH = _rows * pixelSize;
    final double originX = (size.width - spriteW) / 2.0;
    final double originY = (size.height - spriteH) / 2.0;

    // (1) RGB split — 2 Hz square wave (5 swaps per 2.5s cycle).
    final Color glitchBody =
        (tClamped * 5.0) % 2.0 < 1.0
            ? (Color.lerp(body, Colors.cyan, 0.55) ?? body)
            : (Color.lerp(body, Colors.red, 0.55) ?? body);

    // (3) Eye flicker — 7 Hz square wave. When "off" the eye
    // pixels are covered with the body color so the face is
    // featureless for that frame.
    final bool eyesVisible = (tClamped * 7.0) % 2.0 < 1.5;

    // (2) Per-row pixel jitter. dx is the horizontal offset
    // (±3 px at 8 Hz), dy is the vertical offset (±1.5 px at
    // 6 Hz). The phase is offset by row index so adjacent rows
    // wobble out of sync — this is what gives the "broken CRT"
    // look. Each row is drawn at the assembled Y plus its own
    // dy, so the rows appear to split apart and rejoin every
    // frame.
    for (int r = 0; r < _rows; r++) {
      final double rowPhase = r * 0.7;
      final double dx =
          math.sin(tClamped * 2 * math.pi * 8.0 + rowPhase) * 3.0;
      final double dy =
          math.cos(tClamped * 2 * math.pi * 6.0 + rowPhase) * 1.5;

      final Paint bodyPaint = Paint()..color = glitchBody;
      _drawBodyRow(
        canvas,
        originX + dx,
        originY + r * pixelSize + dy,
        r,
        _niPorAsomo,
        bodyPaint,
      );
    }

    // Eyes are drawn at the assembled position (no jitter) so
    // the Xs themselves don't smear. They toggle between cavity
    // and body color so the face alternates "X-eyed" and
    // featureless.
    final Paint eyePaint = Paint()
      ..color = eyesVisible ? cavity : glitchBody;
    _drawEyePairRaw(
      canvas,
      originX,
      originY,
      paint: eyePaint,
      leftCol: 1,
      rightCol: 6,
      topRow: 3,
      eyePattern: _niXLeftEye,
      eyeHeightRows: 3,
    );
  }

  // -------------------------------------------------------------------------
  // TE PASASTE — explosion (no body, just colored squares)
  // -------------------------------------------------------------------------
  void _paintTePasaste(Canvas canvas, Size size, Color body, Color cavity) {
    final double tClamped = t.clamp(0.0, 1.0);
    final double easeIn = Curves.easeIn.transform(tClamped);

    final double cx = size.width / 2.0;
    final double cy = size.height / 2.0;

    // Four colored squares in a cross pattern: up, down, left, right
    // of the center.
    final List<Color> palette = <Color>[
      const Color(0xFFFF3D00), // red
      const Color(0xFFFF9100), // orange
      const Color(0xFFFFEA00), // yellow
      const Color(0xFFFFFFFF), // white
    ];

    // At t < 0.3 the squares pulse outward in a tight cross.
    // At t >= 0.3 they fly further out and fade.
    // alpha = max(0, 1 - (t - 0.3) / 0.7) for the fade tail.
    final double fadeTail = (tClamped - 0.3) / 0.7;
    final double alpha =
        tClamped < 0.3 ? 1.0 : (1.0 - fadeTail).clamp(0.0, 1.0);

    // Distance: starts at 0 (touching the center), expands through
    // the sprite's radius. Use easeIn so the explosion accelerates.
    final double radius = easeIn * math.min(size.width, size.height) * 0.45;
    // Square size: starts at 1.2x pixelSize, grows slightly with t.
    final double sq = pixelSize * 1.2 * (1.0 + 0.4 * easeIn);

    final List<Offset> dirs = <Offset>[
      const Offset(0, -1), // up
      const Offset(0, 1), // down
      const Offset(-1, 0), // left
      const Offset(1, 0), // right
    ];

    for (int i = 0; i < 4; i++) {
      final Paint p = Paint()
        ..color = palette[i].withValues(alpha: alpha);
      final Offset d = dirs[i];
      final double dx = cx + d.dx * radius;
      final double dy = cy + d.dy * radius;
      canvas.drawRect(
        Rect.fromCenter(center: Offset(dx, dy), width: sq, height: sq),
        p,
      );
    }

    // At t=1 the canvas is empty (alpha is 0 for all four squares).
    // We deliberately do NOT clear the canvas — the parent widget
    // composes over a black background.
  }

  // -------------------------------------------------------------------------
  // Pixel-drawing helpers
  // -------------------------------------------------------------------------

  /// Draw the full body grid (all rows, in order).
  void _drawBodyGrid(Canvas canvas, double originX, double originY,
      List<List<int>> grid, Color body) {
    final Paint paint = Paint()..color = body;
    for (int r = 0; r < _rows; r++) {
      _drawBodyRow(canvas, originX, originY, r, grid, paint);
    }
  }

  /// Draw a single row of the body grid as a series of [ui.canvas.drawRect]
  /// calls (one per "1" pixel). Adjacent pixels are coalesced into a
  /// single Rect to cut down on draw calls for the most common case
  /// (long horizontal runs in the body).
  void _drawBodyRow(Canvas canvas, double originX, double originY, int row,
      List<List<int>> grid, Paint paint) {
    final double y = originY + row * pixelSize;
    final double h = pixelSize;
    int c = 0;
    while (c < _cols) {
      if (grid[row][c] == 0) {
        c++;
        continue;
      }
      // Coalesce a run of 1s starting at c.
      int runStart = c;
      while (c < _cols && grid[row][c] == 1) {
        c++;
      }
      final double x = originX + runStart * pixelSize;
      final double w = (c - runStart) * pixelSize;
      canvas.drawRect(Rect.fromLTWH(x, y, w, h), paint);
    }
  }

  /// Draw a pair of symmetric eyes (carved-out pixels in `cavity` colour).
  /// The `eyePattern` is a small `List<List<bool>>` (true = cavity).
  /// Both eyes use the same pattern by default; the offset of the
  /// right eye is computed from `leftCol + 5` (5-col eye).
  void _drawEyePair(
    Canvas canvas,
    double originX,
    double originY, {
    required Color body,
    required Color cavity,
    required int leftCol,
    required int rightCol,
    required int topRow,
    required List<List<bool>> eyePattern,
    int eyeHeightRows = 2,
  }) {
    final Paint paint = Paint()..color = cavity;
    _drawEyePairRaw(
      canvas,
      originX,
      originY,
      paint: paint,
      leftCol: leftCol,
      rightCol: rightCol,
      topRow: topRow,
      eyePattern: eyePattern,
      eyeHeightRows: eyeHeightRows,
    );
  }

  /// Like [_drawEyePair] but takes a ready-made [Paint] (e.g. with
  /// alpha already applied) instead of a `cavity` color. Used by the
  /// niPorAsomo glitch branch, which flips between cavity and body
  /// paint to make the eyes flicker on and off.
  void _drawEyePairRaw(
    Canvas canvas,
    double originX,
    double originY, {
    required Paint paint,
    required int leftCol,
    required int rightCol,
    required int topRow,
    required List<List<bool>> eyePattern,
    int eyeHeightRows = 2,
  }) {
    final int eyeH = eyePattern.length;
    final int eyeW = eyePattern[0].length;
    for (final int baseCol in <int>[leftCol, rightCol]) {
      for (int r = 0; r < eyeH; r++) {
        for (int c = 0; c < eyeW; c++) {
          if (!eyePattern[r][c]) continue;
          final Rect rect = Rect.fromLTWH(
            originX + (baseCol + c) * pixelSize,
            originY + (topRow + r) * pixelSize,
            pixelSize,
            pixelSize,
          );
          canvas.drawRect(rect, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(InvaderSpritePainter old) =>
      old.expression != expression ||
      old.t != t ||
      old.pixelSize != pixelSize ||
      old.colors.length != colors.length ||
      (colors.isNotEmpty && old.colors[0] != colors[0]) ||
      (colors.length > 1 && old.colors[1] != colors[1]);

  @override
  bool? hitTest(ui.Offset position) => false;
}

/// Build a `List<List<bool>>` from a compact string-grid literal.
/// '.' = false (body), any other char (e.g. 'X') = true (cavity).
/// If [invert] is true the meaning is flipped (used to encode body
/// rows as cavity overlays).
List<List<bool>> _boolGrid(List<String> rows, {bool invert = false}) {
  return rows
      .map((String r) => r
          .split('')
          .map((String ch) => invert ? ch == '.' : ch != '.')
          .toList(growable: false))
      .toList(growable: false);
}
