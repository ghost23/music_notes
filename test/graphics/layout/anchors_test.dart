import 'dart:math' as math;

import 'package:flutter/painting.dart' show MatrixUtils;
import 'package:flutter_test/flutter_test.dart';
import 'package:music_notes_2/graphics/generated/glyph_anchors.dart' show glyphAnchors;
import 'package:music_notes_2/graphics/generated/glyph_definitions.dart' show Glyph;
import 'package:music_notes_2/graphics/glyph_anchor.dart' show GlyphAnchor;
import 'package:music_notes_2/graphics/graphics_model/canvas_primitives.dart'
    show GlyphElement, GroupElement;
import 'package:music_notes_2/graphics/graphics_model/transform.dart'
    show NodeTransform;
import 'package:music_notes_2/graphics/layout/geometry.dart'
    show absoluteTransform;
import 'package:music_notes_2/graphics/layout/glyph_metadata.dart'
    show absoluteAnchorOffset;

/// Unit tests for the WP1-S4 anchor model.
///
/// S4's anchor contribution is deliberately small:
/// - the generated `GlyphAnchor` carries **nullable** fields so *presence* is
///   real (`null` = the glyph does not define that anchor; `Offset.zero` is a
///   legitimate anchor position for some glyphs and is **not** a sentinel for
///   absence). A builder resolves a local anchor offset by **direct field
///   access** on the record, taking the `glyphAnchors` table as a parameter
///   (the S4 testability rule) — there is no separate named-vocabulary type or
///   dispatch.
/// - [absoluteAnchorOffset] is a thin transform-composition util: it takes an
///   already-resolved local offset and composes it with the element's absolute
///   transform (reusing S1's `absoluteTransform`). The local offset is a
///   static per-glyph fact known at build time; only the absolute position is
///   deferred for context-dependent elements (S5), and that deferral is about
///   the target's transform, not the anchor offset.
///
/// All coordinates are staff-space units.
void main() {
  /// Matches an [Offset] within [epsilon] (trig of multiples of π/2 is not
  /// bit-exact).
  Matcher offsetCloseTo(Offset expected, {double epsilon = 1e-10}) =>
      predicate<Offset>(
        (Offset o) =>
            (o.dx - expected.dx).abs() <= epsilon &&
            (o.dy - expected.dy).abs() <= epsilon,
        'an offset close to $expected within $epsilon',
      );

  /// A hand-built anchor table for `noteheadBlack` carrying only the stem
  /// anchors it actually defines in SMUFL. Using a hand-built table keeps the
  /// tests free of global state (the S4 testability rule).
  const noteheadBlackAnchors = <Glyph, GlyphAnchor>{
    Glyph.noteheadBlack: GlyphAnchor(
      stemUpSE: Offset(1.18, -0.168),
      stemDownNW: Offset(0, 0.168),
    ),
  };

  group('local anchor lookup (direct field access, table as parameter)', () {
    test('a known SMUFL anchor is read by direct field access on the record', () {
      // The builder resolves a local anchor offset by reading the field off the
      // GlyphAnchor record, taking the anchor table as a parameter.
      final record = noteheadBlackAnchors[Glyph.noteheadBlack]!;
      expect(record.stemUpSE, const Offset(1.18, -0.168));
      expect(record.stemDownNW, const Offset(0, 0.168));
    });

    test('reads the same values from the generated table (no global state in the path)', () {
      expect(glyphAnchors[Glyph.noteheadBlack]!.stemUpSE,
          const Offset(1.18, -0.168));
      expect(glyphAnchors[Glyph.noteheadBlack]!.stemDownNW,
          const Offset(0, 0.168));
    });

    test('a glyph at the origin anchor returns the origin, not null', () {
      // noteShapeDiamondBlack defines stemDownNW at exactly Offset(0,0): a
      // legitimate origin anchor. It must be returned as a real offset, not
      // null — proving zero is not a sentinel for absence.
      const table = {
        Glyph.noteShapeDiamondBlack: GlyphAnchor(
          stemDownNW: Offset(0, 0),
          stemUpSE: Offset(1.444, 0),
        ),
      };
      expect(table[Glyph.noteShapeDiamondBlack]!.stemDownNW, Offset.zero);
    });

    test('an anchor the glyph does not define is null (presence is real)', () {
      // noteheadBlack defines stem anchors but no opticalCenter.
      final record = noteheadBlackAnchors[Glyph.noteheadBlack]!;
      expect(record.opticalCenter, isNull);
    });

    test('a glyph absent from the table yields no record (null lookup)', () {
      expect(noteheadBlackAnchors[Glyph.noteShapeDiamondBlack], isNull);
    });
  });

  group('absoluteAnchorOffset (local offset composed with the absolute transform)', () {
    // The local anchor offset used throughout. In real use this is resolved by
    // the builder via direct field access; here we hand it in directly.
    const localAnchor = Offset(1.18, -0.168);

    test('identity transform leaves the local offset unchanged', () {
      final element = GlyphElement(
        const NodeTransform.identity(),
        Glyph.noteheadBlack,
      );
      expect(
        absoluteAnchorOffset(element, localAnchor),
        localAnchor,
      );
    });

    test('composes a translated+scaled parent (nested)', () {
      // root: translate (10,20), scale (2,2); child GlyphElement: translate (1,0)
      // child maps (1.18,-0.168) -> (2.18,-0.168); parent scales+translates
      //   -> (2*2.18+10, 2*(-0.168)+20) = (14.36, 19.664)
      final child = GlyphElement(
        const NodeTransform(translation: Offset(1, 0)),
        Glyph.noteheadBlack,
      );
      final root = GroupElement(
        const NodeTransform(translation: Offset(10, 20), scale: Offset(2, 2)),
        [child],
      );

      expect(
        absoluteAnchorOffset(child, localAnchor,
            parentAbsolute: absoluteTransform(root)),
        offsetCloseTo(const Offset(14.36, 19.664)),
      );
    });

    test('composes a 90° clockwise-rotated parent (y-down)', () {
      // root: rotation π/2 ; child: translate (1,0)
      // child maps (1.18,-0.168) -> (2.18,-0.168)
      // 90° cw (y-down): (x,y) -> (-y, x) -> (0.168, 2.18)
      final child = GlyphElement(
        const NodeTransform(translation: Offset(1, 0)),
        Glyph.noteheadBlack,
      );
      final root = GroupElement(
        const NodeTransform(rotation: math.pi / 2),
        [child],
      );

      expect(
        absoluteAnchorOffset(child, localAnchor,
            parentAbsolute: absoluteTransform(root)),
        offsetCloseTo(const Offset(0.168, 2.18)),
      );
    });

    test('composes a mixed nested tree (translation + scale + rotation)', () {
      // root: translate (100,200); group: scale (2,2);
      // leaf GlyphElement: translate (1,0), rotation π/2.
      // leaf SRT (scale 1, rot 90, translate (1,0)) maps (x,y) -> (1 - y, x):
      //   (1.18,-0.168) -> (1.168, 1.18) in group space
      // group scale (2,2) -> (2.336, 2.36)
      // root translate (100,200) -> (102.336, 202.36)
      final leaf = GlyphElement(
        const NodeTransform(translation: Offset(1, 0), rotation: math.pi / 2),
        Glyph.noteheadBlack,
      );
      final group = GroupElement(
        const NodeTransform(scale: Offset(2, 2)),
        [leaf],
      );
      final root = GroupElement(
        const NodeTransform(translation: Offset(100, 200)),
        [group],
      );

      expect(
        absoluteAnchorOffset(leaf, localAnchor,
            parentAbsolute:
                absoluteTransform(group, parentAbsolute: absoluteTransform(root))),
        offsetCloseTo(const Offset(102.336, 202.36)),
      );
    });

    test('agrees with manual S1 composition (reuses absoluteTransform, does not duplicate it)', () {
      // The absolute anchor is exactly local-offset transformed by the node's
      // absolute transform from S1 — i.e. the reader reuses absoluteTransform,
      // it does not recompute composition.
      final leaf = GlyphElement(
        const NodeTransform(translation: Offset(1, 0), rotation: math.pi / 2),
        Glyph.noteheadBlack,
      );
      final group = GroupElement(
        const NodeTransform(scale: Offset(2, 2)),
        [leaf],
      );
      final root = GroupElement(
        const NodeTransform(translation: Offset(100, 200)),
        [group],
      );

      final groupAbs =
          absoluteTransform(group, parentAbsolute: absoluteTransform(root));
      final manual = MatrixUtils.transformPoint(
          groupAbs.multiplied(leaf.transform.toMatrix4()), localAnchor);

      expect(
        absoluteAnchorOffset(leaf, localAnchor, parentAbsolute: groupAbs),
        offsetCloseTo(manual),
      );
    });
  });
}
