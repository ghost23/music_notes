# WP2-S2 — Single render scaling measure (staff-space → pixels)

## Goal

Give the renderer **one** explicit, documented scaling measure that converts the
IR's staff-space units into pixels, and thread it through the tree-walker —
replacing the hard-coded `_defaultPixelsPerStaffSpace = 8` placeholder in
`draw_primitives.dart`. This is the boundary the resolved "Coordinate system"
decision (`rewrite-plan.md`) reserves as the renderer's **only** own numeric
contribution: the IR carries no pixels; the renderer supplies exactly one
scale and derives every pixel value from it.

After this story, calling the renderer requires passing the scaling measure; the
staff-space → pixel arithmetic lives in one clearly-named place; and changing
zoom/size is a matter of passing a different measure, never re-running layout.

## Background

The resolved decision states:

> The **renderer** is handed a single concrete scaling measure (e.g. a font size
> for the SMUFL font) and converts staff-space → pixels at draw time.
> Consequences: scaling is a render-phase concern only; the IR stores no pixel
> values; zoom/resize never re-runs layout.

The WP1-S2 shim already localises the arithmetic (`strokeWidth × scale`;
glyph pixel font size `4 × scale`, since 1 em = 4 staff spaces = 1 staff
height), but behind a **placeholder constant** with a `[double scale = …]`
default argument on every draw function. That default is a stand-in "until WP2
threads the real one through every draw call" (per the shim's own doc). This
story does that threading and pins the measure's definition.

## Scope

**In:**

- **Define the scaling measure precisely.** It is the number of **pixels per
  staff space** (equivalently: the SMUFL font size in pixels is `4 ×`
  pixels-per-staff-space, since 1 em = 4 staff spaces). Document the choice and
  the em relationship in one place. Represent it either as a well-named `double`
  parameter or a tiny immutable value type (e.g. a `RenderScale` /
  `RenderStyle`) — pick the smallest thing that reads clearly; do **not**
  introduce dependency injection or hidden global state (per the principles).
- **Thread it through the renderer.** Every draw function takes the measure
  explicitly (or reads it from the passed value type); remove the default
  argument and the `_defaultPixelsPerStaffSpace` constant so a caller **must**
  supply it. The staff-space → pixel conversions (stroke width, glyph font size,
  and — see the design note — how a node's staff-space translation is turned
  into pixels) all derive from this one measure.
- **Centralise the arithmetic.** The two (three, with translation) conversions
  live in named helpers, not inline magic numbers, so the "1 em = 4 staff
  spaces" fact appears once.
- **Unit tests** that the conversions are correct functions of the measure
  (e.g. doubling the measure doubles the pixel stroke width and glyph font
  size), independent of any real canvas.

**Out:**

- Applying `scale`/`rotation` from a node's `NodeTransform`, and the
  unresolved-node refusal — that is S3. This story only establishes the *scaling
  measure* and its threading; S3 uses it while completing the transform walk.
- Choosing the *concrete* pixel value for the app (that is a call site concern:
  `main.dart` in S4 picks a value; the renderer stays parameterised).
- Any `Paint`/`TextStyle` policy change — the "no defaults, throw on missing"
  rules are unchanged from the shim and reaffirmed in S3.

## Design notes

- **One measure, not per-node scale.** The per-node `scale` in `NodeTransform`
  is a *layout* quantity (a scaled glyph, a squashed beam) and stays in
  staff-space; it is unitless and composes within the tree. The **render**
  scaling measure is different: it is the single global staff-space→pixel factor
  applied once. Keep the two concepts distinct in naming and docs so they are
  not confused.
- **Where the unit conversion happens — a decision to pin.** Two equivalent
  strategies:
  1. **Per-leaf conversion (what the shim does today).** The tree-walk works in
     pixel space; each leaf converts its staff-space numbers using the measure
     (`strokeWidth × scale`, font size `4 × scale`, translation `× scale`).
  2. **Scale-the-canvas-once.** Apply the measure as a single root
     `canvas.scale(measure)`, then walk and draw entirely in **staff-space
     units** (translations, stroke widths, and a glyph font size of `4` are all
     in staff spaces; the canvas scale turns them into pixels). This makes the
     tree-walker itself unit-agnostic — a cleaner fit for "pure tree-walker".

  The resolved decision's phrasing (`strokeWidth × scale`, `4 × scale`) matches
  strategy 1, but strategy 2 yields the same pixels and a simpler walker.
  **Recommendation:** adopt strategy 2 (scale the canvas once, walk in
  staff-space) unless a concrete problem surfaces (e.g. stroke-width or text
  hinting under canvas scale). Whichever is chosen, document it here and keep the
  measure's *definition* (pixels per staff space) identical.
- **Reuse before rolling.** If a tiny value type is introduced, keep it a plain
  immutable data class with a `copyWith` (allowed by the principles); do not
  reach for a package for something this small.
- **Exceptions over silent fallback.** A non-positive or NaN scaling measure is
  a programmer error — throw, consistent with `NodeTransform`'s NaN guard.

## Decision: unit-conversion strategy

**Adopted: strategy 2 — scale-the-canvas-once.** Each public draw entry point
applies `RenderScale.pixelsPerStaffSpace` as a single root `canvas.scale(...)`
and then walks the tree in staff-space units (translations, leaf geometry,
stroke widths, and a glyph font size of `RenderScale.staffSpacesPerEm` = 4 are
all staff-space; the root scale turns them into pixels). This matches the
story's recommendation: the walker is unit-agnostic, and all staff-space
geometry — including `Path`/`Rect`/line endpoints, which a per-leaf strategy
would have to scale piecemeal — is converted in one place. The measure's
*definition* (pixels per staff space) is identical either way.

The rejected per-leaf strategy would yield the same pixels but re-introduce
pixel arithmetic at every leaf. The one caveat with scaling the canvas — glyph
rasterisation under a large canvas scale — is judged non-blocking for the
vector (OpenType) SMUFL font; should glyph quality degrade, the localized fix
is to render each glyph at `RenderScale.pixelEmFontSize` with the canvas scale
reset around it, without changing the measure's definition. Documented in
`lib/graphics/render/render_scale.dart` and `draw_primitives.dart`.

## Acceptance criteria

- [x] The render scaling measure is defined and documented as **pixels per staff
      space**, with the "1 em = 4 staff spaces" relationship stated once.
- [x] The `_defaultPixelsPerStaffSpace` placeholder and the default `scale`
      arguments are gone; every draw entry point **requires** the measure
      (explicit parameter or passed value type — no global, no DI).
- [x] The staff-space → pixel conversions live in named helpers; the "× 4" em
      factor is not duplicated.
- [x] The chosen unit-conversion strategy (per-leaf vs scale-the-canvas-once) is
      documented in the story/code, and the two glyph/stroke conversions produce
      pixel values that are correct functions of the measure.
- [x] A non-positive / NaN measure throws.
- [x] Unit tests assert the conversions scale correctly with the measure; the
      existing `draw_primitives` "no styling defaults" tests still pass.
- [x] Project compiles; WP1 suite passes.
