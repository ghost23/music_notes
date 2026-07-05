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
positioned relative to that staff.

MusicXML expresses this via `Attributes.staves` and per-staff `Clef`s, and each
`Note` carries a `staff` index (`data.dart`).

## Scope

**In:**
- A **system** container node grouping ordered **staff** nodes (S3 declared
  these types; S6 gives them arrangement geometry).
- Vertical placement of staves within a system, in staff-space units, via a
  transform (reusing S1) — staff *N* offset below staff *N−1* by a documented
  inter-staff distance.
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

- [ ] A system node can contain N staff nodes (N ≥ 2) arranged vertically with a
      documented inter-staff distance in staff-space units.
- [ ] Each staff node has a well-defined local origin and staff-line region;
      composing transforms (S1) maps a staff-relative point into system space.
- [ ] A free function returns each staff's absolute vertical position and the
      system's total vertical extent, verified against hand-computed values.
- [ ] The inter-staff distance is a parameter (not hard-coded global); its
      default and rationale are documented, and the content-driven-spacing
      decision is explicitly deferred with a pointer to `rewrite-plan.md`.
- [ ] Unit tests build a 2-staff system and assert staff offsets and overall
      vertical extent in staff-space units.
- [ ] Project compiles.
