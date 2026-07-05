import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:vector_math/vector_math_64.dart' show Matrix4;

/// A 2D affine transform carried by every IR [Element] node, expressed in
/// **staff-space units**.
///
/// Unit & coordinate convention:
/// - All numbers are staff-space units (the SMUFL native unit). 1 staff space
///   is the unit; 4 staff spaces = 1 staff height = 1 em. The IR stores no
///   pixel values — conversion to pixels is a render-phase concern.
/// - `x` increases to the right, `y` increases **downward** (screen/canvas
///   convention).
/// - `rotation` is in radians, **clockwise positive** (consistent with y-down):
///   in the y-down coordinate system a positive angle rotates the x-axis
///   toward the y-axis (right → down).
///
/// A local point `p` is mapped into its parent's space in **SRT order** —
/// scale first, then rotate, then translate:
///
///     p' = translation + R(rotation) * (scale ⊙ p)
///
/// Concretely:
///
///     x' = (cos·sx)·x − (sin·sy)·y + translation.dx
///     y' = (sin·sx)·x + (cos·sy)·y + translation.dy
///
/// `toMatrix4()` encodes this as a 4×4 affine matrix (z = 0 plane); absolute
/// transforms are composed by the free functions in `layout/geometry.dart`,
/// and point/rect application reuses `MatrixUtils` from `package:flutter/painting.dart`.
class NodeTransform {
  /// Translation in staff-space units.
  final Offset translation;

  /// Per-axis scale (x, y). `(1, 1)` is unscaled.
  final Offset scale;

  /// Rotation in radians, clockwise positive.
  final double rotation;

  const NodeTransform({
    this.translation = Offset.zero,
    this.scale = const Offset(1, 1),
    this.rotation = 0,
  });

  const NodeTransform.identity()
      : translation = Offset.zero,
        scale = const Offset(1, 1),
        rotation = 0;

  /// `true` when this transform leaves every point unchanged.
  bool get isIdentity =>
      translation == Offset.zero && scale == const Offset(1, 1) && rotation == 0;

  /// Returns a copy with the given fields replaced.
  NodeTransform copyWith({Offset? translation, Offset? scale, double? rotation}) =>
      NodeTransform(
        translation: translation ?? this.translation,
        scale: scale ?? this.scale,
        rotation: rotation ?? this.rotation,
      );

  /// Encodes this transform as a 4×4 affine matrix in SRT order (scale →
  /// rotate → translate), in the column-major storage convention of `Matrix4`.
  ///
  /// The matrix acts on the z = 0 plane (the last row/column is the identity),
  /// so it is directly consumable by `MatrixUtils.transformPoint` /
  /// `MatrixUtils.transformRect`.
  ///
  /// Throws [ArgumentError] if any component is NaN — a malformed transform is
  /// a programmer error, not a recoverable condition.
  Matrix4 toMatrix4() {
    _checkFinite(translation, scale, rotation);

    final c = math.cos(rotation);
    final s = math.sin(rotation);
    final sx = scale.dx;
    final sy = scale.dy;

    // Column-major 4×4. Start from identity (z = 0 plane is already the
    // identity) and overwrite only the 2D-relevant entries:
    //   col0 = (cos·sx, sin·sx, 0, 0)
    //   col1 = (−sin·sy, cos·sy, 0, 0)
    //   col3 = (tx, ty, 0, 1)
    return Matrix4.identity()
      ..setEntry(0, 0, c * sx)
      ..setEntry(1, 0, s * sx)
      ..setEntry(0, 1, -s * sy)
      ..setEntry(1, 1, c * sy)
      ..setEntry(0, 3, translation.dx)
      ..setEntry(1, 3, translation.dy);
  }
}

void _checkFinite(Offset translation, Offset scale, double rotation) {
  if (translation.dx.isNaN ||
      translation.dy.isNaN ||
      scale.dx.isNaN ||
      scale.dy.isNaN ||
      rotation.isNaN) {
    throw ArgumentError(
      'NodeTransform contains NaN: '
      'translation=$translation, scale=$scale, rotation=$rotation.',
    );
  }
}
