# WP1-S7 — Contract-validation fixture (multi-staff)

## Goal

Prove the WP1 IR contract end-to-end by **hand-building** a small multi-staff
scene graph (no layout engine, no rules yet) and verifying its geometry with
tests. This is the capstone that confirms S1–S6 compose into a usable contract
before WP2/WP3 build on it.

## Background

WP1 delivers a contract, not behaviour. The risk is that the pieces (transforms,
scale-free model, taxonomy, anchors, deferred refs, multi-staff containers) look
fine individually but don't fit together. A hand-built reference fixture exercises
the whole contract and becomes the shared example WP2 (render) and WP3 (layout)
target.

## Scope

**In:**
- A fixture, constructed purely with IR constructors/free functions, representing
  **one multi-staff line**: a system with ≥ 2 staves, each with a clef glyph and
  a few notes (notehead + stem), positioned in staff-space.
- At least one **anchor-based attachment** (e.g. a stem placed at a notehead
  anchor via S4) to exercise anchors.
- At least one **deferred/unresolved element** (e.g. a placeholder slur/tie via
  S5) plus a trivial fake resolver, to exercise the deferred-reference mechanism.
- Tests asserting absolute staff-space geometry: staff offsets (S6), composed
  bounding boxes (S1), a resolved anchor position (S4), and that the unresolved
  element is found by traversal and resolves correctly (S5).

**Out:**
- Real musical correctness / engraving accuracy (that comes with rules in WP5/6).
- Rendering to a canvas (WP2) — though the fixture should be shaped so WP2 can
  reuse it.
- Reading from an actual MusicXML file (WP3 wires the parser in).

## Design notes

- Build the fixture in test/support code so WP2 and WP3 can import and reuse it
  as a golden example.
- Keep values hand-computable so assertions are exact, not approximate; document
  the arithmetic in comments.
- The fixture is the practical "definition of done" demonstrator for WP1 listed
  in the package README.

## Acceptance criteria

- [ ] A reusable fixture builds a ≥ 2-staff system with clefs and notes using
      only IR types and free functions, in staff-space units.
- [ ] Tests assert: per-staff absolute vertical positions; the system's total
      bounding box; a stem placed via a notehead anchor resolves to the expected
      absolute point; a deferred element is discovered by traversal and resolves
      via a fake resolver to expected geometry.
- [ ] The fixture contains no pixel values, `Paint`, or `TextStyle` (S2 holds).
- [ ] All WP1 unit tests (S1–S6) plus this fixture pass together.
- [ ] The fixture lives where WP2/WP3 can import it, and the README's "definition
      of done for WP1" is satisfied and checked off.
