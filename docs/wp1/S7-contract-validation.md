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
- At least one **deferred/unresolved element** (e.g. a placeholder beam or slur/tie via
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

- [x] A reusable fixture builds a ≥ 2-staff system with clefs and notes using
      only IR types and free functions, in staff-space units.
- [x] Tests assert: per-staff absolute vertical positions; the system's total
      bounding box; a stem placed via a notehead anchor resolves to the expected
      absolute point; a deferred element is discovered by traversal and resolves
      via a fake resolver to expected geometry.
- [x] The fixture contains no pixel values, `Paint`, or `TextStyle` (S2 holds).
- [x] All WP1 unit tests (S1–S6) plus this fixture pass together.
- [x] The fixture lives where WP2/WP3 can import it, and the README's “definition
      of done for WP1” is satisfied and checked off.

## Implementation

S7 ships a reusable, hand-built fixture plus the tests that drive it — no new
IR surface (it consumes the S1–S6 contract as-is, which is the point: it
proves the contract composes).

> **Revised during WP2.** The original fixture was a musically-arbitrary
> collection of quarter notes and a placeholder slur — fine for the contract but
> hard to compare against real engraving. It has been **replaced with a
> musically-faithful grand staff** (see [`test.png`](./test.png), the reference
> reproduced) once the renderer's glyph baseline registration was fixed (WP2
> corrections). Two small taxonomy roles were added to support it —
> `StaffElement.staffLines` (deferred) and `MeasureElement.barline` — and the
> deferred-reference exemplar is now the **staff lines** (their length is
> content-driven) rather than a slur. The description below reflects the current
> fixture.

### What lives where

- **The fixture** — [`lib/graphics/wp1_contract_fixture.dart`](../../lib/graphics/wp1_contract_fixture.dart)
  (in `lib/` so `main.dart` can display it until WP3 builds the IR from a real
  score):
  - `buildWp1ContractFixture()` builds a **grand staff** (system → part →
    staff1/staff2), arranged by S6's `arrangeStavesVertical` (`dy = 0` / `12`).
    Each staff has **two measures** (measure 2 offset to `x = 11`) closed by a
    barline. Measure 1 carries a clef and a **4/4 time signature** in its
    `attributes` group. Glyphs sit at their **SMUFL registration** positions
    (the renderer aligns the glyph baseline to the node origin):
    - **Staff 1 (treble, gClef on the G line `y = 3`)**: two half notes — G4
      `(5.5,3)` with a stem placed at the notehead's `stemUpSE` anchor (S4), and
      A4 `(8.5,2.5)` with a **sharp accidental** — then a **whole note** F5
      `(13,0)` in measure 2.
    - **Staff 2 (bass, fClef on the F line `y = 1`)**: a **whole note** D3
      `(5.5,14)`, then a **whole rest** (`restWhole`) `(13.5,13)` in measure 2.
    - Every measure is closed by a `BarlineElement` (a regular thin barline
      between measures; a **final** thin+thick barline at the end), aligned
      across the two staves.
    - Each staff's **staff lines** are a **deferred** `staffLines` group
      (`isResolved == false`, empty) — their horizontal length is content-driven
      (S5); `resolveStaffLines` / `resolveAllStaffLines` fill in one
      `LineElement` per line once the content width is known.
  - It returns a `Wp1ContractFixture` with handles to the root and every node
    the tests / WP2 / WP3 reach by identity.
- **The tests** — [`test/graphics/wp1_contract_test.dart`](../../test/graphics/wp1_contract_test.dart)
  drive a fresh fixture per test and assert, by story:
  - **S6** — per-staff absolute origins via the S5 index (`(0,0)` / `(0,12)`)
    and note/rest absolute origins composing through the staff transforms
    (G4 `(5.5,3)`, A4 `(8.5,2.5)`, treble whole `(13,0)`, bass whole `(5.5,14)`,
    whole rest `(13.5,13)`);
  - **S1** — the system's composed bounding box `(0, −1.392, 16.4, 16)` (staff
    lines from `x = 0`; top from `gClef`; right from the final barline's thick
    segment; bottom from staff2's line region), with `systemVerticalExtent`
    agreeing with the height;
  - **S4** — the half note's `stemUpSE` anchor resolving to `(6.68, 2.832)`,
    the stem's start landing exactly on it, and the stem extending up by
    `stemLength`;
  - **S5** — both staves' `staffLines` being the only unresolved nodes,
    `resolveStaffLines` filling in one line per staff line and flagging
    resolved, traversal no longer reporting them, and the group staying the same
    object (identity-stable);
  - **S3** — the taxonomy: clefs (`gClef`/`fClef`), 4/4 `TimeSignatureElement`s,
    `noteheadWhole`/`restWhole` glyphs, the sharp `accidental` role drawn before
    its head, and each measure closed by a `BarlineElement` (regular = one
    segment; final = two);
  - **S2** — noteheads fill, stems and staff lines stroke with staff-space
    widths, and no drawable leaf reaches the renderer with `Styling.inherit`.

### Design notes honoured

- **Musically faithful, still hand-computable.** Transforms are clean
  staff-space values; the composition arithmetic is restated in each
  assertion's comments. The non-integer inputs are the real SMUFL glyph bboxes /
  anchors (`noteheadHalf.stemUpSE = (1.18, −0.168)`, the `gClef`/`fClef`/… bboxes)
  — looked-up facts, documented in the fixture's library doc, asserted with a
  tiny fp tolerance.
- **Reusable across WPs.** The single fixture is imported by the WP1 geometry
  tests, WP2's render/golden tests, and `main.dart`, so they all build against
  the same example. It consumes the S1–S6 contract plus the two small roles
  added in WP2 (`staffLines`, `barline`).
- **Real engraving is still later.** Stem lengths are fixed, the two treble
  notes stand in for the reference's dyad, and inter-staff/horizontal spacing is
  hand-set — real engraving rules are WP5/WP6. The fixture is a *contract +
  render* demonstrator, not an engraved score.
