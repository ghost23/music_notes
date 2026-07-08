# WP1-S5 — Cross-references & the unresolved state

## Goal

Let the IR represent an element whose geometry **cannot be computed yet**
because it depends on the final positions of other elements — a slur over
notes whose Y is not yet known, a beam across stems, a tie between noteheads.
The element exists in the tree early, holds **cross-references** to the
elements/anchors it depends on, and is **resolved** in a later layout pass.

More generally, **any** node can be in an *unresolved* state while its geometry
is still tentative — e.g. a beamed note's stem `LineElement` cannot be
finalised until the beam it joins is laid out. Deferral is not a property of a
fixed set of types; it is a state any element can carry.

This is the structural reason the rewrite exists (see `architecture.md`); WP1
provides only the *mechanism*, not the actual beam/slur math (that is WP6).

## Background

`architecture.md`: "You cannot draw the legato line before you know where its
underlying notes are placed. So you need to be able to create the legato line but
be able to alter it once you have all the other symbols placed."

The multi-pass driver (WP3) will run resolution passes; WP1 must give those
passes something well-defined to operate on.

## The tree vs. its cross-references

The IR is a tree of parent→child `elements`. A **cross-reference** is an edge
that *crosses* that tree — a handle from one node to another reached anywhere
in the hierarchy, not necessarily a child. A slur references noteheads that may
live in any column/measure; a beam references stems; a tie references two
noteheads; a dynamic references the staff it attaches to.

That a cross-reference's target is not yet placed — i.e. that the holder is
"deferred" — is a *consequence* of holding a cross-reference and of the tree
being built one node at a time, **not** the defining property of the type. The
type (`CrossReferenceElement`) is defined by the **capability to hold
cross-references**; the unresolved state (`Element.isResolved`) is a separate,
general mechanism that lives on `Element` and that *any* node can carry.

## Scope

**In:**
- An `isResolved` flag on `Element` (default `true`), so **any** node — a
  cross-reference element *or* a primitive leaf like a beamed note's stem — can
  be built unresolved and finalised by a later pass.
- A `CrossReference` value type that points at another node (by identity) and,
  optionally, a resolved local anchor offset on it (reusing S4), without copying
  that node's data.
- A `CrossReferenceElement` base — an element able to hold cross-references
  (the slur/tie/beam/dynamic/direction placeholders extend it). It is unresolved
  by default; deferral is a consequence, not the essence (see above).
- A clear, queryable way to find unresolved nodes in a tree (so WP3's pass
  driver can iterate them) — via a free traversal function.
- An **absolute-transform index** free function (a `Map<Element, Matrix4>`
  built by a single top-down walk) that a resolver consumes to read a
  cross-reference target's absolute position.
- **Inspectable-while-unresolved** model behaviour: reading an unresolved
  node's `elements` / `localBoundingBox` returns its *current* (tentative)
  values — a layout pass may legitimately inspect them for assessment. The
  model getters do **not** throw. Unresolved geometry is refused only at the
  **render boundary** (WP2): the renderer refuses to draw an unresolved node.

**Out:**
- The actual resolution logic for beams/slurs/ties/dynamics (WP6).
- The pass scheduler / convergence detection (WP3).
- The render-phase throws on unresolved nodes (WP2 — WP1 states the boundary,
  WP2 implements it).
- Persisting cross-references across re-layout / serialization.

## Design notes

- Prefer modeling resolution as a **free function**, keeping the unresolved
  node as pure data holding its cross-references. This matches the
  functional principle and keeps WP6 rules testable.
- Cross-references should be stable handles, not deep copies, so that when a
  target moves, the reference still points at the right node. The identity
  scheme is **Dart object identity** (no id field): stable across passes *iff*
  a pass mutates a node's `transform` in place rather than `copyWith`-replacing
  the whole node. `Element` is intentionally mutable (`transform`,
  `isResolved`) precisely so cross-references and the index keep pointing at
  the right node after it moves.
- Unresolved nodes are **inspectable**, not hidden: a layout rule or the
  pass driver may need to read an unresolved node's current `elements` or
  `localBoundingBox` for assessment, so the getters return tentative values
  rather than throwing. The hard refusal is at the render boundary (WP2).
- Keep the dependency direction explicit and acyclic where possible; document
  what happens if a cross-reference target is itself unresolved (its own
  *position* is still readable from the index; its *geometry* would require
  it resolved first).
- **How a cross-reference obtains a target's *absolute* geometry.** IR nodes
  carry no parent link (by design — see S1: absolute geometry is composed
  **top-down** by free functions that thread `parentAbsolute` down the walk,
  not by walking up). A cross-reference element therefore cannot start from a
  referenced notehead and accumulate its ancestor transforms. The resolver
  must instead consume an **absolute-transform/anchor index built by a single
  top-down pass** — e.g. a `Map<Element, Matrix4>` keyed by node identity —
  and read each target's absolute position from it. Do **not** re-search from
  the root per reference (O(n·m)), and do **not** add parent pointers to work
  around it (that turns the tree into a cyclic graph and breaks the pure-data
  / free-function principle). This index is the contract between WP3's pass
  driver and the resolvers.
- **Node identity must stay stable across passes.** Cross-references and the
  index above are keyed by node identity, so a layout pass must **mutate a
  node's `transform` in place** rather than `copyWith`-replacing the whole
  node — replacing a node silently breaks every cross-reference and index
  entry pointing at it. `Element` is intentionally mutable to allow this;
  keep it that way for nodes that can be reference targets.

## Acceptance criteria

- [x] The IR can hold a node in an explicit **unresolved** state carrying
      cross-references to other elements and (optionally) their named anchors
      (S4). Unresolved state is general: any `Element` can be `isResolved =
      false`, not just cross-reference elements (e.g. a beamed note's stem).
- [x] A free traversal function returns all unresolved nodes in a tree, in a
      deterministic order, for a pass driver to consume.
- [~] Geometry/render of an unresolved element is impossible by construction or
      **throws** a descriptive exception — it never silently yields empty/zero
      geometry. *(Revised — see Implementation. The model getters are
      **inspectable** while unresolved: they return tentative values so a layout
      pass may read them for assessment, so they do **not** throw. The hard
      refusal moves to the **render boundary** (WP2): the renderer refuses to
      draw an unresolved node, so unresolved geometry never reaches the canvas.
      WP1 states this boundary; WP2 implements the throw.)*
- [x] A documented identity/reference scheme explains how a cross-reference
      keeps pointing at the correct node after that node's transform changes.
- [x] Unit tests cover: building an unresolved element with cross-references;
      traversal finding it (and finding deferred non-cross-reference nodes like
      a stem); and the inspectable-while-unresolved path (no throw).
- [x] No beam/slur/tie math is implemented here (correctly deferred to WP6); the
      story delivers only the mechanism, demonstrated with a trivial fake
      resolver in tests.

## Implementation

S5 ships only the *mechanism*, as scope requires. The design generalised during
implementation: an earlier draft restricted the unresolved state to a fixed set
of "deferred" element types, but a beamed note's stem — a primitive `LineElement`
whose length cannot be finalised until the beam is laid out — is just as
"deferred" as a slur, so the deferral flag was lifted to `Element` and the
type's defining property became "holds cross-references" (deferral being a
consequence). Three pieces, in the same layer split the rest of the IR already
follows (model types in `graphics_model/`, free tree-walk functions in
`layout/`):

### What lives where

- **`CrossReference`** (`lib/graphics/graphics_model/semantic/context_dependent.dart`)
  — the data handle: a target `Element` held by **Dart object identity**, plus
  an optional resolved local anchor `Offset?` (reusing S4's eager local
  resolution). Pure data — no behaviour, no copy of the target. Contrast: an
  element's `elements` are **tree** edges (parent→child); a `CrossReference` is
  a **cross-tree** edge (one node → another, anywhere in the hierarchy).
- **`CrossReferenceElement`** (same file) — the abstract base the five
  context-dependent placeholders (`BeamElement`, `TieElement`, `SlurElement`,
  `DynamicElement`, `DirectionElement`) extend instead of bare `GroupElement`.
  It carries `crossReferences`. It is **unresolved by default** (`isResolved =
  false` in its constructor); a builder that can resolve eagerly flips it back
  to `true`. Resolution is a free function, not a method: a resolver mutates
  the node in place (populates `elements`, flips `isResolved`) — WP6 owns the
  math. WP6 will add whatever per-type payload its resolvers need (a slur's
  side, a beam's slope hint, …); S5 deliberately does not speculate a slot for
  it.
- **`Element.isResolved`** (`canvas_primitives.dart`) — the unresolved-state
  flag, general to every node. Defaults to `true` (most nodes are resolved at
  build); set to `false` for any node a builder leaves tentative (a
  cross-reference element, or a beamed note's stem `LineElement`, or a whole
  `PitchedNoteElement` whose stem role is not yet finalised). Purely
  informational to the model — see "Inspectable while unresolved" below.
- **`layout/cross_references.dart`** — the free functions the WP3 pass driver
  and WP6 resolvers consume:
  - `unresolvedElements(root)` — deterministic pre-order traversal yielding
    every node with `isResolved == false` (cross-reference elements *and*
    deferred primitives/composites), recursing through `elements` uniformly;
  - `absoluteTransformIndex(root)` — the `Map<Element, Matrix4>` built by a
    single top-down walk (reusing S1's `absoluteTransform`), keyed by node
    identity, indexing every node regardless of resolved state. This is the
    WP3↔resolver contract: pass-local derived data, rebuilt fresh after any
    mutating pass, never stored on nodes;
  - `crossReferenceAbsoluteOffset(crossReference, index)` — the pure
    composition step a resolver performs per cross-reference (target absolute
    transform ∘ local anchor); throws on a dangling (out-of-subtree) target.

### Identity scheme (documented on `CrossReference`)

Cross-references and the index key off **Dart object identity** — no id field.
This is stable across passes **iff a pass mutates a node's `transform` in
place** rather than `copyWith`-replacing the node: `Element.transform` is a
settable field precisely so cross-references keep pointing at the right node
after it moves (replacing a node silently breaks every cross-reference/index
entry keyed on it). Tests pin this: mutate a target's transform in place,
rebuild the index, and the cross-reference's resolved absolute position tracks
the new transform while `identical(crossReference.target, node)` stays true.

### Inspectable while unresolved (the revised criterion)

An earlier draft made `elements`/`localBoundingBox` **throw** on an unresolved
node. On review that was too aggressive: a layout rule or the pass driver may
legitimately need to read an unresolved node's *current* (tentative) geometry
for assessment, and a primitive leaf a builder left tentative (a stem) has
nothing "unresolvable" about its box — it is just not final. So the model
getters are **inspectable**: they return tentative values (an empty list / a
zero box for a freshly built cross-reference element; a real tentative box for
a deferred stem), never throwing. The hard refusal — "unresolved geometry must
never reach the canvas" — moves to the **render boundary** (WP2): the renderer
checks `isResolved` and refuses to draw an unresolved node. WP1 states this
boundary; WP2 implements the throw. Criterion 3 is marked `[~]` to record this
revision, exactly as S4's absent-anchor throw moved to the consumer.

### Evolving the S3 placeholders

The five context-dependent types keep their names and taxonomy mapping (S3
promised this); they change `extends GroupElement` → `extends
CrossReferenceElement` (which is itself a `GroupElement`, so existing
`isA<GroupElement>()` assertions still hold). They are unresolved by default;
the S3 taxonomy test's placeholder assertion (`elements, isEmpty`) was updated
to assert the cross-reference contract instead.

### Scope guard-rails

No beam/slur/tie/dynamic math is implemented — WP6 owns the actual
resolution logic and will add any per-type payload it needs (S5 deliberately
speculates none). The tests use a trivial `fakeResolveTwoPointCurve` resolver
that draws a straight line between two cross-references' absolute positions,
purely to prove the mechanism gives a resolver something well-defined to
operate on.
Whether a beamed stem is actually built deferred vs. built with a tentative
length that a beam pass later mutates is a WP5/WP6 policy choice — both are
representable under the generalised `isResolved` model, and WP1 deliberately
does not decide. The real curve/segment/wedge geometry is WP6.

### Tests

[`test/graphics/layout/cross_references_test.dart`](../../test/graphics/layout/cross_references_test.dart)
covers: `isResolved` on `Element` (default true; cross-reference elements
unresolved by default; a `LineElement` stem flaggable unresolved); a
cross-reference element holding cross-references by identity; the
**inspectable-while-unresolved** path (`elements`/`localBoundingBox`/
`absoluteBoundingBox` returning tentative values without throwing — including a
deferred stem leaf and a deferred `PitchedNoteElement`); `unresolvedElements`
returning deterministic pre-order (and finding a deferred stem inside a note,
and a deferred composite); `absoluteTransformIndex` recording every node by
identity, indexing tentative children of a deferred composite, and reflecting
in-place transform mutations after a rebuild; `crossReferenceAbsoluteOffset`
composing the anchor (and the no-anchor origin case, and the dangling-target
throw); the identity scheme surviving a target transform mutation; and the fake
resolver resolving a slur and a tie end-to-end, plus a deferred stem finalised
in place (geometry populated, `isResolved` flipped, traversal no longer finds
it). The S3 taxonomy test (`semantic_taxonomy_test.dart`) was updated to assert
the cross-reference / inspectable contract.

### Renames

During implementation `DeferredElement` → `CrossReferenceElement` and
`Reference` → `CrossReference` (the handle), sharpening the contrast with
`elements`: `elements` form the tree; `crossReferences` cross it. The free
functions moved from `layout/deferred.dart` to `layout/cross_references.dart`,
and `referenceAbsoluteOffset` → `crossReferenceAbsoluteOffset`.
