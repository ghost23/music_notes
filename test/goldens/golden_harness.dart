import 'dart:ui' show Canvas, Color, Image, Paint, PictureRecorder, Offset;

import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:music_notes_2/graphics/graphics_model/canvas_primitives.dart'
    show Element;
import 'package:music_notes_2/graphics/render/ir_tree_painter.dart'
    show IRTreePainter;
import 'package:music_notes_2/graphics/render/render_scale.dart'
    show RenderScale;

/// Reusable visual-regression (golden) harness (WP2-S5).
///
/// Renders an IR [Element] tree to a rasterised [Image] through the **same**
/// [IRTreePainter] the app uses (S4) — no layout, no duplicated render setup —
/// so golden tests assert against exactly the pixels a real `CustomPaint` would
/// produce. Later work packages (WP3/WP5/WP6) reuse this verbatim, supplying
/// only their own fixtures + reference images ("run throughout": nothing new is
/// built later, only goldens added).
///
/// ## Deterministic inputs
///
/// The call site fixes everything that affects pixels: the [renderScale], the
/// [size], the [viewportOrigin] (where the staff-space origin (0,0) maps on the
/// image), and — by resolving any deferred nodes beforehand — the tree itself.
/// The harness paints a white background so transparent areas are deterministic.
/// The only remaining variable is the render output.

/// Renders [root] through the S4 [IRTreePainter] / S3 tree-walker to an [Image]
/// of [size] device pixels at [renderScale], with [viewportOrigin] mapping the
/// staff-space origin onto the image and a white background.
///
/// This is the golden-render primitive. It delegates all drawing to
/// [IRTreePainter] (the app's render entry); it does no measurement,
/// positioning or layout of its own.
Future<Image> renderTreeToImage(
  Element root, {
  required RenderScale renderScale,
  required Size size,
  Offset viewportOrigin = Offset.zero,
}) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder)
    // Deterministic white background (transparent → white) so the only pixel
    // variable is the rendered tree.
    ..drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFFFFFF))
    ..translate(viewportOrigin.dx, viewportOrigin.dy);
  IRTreePainter(root: root, renderScale: renderScale).paint(canvas, size);
  return recorder.endRecording().toImage(
        size.width.round(),
        size.height.round(),
      );
}

/// Renders [root] and asserts it matches the golden at [goldenKey] (a path
/// relative to the calling test's directory — the standard `matchesGoldenFile`
/// convention). Use `flutter test --update-goldens` to (re)generate the
/// reference; see `test/goldens/README.md` for the workflow.
Future<void> expectTreeMatchesGolden(
  Element root, {
  required RenderScale renderScale,
  required Size size,
  Offset viewportOrigin = Offset.zero,
  required String goldenKey,
}) async {
  await expectLater(
    renderTreeToImage(
      root,
      renderScale: renderScale,
      size: size,
      viewportOrigin: viewportOrigin,
    ),
    matchesGoldenFile(goldenKey),
  );
}
