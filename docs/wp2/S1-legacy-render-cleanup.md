# WP2-S1 — Legacy render cleanup (clean slate)

## Goal

Remove the legacy single-pass renderer so it no longer co-exists with the new
WP1 pipeline, leaving a **clean slate** for the pure tree-walker (S2–S4). Legacy
render logic that is genuine **source material** for later work packages
(WP5 intra-measure rules, WP6 context-dependent symbols) is not thrown away — it
is **archived** to `docs/legacy-render/`, clearly out of `lib/` so it cannot be
mistaken for live code. The kept parser and data model are **decoupled** from
render code entirely.

After this story the project compiles and all WP1 tests pass, with no
single-pass rendering code left under `lib/graphics/render/` except the
tree-walker seed (`draw_primitives.dart`).

## Background

`rewrite-plan.md`'s central insight is that much of `render/*` is *layout logic
embedded in draw calls*. That old logic still lives alongside the new WP1 IR,
which is confusing: it is unclear which code is live. This story resolves that
by removing the old render path.

The disposition of each file is enumerated in the WP2
[`README.md`](./README.md) ("What WP2 keeps, removes, and archives"). Three
coupling snags make this more than a bulk delete:

1. **`BarLineTypes` is misplaced.** The enum lives in
   `lib/graphics/render/staff.dart`, but the *kept* files
   `lib/musicXML/data.dart` and `lib/musicXML/parser.dart` both import it — a
   data-model concept trapped in the render layer. It must be **relocated into
   the data model** before `render/staff.dart` can be deleted.
2. **`notes.dart` is mostly reference data, not render code.** Its clef→glyph,
   accidental, and key-signature-accidental-position maps and tone conversions
   are **reference data** that WP1's `semantic/attributes.dart` already earmarks
   for the WP5 rules. It is **kept**; only the render-only helper
   `XPositionedMeasureContent` (a legacy measure-layout record) is removed.
3. **WP3 stubs import doomed render code.** `layout/layouting_context.dart`
   extends `MusicLineOptions` from `music_line.dart` and imports
   `render/common.dart`; `layout/layouter.dart` builds on it. These are
   broken-by-design skeletons for WP3, not part of the WP1 contract, and cannot
   survive the deletion. Remove them (WP3 will rebuild against the WP1 taxonomy).

## Scope

**In:**

- **Relocate `BarLineTypes`** out of `render/staff.dart` into the data model
  (`lib/musicXML/data.dart`, or a small neutral file it owns), and update
  `data.dart` / `parser.dart` imports so **no kept file imports any `render/`
  code**. `BarLineTypes` is the barline *style* vocabulary — a data-model
  concept — so the data model is its natural home. (The legacy *drawing* of
  barlines in `render/staff.dart` is archived, not moved.)
- **Delete** the pure-legacy render files (single-pass draw logic + ad-hoc
  geometry typedefs), per the README table:
  `music_line.dart`, `render/drawing_context.dart`, `render/glyph.dart`,
  `render/common.dart`, `render/staff.dart`, `graphics_model/measure.dart`,
  `graphics_model/__glyph.dart`, `graphics_model/__note.dart`.
- **Archive** the WP5/WP6 source-material files to `docs/legacy-render/`
  (preserving directory shape where it aids reading):
  `render/measure.dart` (the measure-grid / column derivation
  `createGridForMeasure`), `render/note/note.dart`, `render/note/pitch_note.dart`,
  `render/note/rest_note.dart`, `render/note/ledger.dart`, `render/beam.dart`.
  Add a short `docs/legacy-render/README.md` stating this is **old, unused,
  reference-only** code kept to inform WP5/WP6, not compiled or imported.
- **Trim `notes.dart`** to reference data: remove `XPositionedMeasureContent`
  (and any other purely render-layout helper) while keeping the reference maps
  and tone conversions the data model and future rules use.
- **Delete WP3-coupled stubs** `layout/layouting_context.dart` and
  `layout/layouter.dart` (they depend on deleted render code and are outside the
  WP1 contract). `layout/layout_definition.dart` (the empty `Selector`) and
  `layout/processing/load_layouting_rules.dart` (empty) are WP4 seeds with no
  legacy coupling — leave them untouched.
- **Delete the orphan golden** `test/goldens/main_demo.png` (no test references
  it; it is a main-branch leftover).
- **Stub `main.dart`** so the app still compiles and launches without the
  deleted `MusicLine` widget — a minimal placeholder (e.g. a blank
  `CustomPaint` or a "layout engine not wired yet" `Scaffold`). S4 replaces this
  with the S7-fixture renderer.

**Out:**

- Any change to the tree-walker's behaviour (`draw_primitives.dart`) — that is
  S2/S3. This story only *removes* code and *relocates* one enum; it does not
  add rendering capability.
- Introducing the render scaling measure (S2) or the `CustomPainter` (S4).
- Re-implementing any archived logic as WP5/WP6 rules (those are later WPs).

## Design notes

- **Deletion is safe because git preserves history.** The archived copies under
  `docs/legacy-render/` are a *reading convenience*, not a backup — the bar for
  archiving vs deleting is "will WP5/WP6 authors want to read this to port the
  logic?" (measure grid, note/beam/ledger geometry: yes; drawing-context
  plumbing and typedefs: no).
- **`docs/legacy-render/` must not compile or be imported.** It is documentation.
  Nothing under `lib/` or `test/` may import it. If a `.dart` extension causes
  tooling to analyze it, either keep it under `docs/` (outside the analyzed
  roots) or note it in `analysis_options.yaml` excludes — prefer the former.
- **`BarLineTypes` placement.** Put it where the data model already defines its
  musical vocabulary (`data.dart`). Keep the enum's identity and values
  unchanged so `parser.dart`'s existing mapping keeps working; this is a *move*,
  not a redesign.
- **Keep each commit compiling.** After the relocation + deletions + `main.dart`
  stub, `flutter analyze` is clean and the WP1 test suite passes. The
  `draw_primitives.dart` shim and its test remain green (they do not depend on
  any deleted file).
- **No behaviour is asserted here.** This is a structural cleanup story; its
  "tests" are that the existing WP1 suite still passes and the analyzer is
  clean, not new assertions.

## Acceptance criteria

- [x] `BarLineTypes` lives in the data model; **no** file under `lib/musicXML/`
      or the WP1 `graphics_model/` / `layout/` imports anything from
      `lib/graphics/render/`.
- [x] The pure-legacy render files listed above are deleted from `lib/`.
- [x] `render/measure.dart`, `render/note/*` and `render/beam.dart` are moved to
      `docs/legacy-render/` with a `README.md` marking them old/unused/reference-
      only; nothing in `lib/` or `test/` imports them.
- [x] `notes.dart` retains its reference data and drops the render-only
      `XPositionedMeasureContent` helper; the data model still compiles against
      it.
- [x] `layout/layouting_context.dart` and `layout/layouter.dart` are removed;
      the untouched WP4 seeds (`layout_definition.dart`,
      `processing/load_layouting_rules.dart`) still compile.
- [x] `test/goldens/main_demo.png` is deleted.
- [x] `main.dart` compiles and launches with a minimal placeholder (no reference
      to the deleted `MusicLine`).
- [x] `flutter analyze` is clean and the full WP1 test suite (S1–S7) plus the
      `draw_primitives` shim test pass.
