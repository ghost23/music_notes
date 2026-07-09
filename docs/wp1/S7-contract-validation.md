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

### What lives where

- **The fixture** — [`test/support/wp1_contract_fixture.dart`](../../test/support/wp1_contract_fixture.dart):
  - `buildWp1ContractFixture()` builds a 2-staff system (system → part →
    staff1/staff2, each with a measure holding a clef in its `attributes` group
    and note(s) in columns), arranged by S6's `arrangeStavesVertical`. Each
    staff has **two measures**: the first carries the clef and a **4/4 time
    signature** (`TimeSignatureElement`, beats/beatType both `timeSig4`) in its
    `attributes` group; the second is offset to `x = 12`. Staff1 (treble,
    gClef) carries Note A `(5,2)` with a stem placed at the notehead's
    `stemUpSE` anchor (S4), Note B `(8,1)` with a **sharp accidental**
    (`accidentalSharp`), and — in measure 2 — an **eighth note** `(13,2)`
    (notehead + stem + `flag8thUp`, the flag placed via its `stemUpNW` anchor at
    the stem top, exercising a second S4 anchor). Staff2 (bass, fClef) carries
    Note C `(5,3)` and — in measure 2 — a **full rest** (`restWhole`) `(13,14)`.
    A deferred `SlurElement` in staff1's first column cross-references
    noteheadA & noteheadB by identity, each with the `stemUpSE` local anchor
    (exercising S4 + S5 together). It returns a `Wp1ContractFixture` with
    handles to the root and every node the tests / WP2 / WP3 need to reach by
    identity.
  - `fakeResolveSlur(slur, index)` — the trivial resolver (straight line
    between the two cross-references' absolute anchor points via
    `crossReferenceAbsoluteOffset`), mutating the slur in place
    (identity-stable).
  - The hand-computed expected values are documented in the library doc and
    exposed as named constants (`expectedNoteheadAStemUpSeAbsolute`, etc.) so
    WP2/WP3 tests assert against the same arithmetic the builder used.
- **The tests** — [`test/graphics/wp1_contract_test.dart`](../../test/graphics/wp1_contract_test.dart)
  drive a fresh fixture per test and assert, by story:
  - **S6** — per-staff absolute origins via the S5 index (`(0,0)` / `(0,12)`)
    and note/rest absolute origins composing through the staff transforms
    (`(5,2)`, `(8,1)`, `(5,15)`, eighth note `(13,2)`, full rest `(13,14)`);
  - **S1** — the system's total bounding box `(−0.02, −4.392, 15.236, 16)`
    (real `gClef`/`fClef`/`noteheadBlack`/`flag8thUp`/`timeSig4`/… bboxes
    composed with the clean transforms; top from `gClef`, bottom from staff2's
    line region, left from `fClef`, right from the eighth-note flag),
    `systemVerticalExtent` agreeing with the height, and the bbox unchanged by
    slur resolution (the resolved line fits);
  - **S4** — the notehead's `stemUpSE` anchor resolving to `(6.18, 1.832)`
    (and B to `(9.18, 0.832)`), the stem's start point landing exactly on that
    anchor, **and** the eighth-note flag's `stemUpNW` anchor coinciding with
    the stem top `(14.18, −1.168)` — proving two anchor attachments;
  - **S5** — the slur being the only unresolved node, `fakeResolveSlur`
    drawing the line `(6.18, 1.832)→(9.18, 0.832)`, traversal no longer
    reporting it after resolution, and the slur staying the same object
    (identity-stable);
  - **S3** — the extended taxonomy: each staff's first measure carries a 4/4
    `TimeSignatureElement` (two `timeSig4` numeral roles), the eighth note is
    a notehead + stem + `flag8thUp` composite, the second measure of staff2
    holds a `RestElement` (`restWhole`), note B carries a sharp `accidental`
    role drawn before the notehead, and each staff has two measures with
    measure 2 offset to `x = 12`;
  - **S2** — noteheads carry a fill color, the stem a stroke + staff-space
    width, and no drawable leaf reaches the renderer with `Styling.inherit`
    (no `Paint`/`TextStyle`/pixel values anywhere in the fixture).

### Design notes honoured

- **Hand-computable, exact assertions.** All transforms are clean staff-space
  values; the composition arithmetic is restated in each assertion's comments.
  The only non-integer inputs are the real SMUFL glyph bboxes / anchors
  (`noteheadBlack.stemUpSE = (1.18, −0.168)`, `flag8thUp.stemUpNW =
  (0, 0.04)`, the `gClef`/`fClef`/`flag8thUp` bboxes) — looked-up facts,
  documented in the fixture's library doc, asserted with a tiny fp tolerance.
- **Reusable across WPs.** The fixture is a `test/support/` file (importable
  by other test files via relative path) so WP2's render tests and WP3's
  layout tests build against the same golden example. It consumes the contract
  as-is — no IR changes — confirming S7's claim that WP2/WP3 can build against
  WP1 without further IR work for the first milestone.
- **No musical correctness.** Clef glyphs are placed at the staff origin
  (not aligned to a staff line), the slur is a straight line (not a curve),
  and the stem is a fixed length — deliberately, since real engraving is WP5/6.
  The fixture is a *contract* demonstrator, not a rendered score.
