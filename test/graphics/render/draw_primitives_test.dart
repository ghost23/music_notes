import 'dart:typed_data' show Float64List;
import 'dart:ui' show Canvas, Color, PictureRecorder, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;
import 'package:music_notes_2/graphics/generated/glyph_definitions.dart';
import 'package:music_notes_2/graphics/graphics_model/canvas_primitives.dart';
import 'package:music_notes_2/graphics/graphics_model/styling.dart';
import 'package:music_notes_2/graphics/graphics_model/transform.dart';
import 'package:music_notes_2/graphics/render/draw_primitives.dart';
import 'package:music_notes_2/graphics/render/render_scale.dart';

/// Contract tests for the WP2 render tree-walker (`draw_primitives.dart`).
///
/// They pin three things:
/// - the **no styling defaults** contract — styling is resolved during layout,
///   and the renderer throws if a required scale-free property is missing;
/// - the **full per-node transform** is applied (translation + scale + rotation
///   via `NodeTransform.toMatrix4`), not just translation;
/// - the **unresolved-node refusal** (WP1-S5 render boundary): a node with
///   `isResolved == false` is never drawn.
///
/// Transform assertions use the `paints` recording canvas (no pixels): they
/// check the matrix the renderer feeds to `canvas.transform`, computed from the
/// same `NodeTransform.toMatrix4()` the IR defines — i.e. via the transform
/// math, not a golden image.
void main() {
  /// A recording [Canvas] that needs no real paint surface.
  Canvas canvas() {
    final recorder = PictureRecorder();
    return Canvas(recorder);
  }

  /// The render scaling measure used by the draw-call tests below.
  final renderScale = RenderScale(8);

  /// Matches a `canvas.transform(Float64List)` argument that equals
  /// [expected.storage] within [tolerance] (trig of multiples of π/2 is not
  /// bit-exact across recomputation).
  Matcher transformMatrixCloseTo(Matrix4 expected, {double tolerance = 1e-12}) =>
      predicate<Float64List>(
        (Float64List actual) {
          if (actual.length != expected.storage.length) return false;
          for (var index = 0; index < actual.length; index += 1) {
            if ((actual[index] - expected.storage[index]).abs() > tolerance) {
              return false;
            }
          }
          return true;
        },
        'a transform matrix close to ${expected.storage}',
      );

  group('renderer has no styling defaults — throws on missing styling', () {
    test('a RectElement with unresolved styling throws', () {
      final element = RectElement(
        const NodeTransform.identity(),
        const Rect.fromLTWH(0, 0, 1, 1),
      );
      expect(() => drawElement(canvas(), element, renderScale), throwsStateError);
    });

    test('a stroked element without a strokeWidth throws', () {
      // strokeColor set but no staff-space strokeWidth → incomplete styling.
      final element = RectElement(
        const NodeTransform.identity(),
        const Rect.fromLTWH(0, 0, 1, 1),
        styling: const Styling(strokeColor: Color(0xFF000000)),
      );
      expect(() => drawElement(canvas(), element, renderScale), throwsStateError);
    });

    test('a glyph without a fill color throws', () {
      final element = GlyphElement(
        const NodeTransform.identity(),
        Glyph.fourStringTabClef,
      );
      expect(() => drawElement(canvas(), element, renderScale), throwsStateError);
    });
  });

  group('renderer draws when styling is resolved', () {
    // These do not assert pixels (that is S5's job); they only confirm that a
    // fully-resolved styling does not throw.
    test('a filled RectElement does not throw', () {
      final element = RectElement(
        const NodeTransform.identity(),
        const Rect.fromLTWH(0, 0, 1, 1),
        styling: const Styling(fillColor: Color(0xFF000000)),
      );
      expect(() => drawElement(canvas(), element, renderScale), returnsNormally);
    });

    test('a stroked-with-width RectElement does not throw', () {
      final element = RectElement(
        const NodeTransform.identity(),
        const Rect.fromLTWH(0, 0, 1, 1),
        styling: const Styling(strokeColor: Color(0xFF000000), strokeWidth: 0.13),
      );
      expect(() => drawElement(canvas(), element, renderScale), returnsNormally);
    });

    test('a glyph with a fill color does not throw', () {
      final element = GlyphElement(
        const NodeTransform.identity(),
        Glyph.fourStringTabClef,
        styling: const Styling(fillColor: Color(0xFF000000)),
      );
      expect(() => drawElement(canvas(), element, renderScale), returnsNormally);
    });
  });

  group('full per-node transform is applied (scale + rotation, not translation only)', () {
    // The renderer must feed each node's full NodeTransform.toMatrix4() to the
    // canvas (SRT: scale → rotate → translate). The old shim applied only
    // translation. These assert, via the `paints` recording canvas, that the
    // exact matrix the IR defines is what reaches `canvas.transform` — i.e. via
    // the transform math, not pixels.
    test('a leaf node with non-identity scale + rotation issues its full matrix', () {
      final transform = NodeTransform(
        translation: const Offset(2, 3),
        scale: const Offset(2, 0.5),
        rotation: 0.3,
      );
      final element = RectElement(
        transform,
        const Rect.fromLTWH(0, 0, 1, 1),
        styling: const Styling(fillColor: Color(0xFF000000)),
      );

      expect(
        (Canvas canvas) => drawElement(canvas, element, renderScale),
        paints..transform(matrix4: transformMatrixCloseTo(transform.toMatrix4())),
      );
    });

    test('a nested tree issues each level transform in order (composition)', () {
      final outerTransform = NodeTransform(
        translation: const Offset(10, 0),
        scale: const Offset(1, 1),
        rotation: 1.5707963267948966, // π/2
      );
      final innerTransform = NodeTransform(
        translation: const Offset(0, 5),
        scale: const Offset(0.5, 0.5),
        rotation: 0,
      );
      final tree = GroupElement(
        outerTransform,
        [
          RectElement(
            innerTransform,
            const Rect.fromLTWH(0, 0, 2, 2),
            styling: const Styling(fillColor: Color(0xFF000000)),
          ),
        ],
      );

      expect(
        (Canvas canvas) => drawElement(canvas, tree, renderScale),
        paints
          ..transform(matrix4: transformMatrixCloseTo(outerTransform.toMatrix4()))
          ..transform(matrix4: transformMatrixCloseTo(innerTransform.toMatrix4())),
      );
    });

    test('a leaf draws from its own IR geometry, not pre-transformed coords', () {
      // The rect passed to drawRect is the leaf's local rect; placement is the
      // canvas transform's job, not the renderer's.
      const rect = Rect.fromLTWH(1, 2, 3, 4);
      final element = RectElement(
        const NodeTransform(translation: Offset(10, 10)),
        rect,
        styling: const Styling(fillColor: Color(0xFF000000)),
      );

      expect(
        (Canvas canvas) => drawElement(canvas, element, renderScale),
        paints..rect(rect: rect, color: const Color(0xFF000000)),
      );
    });

    test('the root render scale is applied once, as a canvas scale', () {
      final element = RectElement(
        const NodeTransform.identity(),
        const Rect.fromLTWH(0, 0, 1, 1),
        styling: const Styling(fillColor: Color(0xFF000000)),
      );

      expect(
        (Canvas canvas) => drawElement(canvas, element, renderScale),
        paints..scale(x: renderScale.pixelsPerStaffSpace),
      );
    });
  });

  group('unresolved nodes are refused (WP1-S5 render boundary)', () {
    test('an unresolved leaf throws and never draws', () {
      final element = RectElement(
        const NodeTransform.identity(),
        const Rect.fromLTWH(0, 0, 1, 1),
        styling: const Styling(fillColor: Color(0xFF000000)),
      )
        ..isResolved = false;

      expect(() => drawElement(canvas(), element, renderScale), throwsStateError);
    });

    test('an unresolved node anywhere in the subtree throws', () {
      final unresolved = RectElement(
        const NodeTransform.identity(),
        const Rect.fromLTWH(0, 0, 1, 1),
        styling: const Styling(fillColor: Color(0xFF000000)),
      )
        ..isResolved = false;
      final tree = GroupElement(
        const NodeTransform.identity(),
        [
          RectElement(
            const NodeTransform.identity(),
            const Rect.fromLTWH(0, 0, 1, 1),
            styling: const Styling(fillColor: Color(0xFF000000)),
          ),
          unresolved,
        ],
      );

      expect(() => drawElement(canvas(), tree, renderScale), throwsStateError);
    });

    test('a resolved node does not throw (isResolved defaults to true)', () {
      final element = RectElement(
        const NodeTransform.identity(),
        const Rect.fromLTWH(0, 0, 1, 1),
        styling: const Styling(fillColor: Color(0xFF000000)),
      );
      // isResolved defaults to true — drawing is allowed.
      expect(element.isResolved, isTrue);
      expect(() => drawElement(canvas(), element, renderScale), returnsNormally);
    });
  });

  group('fill + stroke is drawn in two passes (fill then stroke)', () {
    test('an element with both colors draws its geometry twice', () {
      final element = RectElement(
        const NodeTransform.identity(),
        const Rect.fromLTWH(0, 0, 1, 1),
        styling: const Styling(
          fillColor: Color(0xFF000000),
          strokeColor: Color(0xFFFF0000),
          strokeWidth: 0.1,
        ),
      );

      expect(
        (Canvas canvas) => drawElement(canvas, element, renderScale),
        paints..rect()..rect(),
      );
    });
  });
}
