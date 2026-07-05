import 'dart:math' as math;
import 'package:flutter/painting.dart' show MatrixUtils, Offset;
import 'package:flutter_test/flutter_test.dart';
import 'package:music_notes_2/graphics/graphics_model/transform.dart';

/// Unit tests for the staff-space [NodeTransform] value type (WP1-S1).
///
/// Convention under test (see the doc comment on [NodeTransform]):
/// - units are staff-space units (1 staff space = the SMUFL unit;
///   4 staff spaces = 1 staff height = 1 em);
/// - x increases to the right, y increases downward;
/// - a local point is mapped to its parent's space by
///     p' = translation + rotate(rotation) * (scale ⊙ p)
///   i.e. **scale first, then rotate, then translate** (SRT order);
/// - rotation is in radians, clockwise positive (consistent with y-down).
void main() {
  group('NodeTransform.identity', () {
    test('has zero translation, unit scale, zero rotation', () {
      const t = NodeTransform.identity();
      expect(t.translation, Offset.zero);
      expect(t.scale, const Offset(1, 1));
      expect(t.rotation, 0);
      expect(t.isIdentity, isTrue);
    });

    test('default constructor equals identity', () {
      expect(const NodeTransform(), const NodeTransform.identity());
    });
  });

  group('NodeTransform equality', () {
    test('two identical transforms are equal', () {
      expect(
        const NodeTransform(translation: Offset(1, 2), scale: Offset(3, 4), rotation: 0.5),
        const NodeTransform(translation: Offset(1, 2), scale: Offset(3, 4), rotation: 0.5),
      );
    });

    test('differs in any field breaks equality', () {
      const base = NodeTransform(translation: Offset(1, 2), scale: Offset(3, 4), rotation: 0.5);
      expect(base == const NodeTransform(translation: Offset(9, 2), scale: Offset(3, 4), rotation: 0.5), isFalse);
      expect(base == const NodeTransform(translation: Offset(1, 2), scale: Offset(9, 4), rotation: 0.5), isFalse);
      expect(base == const NodeTransform(translation: Offset(1, 2), scale: Offset(3, 4), rotation: 0.9), isFalse);
    });
  });

  group('NodeTransform.copyWith', () {
    test('overrides only the supplied fields', () {
      const base = NodeTransform(translation: Offset(1, 2), scale: Offset(3, 4), rotation: 0.5);
      expect(base.copyWith(translation: const Offset(9, 9)).translation, const Offset(9, 9));
      expect(base.copyWith(translation: const Offset(9, 9)).scale, const Offset(3, 4));
      expect(base.copyWith(translation: const Offset(9, 9)).rotation, 0.5);
    });

    test('returns a new instance (immutability)', () {
      const base = NodeTransform(translation: Offset(1, 2));
      final copy = base.copyWith(rotation: 0.25);
      expect(identical(base, copy), isFalse);
      expect(base.rotation, 0); // original untouched
    });
  });

  group('NodeTransform.toMatrix4 / SRT convention', () {
    Offset apply(NodeTransform t, Offset p) =>
        MatrixUtils.transformPoint(t.toMatrix4(), p);

    test('identity maps every point to itself', () {
      const t = NodeTransform.identity();
      expect(apply(t, const Offset(0, 0)), Offset.zero);
      expect(apply(t, const Offset(2, -3)), const Offset(2, -3));
    });

    test('pure translation offsets the point', () {
      final t = const NodeTransform(translation: Offset(2, 3));
      expect(apply(t, const Offset(0, 0)), const Offset(2, 3));
      expect(apply(t, const Offset(1, 1)), const Offset(3, 4));
    });

    test('pure uniform scale multiplies coordinates', () {
      final t = const NodeTransform(scale: Offset(2, 3));
      expect(apply(t, const Offset(1, 1)), const Offset(2, 3));
      expect(apply(t, const Offset(0, 0)), Offset.zero);
    });

    test('90° clockwise rotation maps right to down (y-down convention)', () {
      final t = const NodeTransform(rotation: math.pi / 2);
      // (1, 0) [right] -> (0, 1) [down]
      expect(apply(t, const Offset(1, 0)).dx, closeTo(0, 1e-12));
      expect(apply(t, const Offset(1, 0)).dy, closeTo(1, 1e-12));
      // (0, 1) [down] -> (-1, 0) [left]
      expect(apply(t, const Offset(0, 1)).dx, closeTo(-1, 1e-12));
      expect(apply(t, const Offset(0, 1)).dy, closeTo(0, 1e-12));
    });

    test('combined SRT: scale -> rotate -> translate', () {
      // scale (2,3), rotate 90°, translate (1,1):
      // (1,0) --scale--> (2,0) --rotate90--> (0,2) --translate--> (1,3)
      final t = const NodeTransform(
        translation: Offset(1, 1),
        scale: Offset(2, 3),
        rotation: math.pi / 2,
      );
      expect(apply(t, const Offset(1, 0)).dx, closeTo(1, 1e-12));
      expect(apply(t, const Offset(1, 0)).dy, closeTo(3, 1e-12));
    });
  });

  group('malformed input', () {
    test('toMatrix4 throws ArgumentError on NaN translation', () {
      const t = NodeTransform(translation: Offset(double.nan, 0));
      expect(() => t.toMatrix4(), throwsArgumentError);
    });

    test('toMatrix4 throws ArgumentError on NaN scale', () {
      const t = NodeTransform(scale: Offset(1, double.nan));
      expect(() => t.toMatrix4(), throwsArgumentError);
    });

    test('toMatrix4 throws ArgumentError on NaN rotation', () {
      const t = NodeTransform(rotation: double.nan);
      expect(() => t.toMatrix4(), throwsArgumentError);
    });
  });
}
