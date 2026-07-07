# WP1-S4 — Named, transform-aware anchors

## Goal

Let elements expose **named anchor points** (in staff-space, transform-aware) so
other elements can attach to them — e.g. a stem attaches to a notehead's
`stemUpSE` anchor; a beam attaches to stem tips; a slur attaches to notehead
edges. Surface the SMUFL glyph anchors through the IR via free functions.

## Background

The generated `glyph_anchors.dart` already provides per-glyph anchor points
(stem up/down attachment, cut-outs, numeral origin, etc.). Today `GlyphElement`
exposes a single `anchor` getter that reads the global map inside the class —
which mixes data lookup into the model and ignores the node's transform.

Anchors are the mechanism by which context-dependent symbols (S5, WP6) find
their attachment geometry, so they must be resolvable in **absolute staff-space
coordinates** after transforms are composed.

## Scope

**In:**
- A way to ask, by name, for an element's anchor point:
  - for glyphs, names derive from the SMUFL anchor set (e.g. `stemUpSE`);
  - a **local**-space anchor lookup, and a free function that returns the anchor
    in **absolute** space (composing ancestor transforms from S1).
- The **local** anchor lookup may be a method on the glyph node, but it must
  take the glyph metadata as a **parameter** rather than reading the generated
  global map inside the class (testability principle). The **absolute** lookup
  is a free function (it needs ancestor context).
- Defined behaviour when an anchor is absent: **throw** (per exceptions-over-null
  principle) with a clear message naming the glyph and anchor.

**Out:**
- Defining custom anchors on composite/semantic nodes beyond what the first
  milestone needs (can be added when a rule requires it).
- Using anchors to actually place beams/slurs (that is S5 plumbing + WP6 rules).

## Design notes

- Whether the local lookup is a thin free function or a method, it must accept
  the anchor metadata as a parameter so tests can pass a fake record; the model
  node should not read the generated global map inside its own logic.
- Absolute anchor = compose(node absolute transform from S1, local anchor
  offset). Reuse S1's transform-composition function — do not duplicate it.
- Anchor names: reuse SMUFL anchor field names rather than inventing a parallel
  vocabulary.

## Acceptance criteria

- [x] A glyph element's named anchor can be obtained in **local** staff-space
      coordinates, given the element and glyph metadata. *(Realised as direct
      field access on the `GlyphAnchor` record, taking the `glyphAnchors` table
      as a parameter — see Implementation. No separate reader type is needed.)*
- [x] A free function returns the same anchor in **absolute** staff-space
      coordinates, correctly composing nested translation/scale/rotation (S1).
      *(Realised as `absoluteAnchorOffset(element, localOffset, {parentAbsolute})`,
      which composes S1's `absoluteTransform` with the resolved local offset.)*
- [~] Requesting a non-existent anchor **throws** a descriptive exception (no
      silent null). *(Revised — see Implementation.)*
- [x] Glyph metadata is supplied as a parameter to the anchor lookup, so tests
      run with hand-built fixtures and no global state.
- [x] Unit tests cover: a known SMUFL anchor in local space; the same under a
      translated+scaled parent; and the missing-anchor case.
- [x] The model node no longer reads the generated anchor map *inside* its own
      logic; the metadata is passed in (the current parameter-free `anchor`
      getter is replaced accordingly).

## Implementation

S4's anchor contribution is deliberately small. An anchor's **local** offset
is a static per-glyph fact — known the moment the tree is built and unchanged
across layout passes — so a builder resolves it eagerly by **direct field
access** on the `GlyphAnchor` record (the `glyphAnchors` table passed as a
parameter). There is no separate named-vocabulary type (`AnchorName`) and no
dispatch switch: the only place an anchor name lives is the `GlyphAnchor` field
declaration, which is irreducible (the generated `glyphAnchors` map constructs
its 642 entries via those named fields, and the generated files are out of
scope). The one free function S4 adds, `absoluteAnchorOffset`, is a thin
transform-composition util.

This shape emerged from a design pass that rejected a heavier first cut. The
original implementation introduced an `AnchorName` closed vocabulary plus a
`glyphAnchorOffset` local reader and an `absoluteAnchorOffset` that took an
`AnchorName` + table. On review that was over-built: the local reader added
nothing over direct field access (it threw on absence, but a builder that
needs an anchor can fail fast on `null` itself), and an `AnchorName` stored on
a deferred node was just a verbose way to carry a value that could be a plain
`Offset` resolved at build time. Both were removed. What remains is the part
that genuinely serves the contract.

### What lives where

- **`GlyphAnchor`** (`lib/graphics/glyph_anchor.dart`) — the hand-written data
  class with **nullable** `Offset?` fields (see "Presence is real" below) and a
  null-aware `translate`. Hand-written, not generated (see
  [`docs/code-principle.md`](../code-principle.md)).
- **`absoluteAnchorOffset(GlyphElement, Offset localOffset, {parentAbsolute})`**
  (`lib/graphics/layout/glyph_metadata.dart`) — the transform-composition util:
  `MatrixUtils.transformPoint(absoluteTransform(element, parentAbsolute: parentAbsolute), localOffset)`.
  It reuses S1's `absoluteTransform` (no recomputation, no re-walk from the
  root). It takes an already-resolved local `Offset`, not an anchor name +
  table, because the local offset is resolved once at build time and a
  deferred element (S5) carries the `Offset`; the absolute-transform index the
  resolver pairs it with is a WP3 concern.

### Presence is real (the load-bearing change)

A glyph defines only the anchors SMUFL lists for it. To make absence
*expressible* — `Offset.zero` is a legitimate anchor position for some glyphs
(e.g. some noteheads' `stemDownNW`), so zero cannot serve as a sentinel for
absence — the `GlyphAnchor` data class carries **nullable** `Offset?` fields
(`null` = not defined). The generated map entries already set only the
anchors a glyph has, so this required changing the **class definition** only;
no map entry changed. `GlyphAnchor.translate` is null-aware (present anchors
shift, absent ones stay `null`).

The `GlyphAnchor` class is **hand-written** and lives at
[`lib/graphics/glyph_anchor.dart`](../../lib/graphics/glyph_anchor.dart) — it
is **not** in `generated/`, because it carries hand-written logic that a
regeneration would otherwise discard (see
[`docs/code-principle.md`](../code-principle.md)). The generated
`glyph_anchors.dart` holds **only** the per-glyph `glyphAnchors` data map and
`import`s the class. The generator (`convertJsonToDart.mjs`) was updated to
match — its anchors template emits the import + the data map only (no class)
— and its stale `lib/notes/` output paths were corrected to
`lib/graphics/generated/`. The generator was **not** run (the SMUFL JSON has
drifted from the committed generated files; regenerating would touch every
file with unrelated diffs); the committed files remain the source of truth.

### Revised: absent-anchor behaviour (the `[~]` criterion)

The original S4 scope called for a reader that **throws** on a non-existent
anchor. The simplified design drops the reader: a non-existent anchor is
exposed as `null` via direct field access, and the **fail-fast responsibility
moves to the consumer** — the WP5 builder that requires `stemUpSE` for a
notehead asserts/throws when it is `null`. This is consistent with the
architecture: "I need this anchor" is builder knowledge, and that is where the
descriptive failure belongs. Presence is still real and distinguishable
(`null` ≠ `Offset.zero`); the throw is just no longer an S4 reader's job. The
criterion is marked `[~]` rather than `[x]` to record this revision.

### Model node no longer reads the anchor map

The parameter-free `GlyphElement.anchor` getter (which read the global
`glyphAnchors` map inside the model and ignored the node's transform) is
**removed**. Legacy render code in `render/note/` still reads anchor fields
directly; it was given minimal `!` null-assertion shims (the beamed-notehead
glyphs always define their stem anchors, so the assertions are safe). This is
the "adapter shim acceptable until WP2" from S1: WP2 makes the renderer a
pure tree-walker, retiring both the shims and `GlyphAnchor.translate`.

### Tests

[`test/graphics/layout/anchors_test.dart`](../../test/graphics/layout/anchors_test.dart)
uses hand-built anchor tables (no global state) to cover: a known SMUFL anchor
read by direct field access; an origin anchor returned rather than treated as
absent; an absent anchor exposed as `null`; and `absoluteAnchorOffset` under
identity, translated+scaled, rotated, and mixed nested transforms (matching
the S1 fixture shape), plus agreement with manual S1 composition (the util
reuses, not duplicates, `absoluteTransform`).
