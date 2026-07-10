# Legacy render code (WP5/WP6 source material)

> **Old, unused, reference-only.** This directory is **not compiled and not
> imported** by anything under `lib/` or `test/`. It lives under `docs/`
> (outside the Dart analysis roots) so tooling never analyses it. It is kept
> solely as reading material for the future work packages that will port this
> logic into the new layout-rule system.

## Origin

This code was moved out of `lib/graphics/render/` as part of **WP2-S1
(legacy render cleanup)**. The rewrite plan (`docs/rewrite-plan.md`) names these
files as *"source logic to migrate into WP5/WP6 rules"*:

- `measure.dart` — the legacy measure-grid / column derivation
  (`createGridForMeasure`). Source for **WP5** intra-measure horizontal
  spacing.
- `note/note.dart`, `note/pitch_note.dart`, `note/rest_note.dart`,
  `note/ledger.dart` — note / pitch / rest / ledger-line geometry. Source for
  **WP5** note vertical position, accidentals, ledger lines, rests.
- `beam.dart` — beam geometry. Source for **WP6** context-dependent
  (cross-element) symbols.

## What is *not* here

The pure single-pass draw plumbing and ad-hoc geometry typedefs
(`music_line.dart`, `render/drawing_context.dart`, `render/glyph.dart`,
`render/common.dart`, `render/staff.dart`, `graphics_model/measure.dart`,
`graphics_model/__glyph.dart`, `graphics_model/__note.dart`) were **deleted,
not archived**: no WP5/WP6 author needs to read draw-call plumbing or typedefs
to port the layout logic, and git history preserves them. The barline *style*
vocabulary (`BarLineTypes`) was relocated into the data model
(`lib/musicXML/data.dart`), not archived.

## Caveat for readers

The `import` paths inside these files still reflect their **original** location
under `lib/graphics/render/`. They will not resolve from `docs/` — that is
intentional. When porting a piece of logic, read the algorithm, do not try to
run this code directly.
