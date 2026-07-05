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

- [ ] A glyph element's named anchor can be obtained in **local** staff-space
      coordinates, given the element and glyph metadata (method or free function).
- [ ] A free function returns the same anchor in **absolute** staff-space
      coordinates, correctly composing nested translation/scale/rotation (S1).
- [ ] Requesting a non-existent anchor **throws** a descriptive exception (no
      silent null).
- [ ] Glyph metadata is supplied as a parameter to the anchor lookup, so tests
      run with hand-built fixtures and no global state.
- [ ] Unit tests cover: a known SMUFL anchor in local space; the same under a
      translated+scaled parent; and the missing-anchor exception.
- [ ] The model node no longer reads the generated anchor map *inside* its own
      logic; the metadata is passed in (the current parameter-free `anchor`
      getter is replaced accordingly).
