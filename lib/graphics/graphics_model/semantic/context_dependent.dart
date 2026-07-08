import 'dart:ui' show Offset;

import '../canvas_primitives.dart' show Element, GroupElement;

/// A handle from a [CrossReferenceElement] to a target node **elsewhere in the
/// tree**, held by identity (WP1-S5).
///
/// The IR has two kinds of edges:
/// - **tree edges** — an element's `elements`: its parent-child composition,
///   forming the scene-graph tree;
/// - **cross-references** — a [CrossReference]: a handle from one node to
///   *another* node reached **across** the tree, regardless of where each sits
///   in the hierarchy. A slur references noteheads that may live in any
///   column/measure; a beam references stems; a tie references two noteheads;
///   a dynamic references the staff it attaches to.
///
/// A [CrossReference] is pure data — no behaviour, no copy of the target. It
/// carries the target [Element] itself plus, optionally, a resolved **local
/// anchor offset** on it (S4). That a cross-reference's target is not yet
/// placed — i.e. that the holder is "deferred" — is a *consequence* of holding
/// a cross-reference and of the tree being built one node at a time, not the
/// defining property of the type; see [CrossReferenceElement].
///
/// ## Identity scheme (load-bearing)
///
/// A cross-reference points at its target by **Dart object identity** —
/// [target] is the [Element] instance itself. This is stable across layout
/// passes **as long as a pass mutates a node's `transform` in place** rather
/// than `copyWith`-replacing the whole node: the IR `Element` is intentionally
/// mutable (its `transform` and [Element.isResolved] are settable fields)
/// precisely so cross-references — and the absolute-transform index a resolver
/// consumes — keep pointing at the right node after it moves. Replacing a node
/// object silently breaks every cross-reference and index entry keyed on it;
/// do not do that for nodes that can be reference targets.
///
/// No separate id field is used: object identity is simpler, cannot drift out
/// of sync with the node, and needs no registration.
///
/// ## Anchor resolution (reuses S4)
///
/// Per the S4 design, a glyph's anchor offset is a **static per-glyph fact**
/// resolved eagerly at build time by direct field access on the `GlyphAnchor`
/// record (taking the `glyphAnchors` table as a parameter). A [CrossReference]
/// therefore carries the already-resolved local [Offset] in [localAnchor],
/// not an anchor name + table: the local offset is known the moment the tree is
/// built; only the target's *absolute* position is deferred. A resolver pairs
/// [localAnchor] with the target's absolute transform (read from the
/// absolute-transform index in `layout/cross_references.dart`) to get an
/// absolute attachment point. [localAnchor] is `null` when the reference
/// targets the node's own position rather than a named anchor on it (e.g. a
/// dynamic referencing a staff's origin) — the resolver then uses [Offset.zero]
/// against the target's absolute transform.
class CrossReference {
  const CrossReference(this.target, {this.localAnchor});

  /// The target element this cross-reference points at, by identity.
  final Element target;

  /// A resolved local anchor offset on [target] (in target-local staff-space
  /// units), or `null` to use the target's own origin. Resolved eagerly at
  /// build time per S4; only the absolute composition is deferred.
  final Offset? localAnchor;
}

/// An element that holds **cross-references** — handles to other nodes
/// elsewhere in the tree, regardless of hierarchy — so its geometry can be
/// computed from nodes it does not contain as children (WP1-S5).
///
/// The scene graph is a tree of parent→child `elements`. A [CrossReferenceElement]
/// additionally holds [crossReferences]: edges that **cross** that tree,
/// pointing at nodes anywhere in the hierarchy. This is what a slur/tie/beam/
/// dynamic/direction needs — its geometry depends on nodes (noteheads, stems,
/// a staff) that are not its children.
///
/// ## Deferral is a consequence, not the essence
///
/// Because the tree is built one node at a time, a cross-reference element is
/// typically created *before* its targets are placed, so it starts
/// **unresolved** ([Element.isResolved] = `false`) and is resolved in a later
/// pass. But deferral is **not** what makes this type — any element can be
/// deferred (the [Element.isResolved] flag lives on `Element` itself, so a
/// beamed note's stem `LineElement` can be `isResolved = false` until the beam
/// is laid out, without being a [CrossReferenceElement]). This type's defining
/// property is simply the **capability to hold cross-references**.
///
/// ## Resolution is a free function, not a method
///
/// Per the functional principle, resolution is modelled as a **free function**
/// (WP6 owns the actual math; S5 ships only the mechanism). A resolver reads
/// each cross-reference's target absolute transform from the
/// **absolute-transform index** (`layout/cross_references.dart::absoluteTransformIndex`
/// — a `Map<Element, Matrix4>` built by a single top-down walk), composes it
/// with the cross-reference's [localAnchor] (via
/// `crossReferenceAbsoluteOffset`), computes the element's primitives, then
/// **mutates this node in place**: populates [elements] with the computed
/// leaves and flips [Element.isResolved] to `true`. Mutating in place (rather
/// than replacing the node) preserves object identity, which is what
/// [CrossReference]s and the index key on.
///
/// ## Inspectable while unresolved
///
/// Reading [elements] or `localBoundingBox` while unresolved returns the node's
/// *current* (tentative) values — typically an empty child list / a zero box
/// for a freshly built cross-reference element — so a layout pass may inspect
/// it for assessment. The getters do **not** throw; unresolved geometry is
/// refused only at the **render boundary** (WP2). See [Element.isResolved].
///
/// ## Dependency direction
///
/// Keep the cross-reference graph acyclic where possible: a cross-reference
/// element references *placed* elements (typically primitive leaves like
/// noteheads / stems), not other cross-reference elements. The
/// absolute-transform index holds every node's transform regardless of resolved
/// state, so a cross-reference to a deferred target can still read its absolute
/// *position* — but reading that target's *geometry* would require it resolved
/// first. Ordering passes so dependencies resolve before their dependents is
/// WP3's responsibility.
abstract class CrossReferenceElement extends GroupElement {
  CrossReferenceElement(super.transform, [super.elements]) {
    // A freshly built cross-reference element is unresolved: its targets are
    // typically not placed yet. (A builder that can resolve eagerly simply
    // flips this back to `true` after computing the geometry.)
    isResolved = false;
  }

  /// The cross-references this element depends on — handles to target nodes
  /// elsewhere in the tree, each with an optional resolved local anchor (S4).
  /// Populated at build time; consumed by a later resolution pass.
  List<CrossReference> crossReferences = const [];
}

/// A **beam** joining the stems of consecutive notes.
///
/// **Source:** `Beam` entries on `PitchNote.beams`.
/// **Composes:** one or more `RectElement`/`LineElement` leaves — the beam
/// segments — once the stem-tip positions are known. A beam is
/// context-dependent (its geometry depends on the stems it joins): its
/// segment count and geometry are produced by the WP6 beam rule, holding its
/// stems as [CrossReferenceElement.crossReferences]. It therefore stays an
/// open collection (a [CrossReferenceElement] subclass) rather than a fixed
/// composite.
class BeamElement extends CrossReferenceElement {
  BeamElement(super.transform, [super.elements]);
}

/// A **tie** joining two noteheads of the same pitch.
///
/// **Source:** `Tied` notation.
/// **Composes:** (eventually) a `PathElement`/`LineElement` curve leaf, once
/// the start and end notehead positions are known.
/// **Cross-references:** the noteheads it ties (held as
/// [CrossReferenceElement.crossReferences]); **resolution math:** WP6.
class TieElement extends CrossReferenceElement {
  TieElement(super.transform, [super.elements]);
}

/// A **slur** (legato) over a span of notes.
///
/// **Source:** `Slur` notation.
/// **Composes:** (eventually) a `PathElement` curve leaf, once the spanned
/// notehead positions are known.
/// **Cross-references:** the noteheads it spans (held as
/// [CrossReferenceElement.crossReferences]); **resolution math:** WP6.
class SlurElement extends CrossReferenceElement {
  SlurElement(super.transform, [super.elements]);
}

/// A **dynamic** marking (p, f, mp, …).
///
/// **Source:** `Dynamics` notation.
/// **Composes:** one [Element] leaf per dynamic glyph
/// (`Glyph.dynamicPiano` / `dynamicForte` / …), placed relative to the staff
/// once the surrounding context is known.
/// **Cross-references:** the staff/notes it attaches to (held as
/// [CrossReferenceElement.crossReferences]); **resolution math:** WP6.
class DynamicElement extends CrossReferenceElement {
  DynamicElement(super.transform, [super.elements]);
}

/// A **direction** — a wedge (hairpin), printed words, or an octave shift.
///
/// **Source:** `Direction` carrying one of `Wedge` / `Words` / `OctaveShift`.
/// **Composes:** (eventually) `LineElement`/`RectElement` leaves for a wedge,
/// [Element] leaves for words/octave-shift glyphs — once the endpoints'
/// positions are known.
/// **Cross-references:** the notes/staff the direction spans (held as
/// [CrossReferenceElement.crossReferences]); **resolution math:** WP6.
class DirectionElement extends CrossReferenceElement {
  DirectionElement(super.transform, [super.elements]);
}
