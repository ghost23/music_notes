import 'package:flutter/painting.dart' show MatrixUtils, Rect;
import 'package:vector_math/vector_math_64.dart' show Matrix4;
import '../graphics_model/canvas_primitives.dart' show Element;
import '../graphics_model/transform.dart' show NodeTransform;

/// Free geometry functions for the IR (WP1-S1).
///
/// Local geometry (a node's own extent) lives as a getter on [Element]
/// (`localBoundingBox`). **Absolute** geometry — anything that composes
/// ancestor transforms — lives here as free functions, so it can be unit-tested
/// with hand-built trees and has no hidden global state.
///
/// All coordinates are staff-space units (see `NodeTransform`). Point/rect
/// application reuses `MatrixUtils` from `package:flutter/painting.dart`.

/// The absolute transform of [node], i.e. its own [NodeTransform] composed
/// onto the absolute transform of its parent ([parentAbsolute]).
///
/// Pass [parentAbsolute] top-down while walking the tree; when omitted, [node]
/// is treated as a root and its own transform is returned. Composition is
/// `parentAbsolute · nodeTransform` (parent applied last), matching SRT per
/// node.
Matrix4 absoluteTransform(Element node, {Matrix4? parentAbsolute}) {
  final local = node.transform.toMatrix4();
  if (parentAbsolute == null) {
    return local;
  }
  // `multiplied` returns a fresh matrix = parentAbsolute · local, leaving
  // [parentAbsolute] unmutated so callers can reuse it across siblings.
  return parentAbsolute.multiplied(local);
}

/// The absolute (transform-composed) bounding box of [node]'s subtree.
///
/// For a **leaf** (empty [Element.elements]), this is the node's local box
/// transformed into absolute space. For a node **with children** (a
/// `GroupElement` or a `CompositeElement`), the children's absolute boxes are
/// folded. This keys off [Element.elements] alone, so it treats open
/// collections and fixed composites uniformly. When [parentAbsolute] is
/// omitted, [node] is treated as a root.
Rect absoluteBoundingBox(Element node, {Matrix4? parentAbsolute}) {
  final absolute = absoluteTransform(node, parentAbsolute: parentAbsolute);

  final children = node.elements;
  if (children.isEmpty) {
    return MatrixUtils.transformRect(absolute, node.localBoundingBox);
  }

  return children.fold(Rect.zero, (acc, child) {
    final childBox = absoluteBoundingBox(child, parentAbsolute: absolute);
    return acc == Rect.zero ? childBox : acc.expandToInclude(childBox);
  });
}
