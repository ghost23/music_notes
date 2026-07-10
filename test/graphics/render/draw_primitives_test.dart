import 'dart:ui' show Canvas, Color, PictureRecorder, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:music_notes_2/graphics/generated/glyph_definitions.dart';
import 'package:music_notes_2/graphics/graphics_model/canvas_primitives.dart';
import 'package:music_notes_2/graphics/graphics_model/styling.dart';
import 'package:music_notes_2/graphics/graphics_model/transform.dart';
import 'package:music_notes_2/graphics/render/draw_primitives.dart';
import 'package:music_notes_2/graphics/render/render_scale.dart';

/// Contract tests for the temporary render shim (WP1-S2 → WP2).
///
/// These pin the architecture decision that **the renderer has no styling
/// defaults**: styling is resolved during layout, and the renderer throws if a
/// required scale-free property is missing. The shim is a stand-in for the WP2
/// renderer; the contract itself carries forward when WP2 lands.
void main() {
/// A recording [Canvas] that needs no real paint surface.
  Canvas canvas() {
    final recorder = PictureRecorder();
    return Canvas(recorder);
  }

  /// The render scaling measure used by the draw-call tests below.
  final renderScale = RenderScale(8);

  group('renderer has no styling defaults — throws on missing styling', () {
    test('a RectElement with unresolved styling throws', () {
      final element = RectElement(
        const NodeTransform.identity(),
        const Rect.fromLTWH(0, 0, 1, 1),
      );
      expect(() => drawRectElement(canvas(), element, renderScale), throwsStateError);
    });

    test('a stroked element without a strokeWidth throws', () {
      // strokeColor set but no staff-space strokeWidth → incomplete styling.
      final element = RectElement(
        const NodeTransform.identity(),
        const Rect.fromLTWH(0, 0, 1, 1),
        styling: const Styling(strokeColor: Color(0xFF000000)),
      );
      expect(() => drawRectElement(canvas(), element, renderScale), throwsStateError);
    });

    test('a glyph without a fill color throws', () {
      final element = GlyphElement(
        const NodeTransform.identity(),
        Glyph.fourStringTabClef,
      );
      expect(() => drawGlyphElement(canvas(), element, renderScale), throwsStateError);
    });
  });

  group('renderer draws when styling is resolved', () {
    // These do not assert pixels (that is WP2's job); they only confirm that a
    // fully-resolved styling does not throw.
    test('a filled RectElement does not throw', () {
      final element = RectElement(
        const NodeTransform.identity(),
        const Rect.fromLTWH(0, 0, 1, 1),
        styling: const Styling(fillColor: Color(0xFF000000)),
      );
      expect(() => drawRectElement(canvas(), element, renderScale), returnsNormally);
    });

    test('a stroked-with-width RectElement does not throw', () {
      final element = RectElement(
        const NodeTransform.identity(),
        const Rect.fromLTWH(0, 0, 1, 1),
        styling: const Styling(strokeColor: Color(0xFF000000), strokeWidth: 0.13),
      );
      expect(() => drawRectElement(canvas(), element, renderScale), returnsNormally);
    });

    test('a glyph with a fill color does not throw', () {
      final element = GlyphElement(
        const NodeTransform.identity(),
        Glyph.fourStringTabClef,
        styling: const Styling(fillColor: Color(0xFF000000)),
      );
      expect(() => drawGlyphElement(canvas(), element, renderScale), returnsNormally);
    });
  });
}
