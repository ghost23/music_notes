# WP2-S4 — `CustomPaint` entry point + end-to-end proof on the S7 fixture

## Goal

Prove the IR → render pipeline **end-to-end** by rendering the WP1 S7 contract
fixture — a hand-built multi-staff scene graph — through the S3 tree-walker onto
a real Flutter canvas, via a minimal `CustomPainter`. Rewire `main.dart` to
display the fixture, replacing the S1 placeholder and removing the last trace of
the legacy `MusicLine` path. This is WP2's capstone: it confirms that the WP1 IR
is drawable **as-is**, with no IR changes and no layout engine.

After this story, running the app draws the S7 fixture, and an automated test
renders the same fixture without error — the shared example WP3/WP5/WP6 will
grow into real music.

## Background

WP1-S7 built `buildWp1ContractFixture()` in
[`test/support/wp1_contract_fixture.dart`](../../test/support/wp1_contract_fixture.dart):
a 2-staff system (system → part → staves → measures → columns) with clefs,
notes (notehead + stem placed via S4 anchors), a time signature, an accidental,
an eighth-note flag, a rest, and a deferred slur with a fake resolver. It was
built explicitly to be "shaped so WP2 can reuse it" as a golden example, in
staff-space units with no pixels/`Paint`/`TextStyle`.

That fixture is the natural end-to-end subject: it exercises containers, glyphs,
lines, anchors, multi-staff vertical arrangement, and (once its fake resolver
runs) a resolved deferred element — everything the S3 walker must handle. Because
WP3 does not exist yet, the fixture (not a parsed `Score`) is what the renderer
consumes for now.

## Scope

**In:**

- **A minimal IR-consuming `CustomPainter`** that takes an IR root `Element` and
  the S2 render scaling measure, and paints the tree by calling the S3
  tree-walker. It performs **no** layout — it is the thinnest possible bridge
  from an `Element` tree + scale to `CustomPainter.paint`. `shouldRepaint`
  compares the root and the scaling measure.
- **Rewire `main.dart`** to build the S7 fixture (resolving its deferred slur via
  the fixture's `fakeResolveSlur` so no unresolved node reaches the renderer —
  see S3) and display it through the new `CustomPainter`, picking a concrete
  pixels-per-staff-space value for the app. Remove the S1 placeholder.
- **An end-to-end render test** that paints the fixture to a recording canvas
  (`PictureRecorder`) through the `CustomPainter` / tree-walker and asserts it
  completes without throwing (proving no unresolved node, no missing styling, no
  contract violation reaches the canvas). Optionally rasterise the recorded
  picture to an image to confirm it produces non-empty output.
- **Sharing:** keep the fixture the single source (import it; do not duplicate a
  second hand-built tree), so WP2's render test and WP1's geometry tests assert
  against the same example.

**Out:**

- **The golden-image regression harness** (capturing a reference PNG and failing
  on visual diffs) — that is the **next story, [S5](./S5-visual-regression-harness.md)**.
  S4's automated test proves *renders without error / produces output*, not
  *matches a pixel-exact reference*; S5 adds the golden comparison, font loading,
  and tolerance/platform decisions on top of exactly the painter S4 delivers.
- **Full widget integration** (responsive sizing, zoom controls, scrolling,
  multiple systems) — the WP7 era (needs real scores + multiple systems).
- **Rendering a real parsed `Score`** — needs the WP3 layout engine to build the
  IR from the data model; not possible in WP2.
- **Engraving correctness** — the fixture is a contract demonstrator (clefs at
  the staff origin, straight-line slur, fixed stems), as WP1-S7 documents.

## Design notes

- **Resolve before rendering.** The fixture ships an *unresolved* `SlurElement`;
  S3's renderer refuses unresolved nodes. So the entry point must run the
  fixture's `fakeResolveSlur` (the S5 mechanism demonstrator) before painting.
  This is a faithful preview of the real pipeline order: WP3 resolves deferred
  elements, *then* the renderer draws — the fake resolver stands in for WP6 math.
- **The painter owns no state.** Per the principles, the `CustomPainter` is a
  thin function of (root, scale): no measurement, no caching of layout, no hidden
  lookups. It is deliberately trivial so the S5 golden harness can drive it
  directly, and so the WP7-era widget layer can wrap/replace it without touching
  the render core.
- **Pick the app's scale at the call site, not in the renderer.** `main.dart`
  chooses a concrete pixels-per-staff-space value (the legacy app used
  `staffHeight = 36`, i.e. 9 px per staff space); the renderer stays
  parameterised (S2). Document the value chosen.
- **This is the definition-of-done demonstrator for WP2**, mirroring how S7 was
  the demonstrator for WP1: a hand-built example driven through the real code
  path, proving the contract composes — here, that the IR renders.

## Acceptance criteria

- [ ] A minimal `CustomPainter` renders an arbitrary IR root at a given scaling
      measure by delegating to the S3 tree-walker, with correct `shouldRepaint`
      and no layout logic of its own.
- [ ] `main.dart` builds the WP1 S7 fixture, resolves its deferred slur, and
      displays it through the new painter; the legacy `MusicLine` path and the S1
      placeholder are gone.
- [ ] An automated test renders the (resolved) S7 fixture through the painter /
      tree-walker to a recording canvas and completes without throwing;
      (optionally) the rasterised output is non-empty.
- [ ] The test imports the shared `buildWp1ContractFixture()` rather than
      duplicating a hand-built tree.
- [ ] Running the app draws the multi-staff fixture (manual/visual check);
      `flutter analyze` is clean and the full WP1 + WP2 test suite passes.
- [ ] WP2's "definition of done" in [`README.md`](./README.md) is satisfied.
