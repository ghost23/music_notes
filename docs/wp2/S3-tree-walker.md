# WP2-S3 — Pure tree-walker: full transform, styling, unresolved refusal

## Goal

Complete the renderer as a **pure tree-walker** over the WP1 IR: it applies each
node's **full** `NodeTransform` (translation **+ scale + rotation**, not just
translation), draws leaves from their own geometry + resolved `Styling`, and
**refuses to draw an unresolved node** (`isResolved == false`) — enforcing the
WP1-S5 render boundary. It performs **no** measurement, positioning, spacing, or
grid logic; every number it draws is already on the tree, converted to pixels
via the S2 scaling measure.

After this story, `render/*` contains only a tree-walker: given an IR root and
the scaling measure, it draws the subtree and does nothing else.

## Background

The WP1-S2 shim (`draw_primitives.dart`) is already structured as a tree-walk
that switches on the sealed `Element` type and recurses through
`Element.elements`, and it already implements the "no styling defaults, throw on
missing" contract. Two gaps remain against the WP1 contract:

1. **Only translation is applied.** `drawTranslated` does
   `canvas.translate(pointOfOrigin…)` and ignores the `scale` and `rotation`
   that `NodeTransform` carries (and that `NodeTransform.toMatrix4()` already
   encodes in SRT order). A rotated beam or a scaled glyph would render wrong.
   The `pointOfOrigin` getter it reads is itself a WP1 adapter shim slated for
   removal.
2. **Unresolved nodes are not refused.** WP1-S5 is explicit: the `isResolved`
   flag "is enforced only at the **render boundary** (WP2): the renderer refuses
   to draw an unresolved node, so unresolved geometry never reaches the canvas."
   The shim does not check it.

This story closes both and drops the WP1→legacy adapter shims the walker used.

## Scope

**In:**

- **Apply the full per-node transform.** Replace translation-only placement with
  application of the node's complete `NodeTransform` — using
  `NodeTransform.toMatrix4()` composed onto the canvas transform (e.g.
  `canvas.save()` / `canvas.transform(matrix)` / draw / `canvas.restore()`), so
  translation, per-axis scale, and rotation all take effect in SRT order. This
  works uniformly for leaves and containers, so a container's transform applies
  to its whole subtree via canvas state. (How staff-space transforms combine
  with the S2 scaling measure follows the strategy chosen in S2 — e.g. a single
  root canvas scale, then transforms applied in staff-space.)
- **Refuse unresolved nodes (WP1-S5 boundary).** When the walk reaches a node
  with `isResolved == false`, **throw** a clear error (consistent with the
  exceptions-over-null principle) — unresolved geometry must never be drawn.
  Document that this is the single enforcement point for the S5 flag. Decide and
  document the granularity: refusing at the unresolved node (and thus its
  subtree) is the contract; whether the whole render aborts or reports the
  offending node is an error-reporting choice — prefer a precise error naming the
  node type.
- **Draw leaves from IR data only.** `GlyphElement` → SMUFL glyph via the
  generated `glyphFontCodeMap` + the 'Bravura' font binding (a render-phase
  resource binding, not IR state) at the S2-derived pixel font size;
  `LineElement`/`RectElement`/`PathElement` → their own geometry with a `Paint`
  built from resolved `Styling`. No widths, offsets, or positions are computed
  here.
- **Reaffirm the styling contract.** Keep "the renderer has no defaults; throw on
  a missing required scale-free property; fill-vs-stroke derived from color
  presence." Where both fill and stroke are set, implement the intended
  two-pass (fill then stroke) draw the shim deferred, or document explicitly why
  a single pass suffices for the first milestone.
- **Remove the WP1 adapter shims the walker relied on** (`Element.pointOfOrigin`
  get/set and, if now unused, `Element.boundingBox`) once nothing references
  them — the "to be removed in WP2" note on them in
  `canvas_primitives.dart` comes due here. (Confirm no *kept* code still uses
  them before deleting.)
- **Tests** with a recording canvas / hand-built IR:
  - a node with non-identity scale and rotation places its child where the
    composed transform predicts (assert via the transform math, not pixels);
  - drawing a subtree containing an `isResolved == false` node throws;
  - the existing "no styling defaults" throw/return cases still hold.

**Out:**

- The `CustomPainter` and `main.dart` wiring, and the end-to-end fixture render
  (S4).
- Deferred-element **resolution** (turning an unresolved slur/beam into
  primitives) — that is WP6; here the renderer only *refuses* unresolved nodes.
- Any layout/measurement — explicitly forbidden in the render phase.

## Design notes

- **Transform application via the matrix, not manual math.** `NodeTransform`
  already produces a correct SRT `Matrix4`; feed it to the canvas rather than
  re-deriving translate/rotate/scale by hand. This keeps the render convention
  and the IR convention identical by construction and avoids sign/order bugs
  (y-down, clockwise-positive rotation — see `NodeTransform` docs).
- **Container = transform + recurse.** A `GroupElement`/`CompositeElement` has no
  own drawable geometry; it applies its transform and recurses into `elements`
  in draw order. Leaves apply their transform and paint. One uniform rule.
- **`isResolved` is informational everywhere except here.** WP1 is deliberate
  that the model getters stay inspectable while unresolved (they return tentative
  values, never throw) so layout passes can assess them; the *only* place the
  flag becomes a hard gate is this render boundary. Keep that asymmetry intact —
  do not make model getters throw.
- **No styling defaults — reaffirmed, not re-litigated.** The throw-on-missing
  behaviour and its rationale are settled (WP1-S2 + `rewrite-plan.md`); this
  story carries it forward unchanged and keeps the shim's contract tests.
- **Purity check.** After this story, grepping `render/` should surface no
  advance widths, no `staffYPos`, no column/measure spacing, no engraving-default
  lookups for *positioning* — only glyph-code/font/paint lookups needed to draw
  what the IR already positioned.
- **Collapse to a single public entry point.** `drawElement` already dispatches
  exhaustively over the sealed `Element` and applies the same `_withScale` +
  private walker the per-type functions do; `drawPathElement` / `drawLineElement`
  / `drawRectElement` / `drawGlyphElement` are therefore pure redundancy (each is
  just `_withScale` wrapping a private walker that `drawElement` already calls).
  Collapse them: keep only the private staff-space walkers (`_drawPath`/
  `_drawLine`/`_drawRect`/`_drawGlyph`) called from the `drawElement` switch,
  and drop the four public wrappers. `drawElement` becomes the **sole** public
  entry point. This removes duplicated `_withScale` calls and — more importantly —
  means the new full-transform walk and the unresolved-node refusal need enforcing
  at **one** place, not five. Update the only external caller,
  `draw_primitives_test.dart`, to call `drawElement` instead of the per-type
  functions (which also exercises the real dispatch path instead of bypassing
  it).

## Acceptance criteria

- [x] The renderer applies each node's full `NodeTransform` (translation, scale,
      rotation) via `toMatrix4()`; a hand-built tree with nested scale + rotation
      draws children at the composed positions predicted by the transform math.
- [x] Reaching a node with `isResolved == false` during the walk **throws**;
      this is documented as the sole enforcement point of the WP1-S5 flag, and
      the model getters remain non-throwing while unresolved.
- [x] Leaves draw purely from their own IR geometry + resolved `Styling` + the
      S2 scaling measure; containers apply their transform and recurse. No
      measurement/positioning code exists in `render/*`.
- [x] The "no styling defaults / throw on missing / fill-vs-stroke from color
      presence" contract holds, with fill+stroke handled (two-pass) or its
      single-pass simplification documented.
- [x] The WP1 legacy adapter shims (`pointOfOrigin`, and `boundingBox` if now
      unused) are removed from `canvas_primitives.dart`, with no remaining
      references.
- [x] Unit tests cover the transform composition, the unresolved-refusal, and
      the styling cases; the full WP1 suite plus the render tests pass.
