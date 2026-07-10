# WP1-S6 — Multi-staff system container & vertical arrangement

## Goal

Give the IR the structural nodes and geometry to represent **a single system
containing more than one staff** (e.g. a piano grand staff), with correct
**vertical arrangement** in staff-space units. This is the structural backbone
of the first milestone (one multi-staff line).

## Background

The first milestone is explicitly multi-staff from the start
(`rewrite-plan.md`). The legacy code computed a `staffsSpacing` value ad hoc;
the IR needs a first-class notion of a system grouping staves stacked vertically,
each staff being its own coordinate region, so notes/measures within a staff are
positioned relative to that staff. At the same time two staves can also be visually
linked to each other, for example when a melody starts on one staff and continues
on the other and a beam connects notes from both staves. Which means the spacing
between staves can be a deferred property.

MusicXML expresses this via `Attributes.staves` and per-staff `Clef`s, and each
`Note` carries a `staff` index (`data.dart`).

## Scope

**In:**
- A **system** container node grouping ordered **staff** nodes (S3 declared
  these types; S6 gives them arrangement geometry).
- Vertical placement of staves within a system, in staff-space units, via a
  transform (reusing S1) — staff *N* offset below staff *N−1* by a documented
  inter-staff distance that can be dynamic/deferred.
- The staff node defines its local origin and the staff-line region so that a
  note's staff-relative Y maps into system space through transform composition.
- A free function to compute a staff's absolute vertical position / the system's
  overall vertical extent (bounding box via S1 functions).

**Out:**
- Brace/bracket grouping glyphs and labels (later; not required to lay out the
  notes).
- *Content-driven* inter-staff spacing (collision-aware spacing); for the first
  milestone a documented fixed/parameterised inter-staff distance is acceptable.
  (This is the open question in `rewrite-plan.md`; S6 picks the simple option and
  flags it.)
- Multiple systems / line breaking (WP7).

## Design notes

- Staff vertical offsets are transforms on staff nodes, composed by S1's
  functions — do not introduce a separate positioning mechanism.
- Keep the inter-staff distance a parameter passed into the construction free
  function (testability; no global). Document the default and its source.
- A note's staff index from `data.dart` selects which staff node it belongs to;
  WP1 only needs the container to *exist and arrange* — wiring notes into the
  right staff is layout (WP3/WP5), but the contract must make it expressible.

## Acceptance criteria

- [x] A system node can contain N staff nodes (N ≥ 2) arranged vertically with a
      documented inter-staff distance in staff-space units.
- [x] Each staff node has a well-defined local origin and staff-line region;
      composing transforms (S1) maps a staff-relative point into system space.
- [x] A free function returns each staff's absolute vertical position and the
      system's total vertical extent, verified against hand-computed values.
- [x] The inter-staff distance is a parameter (not hard-coded global); its
      default and rationale are documented, and the content-driven-spacing
      decision is explicitly deferred with a pointer to `rewrite-plan.md`.
- [x] Unit tests build a 2-staff system and assert staff offsets and overall
      vertical extent in staff-space units.
- [x] Project compiles.

## Implementation details worth noting

### What lives where

- **Staff-line region & local origin** (`lib/graphics/graphics_model/semantic/structural.dart`)
  — `StaffElement` documents its local origin (top line at `y = 0`) and
  exposes its **staff-line region** as the vertical span of its staff lines
  (`y ∈ [0, staffHeightInStaffSpaces(lineCount)]`; a standard 5-line staff:
  `[0, 4]` staff spaces). The region is a **derived** function of the staff's
  `lineCount` (see the next subsection), surfaced as a `staffLineRegion`
  getter. `StaffElement.localBoundingBox` is overridden to **union the line
  region with the folded descendants**, so a staff truthfully reports its
  line extent even before any content is attached — and the system's extent is
  computable as a bounding box via S1's `absoluteBoundingBox`. The region's
  *horizontal* extent is content-driven (width 0, owned by descendants).
  (**WP2 addition:** the region describes where the lines *are*; the drawable
  staff-line primitives were later added as a **deferred** `StaffElement.staffLines`
  role — one `LineElement` per line, whose length is resolved from the content
  width, exactly because the horizontal extent is content-driven. See
  [`../wp1/S7-contract-validation.md`](./S7-contract-validation.md).)
- **Multi-staff arrangement free functions** (`lib/graphics/layout/system.dart`)
  — the S6 contribution:
  - `arrangeStavesVertical(part, {interStaffDistance})` sets each staff's
    `transform.translation.dy` to `index × distance` (first staff at `dy = 0`).
    Staff offsets are **transforms on staff nodes** (S1), not a separate
    positioning mechanism; it **mutates transforms in place** (not the nodes),
    preserving the S5 identity-stability contract; each staff's X/scale/rotation
    is preserved.
  - `staffAbsoluteOrigin(staff, index)` returns a staff's absolute top-line
    offset, reusing S5's `absoluteTransformIndex` (one top-down walk's composed
    transforms) rather than re-walking per staff; throws on a dangling target.
  - `systemVerticalExtent(system, {parentAbsolute})` returns the system's total
    vertical height as a bounding box via S1's `absoluteBoundingBox` — for N
    standard staves at distance `d` it is `(N−1)·d + 4`.
  - `defaultInterStaffDistance` (`12` staff spaces = 3 staff heights) and
    `defaultInterStaffGap` (`8` = 2 staff heights), documented with their
    source (the legacy `MusicLineState.initState` `staffsSpacing =
    staffHeight * 2`) and the explicit deferral of content-driven spacing with a
    pointer to `rewrite-plan.md`.

### Staff height is derived from a per-staff line count

`staffHeightInStaffSpaces` is **not an independent constant** — it is a
*derived* value: the staff lines sit at `y = 0, 1, …, lineCount−1` (the line
spacing is 1 staff space *by definition* — it is the staff-space unit itself),
so the height (top line to bottom line) is `lineCount − 1` staff spaces. It is
therefore a free function `staffHeightInStaffSpaces([lineCount = staffLineCount])`,
defaulting to the SMUFL standard `staffLineCount = 5` (→ 4 staff spaces), and
throws `ArgumentError` for `lineCount < 1`. Making it a function of the line
count means the height and the line count **cannot drift apart** (an
independent `4.0` constant beside `staffLineCount = 5` could).

`StaffElement` carries its own `lineCount` field (defaulting to `staffLineCount`)
and derives `staffLineRegion` via the function, so the region is genuinely
**per-staff** (the S6 acceptance wording "the staff node *defines* its
staff-line region") rather than a global constant. A non-standard count may be
passed for a 1-line or 6-line staff (e.g. percussion / tab); MusicXML expresses
this via `<staff-details><staff-lines>` (not yet parsed by the current parser;
the field is present so the region is per-staff and forward-compatible). The
first milestone only builds 5-line staves, so the default is always used in
practice — no behaviour change — but the contract is honest about a staff's
region being its own. The default inter-staff gap/distance are derived through
the same function (for the standard 5-line staff).

### `absoluteBoundingBox` refined to reflect a node's own geometry (S1)

S6 introduced the first IR node that carries **own geometry beyond its
children** — a `StaffElement`'s 5-line region. S1's `absoluteBoundingBox`
previously folded a composing node's children directly (keying off
`Element.elements`) and did *not* consult `localBoundingBox` for composing
nodes, so a content-bearing staff's absolute box would have missed its line
region (an empty staff happened to work because the empty-children branch used
`localBoundingBox`). This was an S1 gap that S6's staff-line region exposed.

`absoluteBoundingBox` is therefore simplified to
`transformRect(absoluteTransform(node, parentAbsolute), node.localBoundingBox)`
for **all** nodes. This is **mathematically equivalent** for every existing
S1–S5 node: a `GroupElement`/`CompositeElement`'s `localBoundingBox` already
is the recursive fold of its children's local boxes through their child
transforms, and composing that with the absolute transform equals the previous
fold-of-children's-absolute-boxes (affine transforms distribute over the union).
The change only adds correctness for nodes with own geometry beyond children
(the staff-line region). All S1–S5 geometry fixtures continue to pass
unchanged. The uniformity intent of S1 (open collections vs. fixed composites)
is preserved: both still satisfy the single `localBoundingBox` contract.

### Scope guard-rails

No brace/bracket grouping glyphs or labels (later WP). No content-driven /
collision-aware inter-staff spacing — explicitly deferred to a later WP (open
question in `rewrite-plan.md`); the spacing may become a deferred/resolved
property (S5's `isResolved`) when wired, but the mechanism is not built here.
No multi-system / line breaking (WP7). Wiring notes into the right staff by
`Note.staff` is layout (WP3/WP5); S6 only ensures the container exists,
arranges, and carries each staff's 1-based `staffNumber` so the selection is
expressible.

### Tests

[`test/graphics/layout/system_test.dart`](../../test/graphics/layout/system_test.dart)
builds hand-built `Element` trees (no glyph metadata, no parser) and covers:
the derived height function (`staffHeightInStaffSpaces(lineCount)` for 5/6/1
lines and the `< 1` throw); the staff-line region & per-staff `lineCount` (an
empty 5-line staff reports `[0, 4]`; a 6-line staff reports `[0, 5]`; a
single-line staff `[0, 0]`); a staff with content unions the region with
descendants; `arrangeStavesVertical` on a 2-staff and 3-staff system (offsets
`0, 12, 24` at the default distance; X preserved; the inter-staff distance is
a parameter); transform composition mapping a staff-relative note into system
space (`staff2 dy=12` + note `y=2` → system `y=14`, verified against hand
arithmetic, plus the system's absolute bounding box); `staffAbsoluteOrigin`
per staff via the S5 index (and the bottom line at
`origin.dy + staffHeightInStaffSpaces(lineCount)`, a custom distance, and the
dangling-target throw); `systemVerticalExtent` for 2/3 empty staves (`16` /
`28`), a custom distance (`14`), a 6-line single-staff system (`5`), content
extending below the bottom line (`19`), and agreement with
`absoluteBoundingBox(system).height`; and identity stability — re-arranging in
place keeps node identity stable and a rebuilt S5 index tracks the new
position. A 1-staff system is included to confirm the container is general
(N ≥ 1) even though "multi-staff" means N ≥ 2.

