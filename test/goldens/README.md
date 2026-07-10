# Goldens (visual-regression harness)

Reference images for the WP2-S5 golden harness. The harness lives in
[`golden_harness.dart`](./golden_harness.dart); it renders an IR `Element` tree
through the same `IRTreePainter` the app uses (S4) and compares via Flutter's
built-in `matchesGoldenFile`. Later work packages (WP3/WP5/WP6) reuse the harness
and only add new reference images here — "run throughout".

## Files

- `golden_harness.dart` — the reusable render-to-image + compare helpers
  (`renderTreeToImage`, `expectTreeMatchesGolden`). No layout, no duplicated
  render setup; it delegates drawing to `IRTreePainter`.
- `wp1_fixture_golden_test.dart` — the first golden: the resolved WP1-S7
  contract fixture.
- `wp1_contract_fixture.png` — its committed reference image.

## Workflow

### Running goldens

```
flutter test test/goldens
```

A golden test renders the fixture and compares it to the committed PNG. A
mismatch fails the test with a diff.

### Regenerating / updating a golden

```
flutter test --update-goldens test/goldens
```

`--update-goldens` (re)writes the reference PNG from the current render output.
**This is a conscious act, not a reflex:** only update a golden for an
*intended* visual change (a deliberate render/layout refinement), and review the
resulting image diff like any other code change. Regenerating to make a failing
test green, without the change being intended, defeats the harness's purpose —
it would lock in a regression.

When you add a golden for a new fixture, run `--update-goldens` once to create
the reference, then commit it.

## Deterministic inputs

A golden is only meaningful if its inputs are fixed. The harness pins, per
fixture:

- the **render scaling measure** (`RenderScale`), documented in the test;
- the **image size** and the **viewport origin** (where staff-space (0,0) maps
  on the image), computed from the fixture's absolute bounding box at a fixed
  margin;
- a **white background** (transparent areas become white, so the only pixel
  variable is the rendered tree);
- the **tree** — deferred elements are resolved before rendering (the S3 walker
  refuses unresolved nodes).

Fonts are loaded once for the whole suite in `flutter_test_config.dart`
(Bravura SMUFL font + BravuraText), so glyphs rasterise as real glyphs, not
missing-glyph boxes.

## Platform / consistency decision

**Goldens are pinned to macOS** — the project's development platform and a
desktop build target. Generate and update goldens only on macOS.

Flutter's rasterisation (font hinting, anti-aliasing, subpixel positioning)
differs across platforms, so a golden generated on macOS may not match the same
render on Windows/Linux. This is expected. Concretely:

- Generate / update goldens on macOS.
- If CI is introduced, pin it to macOS, or — if cross-platform CI is required —
  adopt a tolerant comparator (Flutter supports a custom
  `GoldenFileComparator`; a tolerance-based one can absorb subpixel diffs). The
  harness itself is platform-agnostic; only the comparator would change.

Within macOS, `flutter test` is deterministic: a committed golden is a stable
reference until an intended change is made.
