import 'dart:ui' show Offset;

import 'package:flutter/painting.dart' show MatrixUtils;
import 'package:vector_math/vector_math_64.dart' show Matrix4;

import '../graphics_model/canvas_primitives.dart' show Element;
import '../graphics_model/semantic/context_dependent.dart' show CrossReference;
import 'geometry.dart' show absoluteTransform;

/// Free functions for the cross-reference / resolution mechanism (WP1-S5).
///
/// The IR is a tree of parent→child `elements`. A [CrossReference] (see
/// `semantic/context_dependent.dart`) is an edge that **crosses** that tree:
/// a handle from one node to another reached anywhere in the hierarchy. These
/// functions give the WP3 pass driver and the WP6 resolvers something
/// well-defined to operate on:
/// - [unresolvedElements] finds every node still in an unresolved state, in
///   deterministic pre-order, for a pass driver to iterate;
/// - [absoluteTransformIndex] builds the `Map<Element, Matrix4>` a resolver
///   consumes to read each cross-reference target's absolute position (built by
///   a single top-down walk — never by walking up; the IR has no parent links
///   by design);
/// - [crossReferenceAbsoluteOffset] is the pure composition step a resolver
///   performs per cross-reference.
///
/// The actual resolution *math* (beam/slur/tie/dynamic geometry) is WP6; this
/// library ships only the mechanism. See `docs/wp1/S5-deferred-references.md`.
///
/// All coordinates are staff-space units.

/// All unresolved nodes in [root]'s subtree, in deterministic pre-order
/// depth-first order.
///
/// A pass driver iterates this to find what still needs resolving. It yields
/// every node whose [Element.isResolved] is `false` — a cross-reference
/// element (slur/tie/beam/…) **or** any other node a builder left tentative
/// (e.g. a beamed note's stem `LineElement` until the beam is laid out) —
/// recursing through `elements` uniformly, since the getters are inspectable
/// while unresolved (they return tentative values, never throw).
Iterable<Element> unresolvedElements(Element root) sync* {
  if (!root.isResolved) yield root;
  for (final child in root.elements) {
    yield* unresolvedElements(child);
  }
}

/// The absolute transform of every node in [root]'s subtree, keyed by **node
/// identity** — the index a cross-reference's resolver consumes (WP1-S5
/// contract; WP3 owns *when* it is rebuilt).
///
/// Built by a single top-down walk that threads each parent's absolute
/// transform down (reusing S1's [absoluteTransform]), never by walking up or
/// storing absolute values on nodes. A resolver reads a cross-reference
/// target's absolute position as `index[target]` and composes it with the
/// cross-reference's local anchor offset via [crossReferenceAbsoluteOffset].
///
/// Every node is indexed regardless of its resolved state — a target's own
/// *position* is a pure function of transforms and is available even while the
/// target's *geometry* is still tentative (a beam referencing a not-yet-
/// finalised stem still reads the stem's absolute transform). The walk recurses
/// through `elements` uniformly; an unresolved cross-reference element with an
/// empty child list simply contributes itself and nothing below it.
///
/// This is pass-local derived data, not IR state: it is a pure function of the
/// current transforms and is rebuilt fresh after any mutating pass. Storing
/// absolute values on nodes (or parent pointers) is deliberately avoided — it
/// would demand careful invalidation and turn the tree into a cyclic graph.
Map<Element, Matrix4> absoluteTransformIndex(Element root) {
  final index = <Element, Matrix4>{};
  void walk(Element node, Matrix4? parentAbsolute) {
    final absolute = absoluteTransform(node, parentAbsolute: parentAbsolute);
    index[node] = absolute;
    for (final child in node.elements) {
      walk(child, absolute);
    }
  }

  walk(root, null);
  return index;
}

/// The absolute staff-space position a [crossReference] points at, given the
/// [index] of absolute transforms.
///
/// This is the composition step a resolver (WP6) performs for each
/// cross-reference: it takes the target's absolute transform from [index] and
/// applies the cross-reference's local anchor offset (or [Offset.zero] when it
/// targets the node's own origin). It is pure transform composition (reusing
/// `MatrixUtils.transformPoint`), not resolution math — what the resolver
/// *does* with this point (build a slur curve, a beam segment, …) is WP6.
///
/// Throws [StateError] if [crossReference]'s target is not in [index] (e.g. the
/// cross-reference points outside the indexed subtree): a dangling
/// cross-reference is a programmer error, not a recoverable condition — per
/// the exceptions-over-null principle.
Offset crossReferenceAbsoluteOffset(
  CrossReference crossReference,
  Map<Element, Matrix4> index,
) {
  final targetAbsolute = index[crossReference.target];
  if (targetAbsolute == null) {
    throw StateError(
      'CrossReference target ${crossReference.target.runtimeType} is not in '
      'the absolute-transform index; the cross-reference points outside the '
      'indexed subtree.',
    );
  }
  return MatrixUtils.transformPoint(
    targetAbsolute,
    crossReference.localAnchor ?? Offset.zero,
  );
}
