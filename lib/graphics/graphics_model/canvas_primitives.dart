import 'dart:ui' show Offset, Path, Rect;

import 'package:flutter/painting.dart' show MatrixUtils;

import 'transform.dart' show NodeTransform;
import 'styling.dart' show Styling;
import '../generated/glyph_bboxes.dart';
import '../generated/glyph_definitions.dart';
import '/graphics/generated/glyph_anchors.dart';

/// Base class for the layout/render intermediate representation (WP1).
///
/// All numbers are **staff-space units**: 1 staff space is the SMUFL unit;
/// 4 staff spaces = 1 staff height = 1 em. The IR stores no pixel values —
/// conversion to pixels is a render-phase concern (see [Styling] for the
/// scale-free presentational styling an element carries).
///
/// Each node carries a [transform] relative to its parent (translation, scale,
/// rotation in staff-space units). See [NodeTransform] for the convention (axis
/// directions, rotation sign, SRT order). Absolute/composed geometry is
/// computed by the free functions in `layout/geometry.dart`, not by this
/// class.
sealed class Element {
  Element(this.transform, {this.styling = Styling.inherit});

  /// Transform of this node relative to its parent, in staff-space units.
  NodeTransform transform;

  /// Scale-free presentational styling (stroke/fill color, staff-space
  /// stroke thickness). No `Paint`/`TextStyle` and no pixel values; the
  /// renderer builds concrete paint objects from this plus the render scaling
  /// measure. The layout phase is the sole source of styling — the renderer
  /// has no defaults and throws on a missing required property. Defaults to
  /// [Styling.inherit] ("unresolved; layout must resolve").
  Styling styling;

  /// Local bounding box, derived purely from this node's own fields.
  ///
  /// A node with [elements] folds their local boxes through their child
  /// transforms. Anything needing ancestor transforms is a free function.
  Rect get localBoundingBox;

  /// The node's child elements in draw order — the single traversal contract
  /// the generic tree-walk (bbox folding, rendering, the WP3 transform index)
  /// depends on.
  ///
  /// - **Leaves** ([PathElement], [LineElement], [RectElement],
  ///   [GlyphElement]) return `const []`.
  /// - A [GroupElement] is an **open collection**: its elements are a plain,
  ///   mutable list whose length is data-driven.
  /// - A [CompositeElement] is a **fixed set of named roles**: it *derives*
  ///   this list (read-only) from its typed role fields, so the roles stay
  ///   named and the arity is codified, while the walk still sees a plain
  ///   ordered list.
  List<Element> get elements;

  /// Adapter shim for legacy render code; delegates to [localBoundingBox].
  /// To be removed in WP2.
  Rect get boundingBox => localBoundingBox;

  /// Adapter shim for legacy render/layout code; backed by [transform].
  /// To be removed in WP2.
  Offset get pointOfOrigin => transform.translation;
  set pointOfOrigin(Offset value) =>
      transform = transform.copyWith(translation: value);
}

/// The local bounding box of a node that composes children: each child's local
/// box folded through its child transform. Shared by the two composing shapes
/// ([GroupElement] and [CompositeElement]).
Rect _foldChildBoxes(List<Element> children) =>
    children.fold(Rect.zero, (acc, child) {
      final childBox = MatrixUtils.transformRect(
          child.transform.toMatrix4(), child.localBoundingBox);
      return acc == Rect.zero ? childBox : acc.expandToInclude(childBox);
    });

/// An **open collection** node: its [elements] are a plain, mutable list whose
/// length is data-driven (parts of a system, columns of a measure, accidentals
/// of a key signature, the style leaves of a barline). Use this when a *list*
/// is genuinely the right model — i.e. there are no distinct named roles to
/// lose. For a node with a fixed set of named parts, use [CompositeElement]
/// instead so the roles stay named and the arity is codified.
class GroupElement extends Element {
  GroupElement(super.transform, [this.elements = const []]);

  /// The open, mutable child list. Satisfies [Element.elements].
  @override
  List<Element> elements;

  @override
  Rect get localBoundingBox => _foldChildBoxes(elements);
}

/// A **composite** semantic node: a *fixed set of named roles* rather than an
/// open child list. Subclasses expose their parts as typed, named fields
/// (`beats`/`beatType`, `notehead`/`stem`/…) and implement [elements] from
/// them in draw order.
///
/// Unlike [GroupElement], the child set is **closed**: [elements] is a
/// read-only view derived from the named roles, with no mutable list to append
/// anonymous children to — so the roles cannot be lost and an invalid arity (a
/// time signature with one or five numerals) cannot be constructed. It extends
/// [Element] directly (not [GroupElement]): the traversal contract it needs is
/// just [Element.elements], which it implements from its roles.
///
/// A role may be any [Element] — typically a primitive leaf (a stem is a
/// [LineElement], a flag a [GlyphElement]); dedicated semantic sub-types are
/// introduced later only if a rule needs one.
abstract class CompositeElement extends Element {
  CompositeElement(super.transform);

  @override
  Rect get localBoundingBox => _foldChildBoxes(elements);
}

class PathElement extends Element {
  PathElement(super.transform, this.path, {super.styling});

  Path path;

  @override
  List<Element> get elements => const [];

  @override
  Rect get localBoundingBox => path.getBounds();
}

class LineElement extends Element {
  LineElement(
    super.transform,
    this.startPoint,
    this.endPoint, {
    super.styling,
  });

  Offset startPoint;
  Offset endPoint;

  @override
  List<Element> get elements => const [];

  @override
  Rect get localBoundingBox => Rect.fromPoints(startPoint, endPoint);
}

class RectElement extends Element {
  RectElement(super.transform, this.rect, {super.styling});

  Rect rect;

  @override
  List<Element> get elements => const [];

  @override
  Rect get localBoundingBox => rect;
}

class GlyphElement extends Element {
  GlyphElement(super.transform, this.glyph, {super.styling});

  /// The SMUFL glyph this node renders. Its size derives from staff-space +
  /// the render scaling measure, computed at render time; no pixel font size
  /// is stored here. Font family is also supplied at render time.
  Glyph glyph;

  GlyphAnchor get anchor => glyphAnchors[glyph] ?? const GlyphAnchor();

  @override
  List<Element> get elements => const [];

  @override
  Rect get localBoundingBox {
    final bbox = glyphBBoxes[glyph];
    if (bbox == null) {
      throw StateError('No bounding box registered for glyph $glyph.');
    }
    return Rect.fromPoints(bbox.northEast, bbox.southWest);
  }
}
