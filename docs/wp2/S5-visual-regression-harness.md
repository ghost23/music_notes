# WP2-S5 — Visual-regression (golden) harness

## Goal

Stand up a reusable **visual-regression harness**: render an IR root at a given
scaling measure to an image and compare it against a committed **golden**
reference, failing on unexpected visual change. Commit the first golden — the
WP1-S7 contract fixture rendered through the WP2 tree-walker. This turns S4's
"renders without error" into "renders **correctly and stably**", and gives every
later work package (WP3/WP5/WP6) a safety net so a layout-rule refinement cannot
silently break an already-correct result.

This story absorbs the "stand up early, run throughout" half of the original
WP8. The full app/widget integration (responsive sizing, zoom, scroll, multiple
systems) is **not** here — it needs real parsed scores (WP3) and multi-system
content (WP7), and is deferred to that era.

## Background

`rewrite-plan.md` listed WP8 as "Widget / `CustomPaint` rewiring and a
visual-regression harness (golden images), so layout-rule refinements don't
silently break earlier results. **Stand up early, run throughout.**" WP2 is the
earliest point where that is possible: S3 gives a pure renderer and S4 gives a
`CustomPainter` and a concrete thing to draw (the WP1-S7 fixture).

S4's automated test proves the pipeline *completes* (no unresolved node, no
missing styling, no contract violation reaches the canvas). A golden test proves
something stronger and complementary: the pixels are what we expect and **stay**
that way. Because the WP1-S7 fixture is the shared example WP3/WP5/WP6 build on, a
golden of it is the single most valuable regression anchor we can plant now.

The legacy `test/goldens/main_demo.png` (deleted in S1) is a leftover from the
main-branch renderer and is **not** reused; S5 produces a fresh golden from the
new pipeline.

## Scope

**In:**

- **A reusable golden test helper** that renders an arbitrary IR root at a
  scaling measure to an image (via the S4 `CustomPainter` / S3 tree-walker on a
  `PictureRecorder` → `Picture.toImage`) and asserts it against a golden file
  with `matchesGoldenFile`. It is a thin function later WPs call with their own
  fixtures — no layout, no duplicated render setup.
- **Deterministic font loading in tests.** The Bravura SMUFL font must be loaded
  into the test environment so glyphs rasterise consistently — wire this through
  the existing `flutter_test_config.dart` (currently a no-op passthrough), e.g. a
  `FontLoader` for Bravura (and any text font) before tests run. Without this,
  glyph goldens render as missing-glyph boxes.
- **The first committed golden:** the WP1-S7 fixture (deferred slur resolved via
  `fakeResolveSlur`, per S3/S4) rendered at a fixed, documented scaling measure,
  at a fixed canvas size, checked in under `test/goldens/`.
- **A documented update workflow:** how to regenerate goldens
  (`flutter test --update-goldens`) and when it is legitimate to do so (an
  intended visual change, reviewed like any other diff), so a golden update is a
  conscious act, not a reflex.
- **A platform/consistency decision** for goldens (see design notes), documented
  so failures are interpretable.

**Out:**

- **Full widget / app integration** — responsive layout, zoom, scrolling,
  multi-system UI. Deferred to the WP7 era (needs real scores + multiple
  systems). WP2-S4's minimal `CustomPainter` is the only widget surface for now.
- **Goldens of real parsed scores** — needs the WP3 layout engine to build the
  IR; not possible in WP2. Later WPs add their own goldens using this harness.
- **CI wiring / cross-platform golden infrastructure** beyond the consistency
  decision below — set up as the project's CI matures; the harness itself must
  not presuppose a particular CI.

## Design notes

- **Golden flakiness is the real risk; confront it now.** Flutter goldens differ
  across platforms/renderers (font hinting, anti-aliasing). Pick and document one
  of: (a) pin goldens to a single canonical platform (e.g., only run/update on the
  CI reference OS, skip elsewhere), or (b) allow a small comparison tolerance if
  the harness supports it. "Stand up early" is precisely so we hit this now, with
  one simple fixture, rather than after WP3/5/6 pile untested output on top.
- **Deterministic inputs.** Fix the scaling measure, the canvas size, and the
  background so the only variable is the render output. Resolve the fixture's
  deferred elements before rendering (S3 refuses unresolved nodes).
- **The harness is the durable artifact; the golden is data.** Keep the helper
  general (root + scale + size → comparison) so WP3/WP5/WP6 reuse it verbatim and
  only supply new fixtures + reference images. This is the "run throughout"
  property: nothing new is built later, only goldens added.
- **Reuse, don't reinvent.** Prefer Flutter's built-in `matchesGoldenFile` and
  standard font-loading utilities over a bespoke image-diff system (per the
  principles — check for an existing solution before building one). Only reach
  further if the built-in proves insufficient (e.g. tolerance needs).
- **One fixture, shared.** Import `buildWp1ContractFixture()`; do not hand-build
  a second tree for the golden.

## Acceptance criteria

- [x] A reusable golden helper renders an IR root at a given scaling measure to
      an image and compares it via `matchesGoldenFile`, with no layout logic and
      no render setup duplicated from S4.
- [x] Bravura (and any needed text font) loads deterministically in the test
      environment (via `flutter_test_config.dart`); glyphs rasterise as real
      glyphs, not missing-glyph boxes.
- [x] A first golden of the resolved WP1-S7 fixture is committed under
      `test/goldens/`, produced by the new pipeline at a fixed, documented scale
      and size; the orphan `main_demo.png` is not reused.
- [x] The golden test passes against its reference and fails on an intentional
      perturbation (sanity check that it actually compares pixels).
- [x] The golden-update workflow and the platform/consistency decision are
      documented.
- [x] The test imports the shared `buildWp1ContractFixture()`; the full WP1 +
      WP2 suite passes and `flutter analyze` is clean.
