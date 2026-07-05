import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;
import 'package:flutter/painting.dart' show MatrixUtils;
import 'package:flutter_test/flutter_test.dart';
import 'package:music_notes_2/graphics/generated/glyph_definitions.dart';
import 'package:music_notes_2/graphics/graphics_model/canvas_primitives.dart';
import 'package:music_notes_2/graphics/graphics_model/transform.dart';
import 'package:music_notes_2/graphics/layout/geometry.dart';

/// Unit tests for the free geometry functions of WP1-S1.
///
/// These build hand-built `Element` trees (no glyph metadata, no parser) and
/// assert that:
/// - a node reports its **local** bounding box (pure derived data); and
/// - the free functions compose ancestor transforms to produce the
///   **absolute** transform / bounding box.
///
/// All coordinates are staff-space units.
void main() {
  /// Matches a [Rect] field-by-field within [epsilon] (default 1e-10).
  /// Needed because trig of multiples of π/2 is not bit-exact.
  Matcher rectCloseTo(Rect expected, {double epsilon = 1e-10}) =>
      predicate<Rect>(
        (Rect r) =>
            (r.left - expected.left).abs() <= epsilon &&
            (r.top - expected.top).abs() <= epsilon &&
            (r.right - expected.right).abs() <= epsilon &&
            (r.bottom - expected.bottom).abs() <= epsilon,
        'a rect close to $expected within $epsilon',
      );

  /// Matches an [Offset] within [epsilon] (default 1e-10).
  Matcher offsetCloseTo(Offset expected, {double epsilon = 1e-10}) =>
      predicate<Offset>(
        (Offset o) =>
            (o.dx - expected.dx).abs() <= epsilon &&
            (o.dy - expected.dy).abs() <= epsilon,
        'an offset close to $expected within $epsilon',
      );

  /// Convenience: a leaf rectangle at the given staff-space rect.
  RectElement leaf(NodeTransform transform, Rect rect) =>
      RectElement(transform, rect);

  group('local bounding box', () {
    test('a RectElement reports its own rect locally', () {
      final r = Rect.fromLTRB(1, 2, 3, 4);
      expect(leaf(const NodeTransform(), r).localBoundingBox, r);
    });

    test('a GroupElement folds its children (child transforms included)', () {
      // Child at translation (10, 20) with a 2x2 rect -> occupies (10,20)-(12,22)
      // in the group's local space.
      final group = GroupElement(
        const NodeTransform.identity(),
        [
          leaf(const NodeTransform(translation: Offset(10, 20)), Rect.fromLTWH(0, 0, 2, 2)),
        ],
      );
      expect(group.localBoundingBox, Rect.fromLTWH(10, 20, 2, 2));
    });

    test('an empty GroupElement has a zero local bounding box', () {
      expect(
        GroupElement(const NodeTransform.identity(), const []).localBoundingBox,
        Rect.zero,
      );
    });
  });

  group('absoluteTransform', () {
    test('a root node with identity transform yields the identity matrix', () {
      final node = leaf(const NodeTransform.identity(), Rect.zero);
      final m = absoluteTransform(node);
      final p = MatrixUtils.transformPoint(m, const Offset(5, -7));
      expect(p, const Offset(5, -7));
    });

    test('applies a single node transform when no parent is given', () {
      final node = leaf(const NodeTransform(translation: Offset(3, 4)), Rect.zero);
      expect(MatrixUtils.transformPoint(absoluteTransform(node), const Offset(0, 0)), const Offset(3, 4));
    });

    test('composes a node transform onto a supplied parent-absolute matrix', () {
      final root = GroupElement(const NodeTransform(translation: Offset(100, 200)), []);
      final child = GroupElement(const NodeTransform(translation: Offset(1, 2)), []);
      final parentAbsolute = absoluteTransform(root);
      final childAbsolute = absoluteTransform(child, parentAbsolute: parentAbsolute);
      // (0,0) -> root adds (100,200); child adds (1,2) -> (101,202)
      expect(MatrixUtils.transformPoint(childAbsolute, const Offset(0, 0)), const Offset(101, 202));
      // and a point carried by the child is also offset
      expect(MatrixUtils.transformPoint(childAbsolute, const Offset(5, 5)), const Offset(106, 207));
    });
  });

  group('MatrixUtils.transformPoint / MatrixUtils.transformRect (matrix helpers)', () {
    test('MatrixUtils.transformPoint applies an identity matrix unchanged', () {
      final m = const NodeTransform.identity().toMatrix4();
      expect(MatrixUtils.transformPoint(m, const Offset(2, -3)), const Offset(2, -3));
    });

    test('MatrixUtils.transformPoint applies translation', () {
      final m = const NodeTransform(translation: Offset(5, 6)).toMatrix4();
      expect(MatrixUtils.transformPoint(m, const Offset(1, 1)), const Offset(6, 7));
    });

    test('MatrixUtils.transformRect returns the AABB of transformed corners', () {
      // scale (2,2) on a 1..3 / 1..4 rect -> (2,2)..(6,8)
      final m = const NodeTransform(scale: Offset(2, 2)).toMatrix4();
      expect(MatrixUtils.transformRect(m, Rect.fromLTRB(1, 1, 3, 4)),
          rectCloseTo(Rect.fromLTRB(2, 2, 6, 8)));
    });

    test('MatrixUtils.transformRect on a rotated rect produces a non-trivial AABB', () {
      // 90° rotation of (1,1)-(3,4): corners (-1,1),(-1,3),(-4,3),(-4,1)
      final m = const NodeTransform(rotation: math.pi / 2).toMatrix4();
      expect(MatrixUtils.transformRect(m, Rect.fromLTRB(1, 1, 3, 4)),
          rectCloseTo(Rect.fromLTRB(-4, 1, -1, 3)));
    });
  });

  group('GlyphElement local bounding box', () {
    test('a registered glyph yields a non-empty local box', () {
      final element = GlyphElement(
        const NodeTransform.identity(),
        Glyph.fourStringTabClef,
      );
      expect(element.localBoundingBox, isNot(equals(Rect.zero)));
    });

    test('throws StateError when the glyph has no registered bounding box', () {
      // clefChangeCombining is a real Glyph enum value that is absent from
      // glyphBBoxes. Missing metadata is a programmer/usage error and must
      // surface as an exception, not a null dereference.
      final element = GlyphElement(
        const NodeTransform.identity(),
        Glyph.clefChangeCombining,
      );
      expect(() => element.localBoundingBox, throwsStateError);
    });
  });

  group('absoluteBoundingBox', () {
    test('identity transform leaves the local box unchanged', () {
      final r = Rect.fromLTRB(1, 1, 4, 5);
      final node = leaf(const NodeTransform.identity(), r);
      expect(absoluteBoundingBox(node), r);
    });

    test('nested translation composes', () {
      // root translates (10, 20); child translates (1, 2); leaf rect 0..2 wide.
      final tree = GroupElement(
        const NodeTransform(translation: Offset(10, 20)),
        [
          GroupElement(
            const NodeTransform(translation: Offset(1, 2)),
            [leaf(const NodeTransform.identity(), Rect.fromLTWH(0, 0, 3, 4))],
          ),
        ],
      );
      // (0,0)->(11,22); size (3,4) -> (11,22)-(14,26)
      expect(absoluteBoundingBox(tree), Rect.fromLTWH(11, 22, 3, 4));
    });

    test('pure scale composes', () {
      final tree = GroupElement(
        const NodeTransform(scale: Offset(2, 2)),
        [leaf(const NodeTransform.identity(), Rect.fromLTWH(1, 1, 1, 2))],
      );
      // (1,1)->(2,2); (2,3)->(4,6)
      expect(absoluteBoundingBox(tree), Rect.fromLTWH(2, 2, 2, 4));
    });

    test('90° clockwise rotation composes', () {
      final tree = GroupElement(
        const NodeTransform(rotation: math.pi / 2),
        [leaf(const NodeTransform.identity(), Rect.fromLTRB(1, 1, 3, 4))],
      );
      // corners (1,1),(3,1),(3,4),(1,4) rotated 90° cw (y-down) -> (x,y) = (-y, x)
      // x range -4..-1, y range 1..3
      expect(absoluteBoundingBox(tree), rectCloseTo(Rect.fromLTRB(-4, 1, -1, 3)));
    });

    test('mixed nested: translation + scale + rotation across three levels', () {
      // root: translate (100, 200), scale 1, rot 0
      // group: translate 0, scale (2, 2), rot 0
      // leaf: translate (1, 0), scale 1, rot 90° ; rect = unit square at origin
      final tree = GroupElement(
        const NodeTransform(translation: Offset(100, 200)),
        [
          GroupElement(
            const NodeTransform(scale: Offset(2, 2)),
            [
              leaf(
                const NodeTransform(translation: Offset(1, 0), rotation: math.pi / 2),
                Rect.fromLTWH(0, 0, 1, 1),
              ),
            ],
          ),
        ],
      );

      // Worked out by hand:
      // leaf SRT (scale 1, rot 90, translate (1,0)) maps (x,y) -> (1 - y, x)
      //   rect corners (0,0)->(1,0); (1,0)->(1,1); (1,1)->(0,1); (0,1)->(0,0)
      //   -> box (0,0)-(1,1) in group space (before group scale)
      // group scale (2,2) -> box (0,0)-(2,2)
      // root translate (100,200) -> box (100,200)-(102,202)
      expect(absoluteBoundingBox(tree), rectCloseTo(Rect.fromLTWH(100, 200, 2, 2)));

      // The leaf's own absolute transform applied to a local point agrees:
      final group = tree.elements.first as GroupElement;
      final leafNode = group.elements.first;
      final rootAbs = absoluteTransform(tree);
      final groupAbs = absoluteTransform(group, parentAbsolute: rootAbs);
      final leafAbs = absoluteTransform(leafNode, parentAbsolute: groupAbs);
      // local (0,0) -> (102, 200); local (1,0) -> (102, 202)
      expect(MatrixUtils.transformPoint(leafAbs, const Offset(0, 0)),
          offsetCloseTo(const Offset(102, 200)));
      expect(MatrixUtils.transformPoint(leafAbs, const Offset(1, 0)),
          offsetCloseTo(const Offset(102, 202)));
    });
  });
}
