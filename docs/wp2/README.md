# WP2 — Render phase as a pure tree-walker

This package turns the render phase into a **pure consumer** of the WP1 IR: it
walks the scene graph of `Element`s and draws them, doing **no** measurement,
positioning, or layout. Every position, transform, anchor and style it needs is
already on the tree (WP1); the renderer's only own contribution is converting
staff-space units to pixels via a single render scaling measure.

See the parent [`../rewrite-plan.md`](../rewrite-plan.md) for how WP2 fits the
overall rewrite (WP2 section + the "Coordinate system" and "Styling ownership"
resolved decisions), [`../code-principle.md`](../code-principle.md) for the
coding/design principles every story must follow, and
[`../wp1/README.md`](../wp1/README.md) for the IR contract WP2 consumes.

## Why this package

`rewrite-plan.md`'s central insight: much of the legacy `render/*` is layout
logic embedded in draw calls (note widths, accidental placement, ledger lines,
beam geometry, the measure grid). That single-pass coupling is exactly what the
rewrite removes. WP2:

- **removes the legacy single-pass renderer**, so the old layout-while-drawing
  code no longer co-exists with the new pipeline (a clean slate — S1);
- **proves the IR end-to-end**: the WP1 S7 contract fixture, rendered by the new
  tree-walker to a real canvas, is the demonstrator that the IR is drawable as-is
  (S4).

## Starting point

`lib/graphics/render/draw_primitives.dart` is already a near-complete
tree-walker shim (introduced in WP1-S2): it switches on the sealed `Element`
type, draws leaves (`PathElement`/`LineElement`/`RectElement`/`GlyphElement`),
recurses into containers (`GroupElement`/`CompositeElement`), and already
enforces the "no styling defaults" contract (it throws on a missing required
scale-free property). WP2 **grows this shim into the real renderer** rather than
starting over. Its current gaps — which the stories close — are:

- it applies only a node's **translation**, ignoring the `scale`/`rotation` the
  WP1 `NodeTransform` supports (S3);
- it carries a hard-coded `_defaultPixelsPerStaffSpace` placeholder instead of a
  real, threaded render scaling measure (S2);
- it does not yet enforce the WP1-S5 render boundary that an **unresolved** node
  (`isResolved == false`) must be refused, never drawn (S3).

## What WP2 keeps, removes, and archives

| Bucket | Files | Disposition |
|---|---|---|
| **WP2 seed — keep & grow** | `render/draw_primitives.dart` (+ its test) | Becomes the WP2 renderer. |
| **Kept, but decoupled from render** | `musicXML/data.dart`, `musicXML/parser.dart` | Keep; sever their dependency on `render/staff.dart` by relocating `BarLineTypes` into the data model (S1). |
| **Kept reference data** | `graphics/notes.dart` | Reference maps consulted by WP5 rules (see WP1 `semantic/attributes.dart`). Keep; drop only the legacy render helper `XPositionedMeasureContent`. |
| **Pure legacy render — delete** | `music_line.dart`, `render/drawing_context.dart`, `render/glyph.dart`, `render/common.dart`, `render/staff.dart`, `graphics_model/measure.dart`, `graphics_model/__glyph.dart`, `graphics_model/__note.dart` | Single-pass draw logic + ad-hoc geometry typedefs. Git history preserves them. |
| **Legacy render = WP5/WP6 source material — archive** | `render/measure.dart` (measure-grid derivation), `render/note/*` (note/pitch/rest/ledger geometry), `render/beam.dart` | `rewrite-plan.md` names these as "source logic to migrate into WP5/WP6 rules." Moved to `docs/legacy-render/` — out of `lib/` so they cannot be mistaken for live code, but preserved for reference when those rules are written (S1). |
| **WP3 scaffolding coupled to legacy** | `layout/layouting_context.dart` (imports the doomed `music_line.dart`) and `layout/layouter.dart` | Broken-by-design stubs; delete (WP3 rebuilds against the WP1 taxonomy). See S1. |
| **Orphan** | `test/goldens/main_demo.png` | Leftover from the main-branch renderer; no test references it. Delete (S1). |

## Coordinate system & styling (recap of the resolved decisions)

WP2 is bound by the two resolved decisions in `rewrite-plan.md`:

- **Coordinate system.** The IR is entirely in **staff-space units** and stores
  no pixel values. The renderer is handed **one** concrete scaling measure and
  converts staff-space → pixels at draw time. Zoom/resize changes only this
  measure; it never re-runs layout. This is the renderer's *only* own numeric
  contribution (S2).
- **Styling ownership.** The layout phase is the **sole source of styling**. The
  renderer has **no defaults**: it draws exactly what the IR carries and
  **throws** if a required scale-free property is missing. Fill-vs-stroke intent
  is derived from color presence (`Styling.hasStroke`/`hasFill`), never a
  separate enum (S3).

Plus the WP1-S5 render boundary: an **unresolved** node has only tentative
geometry and must be **refused** by the renderer, so unresolved geometry never
reaches the canvas (S3).

## Stories

| ID | Title | Depends on |
|---|---|---|
| [S1](./S1-legacy-render-cleanup.md) | Legacy render cleanup (clean slate) | — |
| [S2](./S2-render-scaling-measure.md) | Single render scaling measure (staff-space → pixels) | S1 |
| [S3](./S3-tree-walker.md) | Pure tree-walker: full transform, styling, unresolved refusal | S1, S2 |
| [S4](./S4-entry-point-and-e2e.md) | `CustomPaint` entry point + end-to-end proof on the S7 fixture | S1–S3 |
| [S5](./S5-visual-regression-harness.md) | Visual-regression (golden) harness | S4 |

Suggested order: S1 → S2 → S3 → S4 → S5. S1 is done first, as the clean slate
the rest builds on; S4 renders the WP1 S7 contract fixture end-to-end; S5 locks
that output behind a golden so later WPs cannot silently regress it.

### Note on the merged WP8

The original plan had a separate **WP8 — Integration & visual validation**
("stand up early, run throughout"). Its two halves are separable, so WP8 is
dissolved: the **visual-regression (golden) harness** — the part that must stand
up early — is **S5 here**, planted the moment there is renderable output; the
**full widget/app integration** (responsive sizing, zoom, scroll, multiple
systems) needs real parsed scores (WP3) and multi-system content, and folds into
the **WP7** era. WP2-S4's minimal `CustomPainter` is the only widget surface
needed until then. "Run throughout" is preserved: every later WP adds its own
goldens using the S5 harness — nothing new is built, only reference images
added.

## Definition of done for WP2

- A render phase that is a **pure tree-walker**: it consumes the WP1 IR and only
  translates/scales/rotates/draws — no measurement, positioning, grid or spacing
  logic anywhere in `render/*`.
- The legacy single-pass renderer is **gone** from `lib/`; its WP5/WP6 source
  material is preserved under `docs/legacy-render/`; the kept parser/data model
  no longer depends on any render code.
- The renderer applies each node's **full** `NodeTransform` (translation, scale,
  rotation), converts staff-space → pixels through **one** documented scaling
  measure, sources all presentation from `Styling` with **no defaults**, and
  **refuses** unresolved nodes at the render boundary.
- The WP1 **S7 contract fixture renders end-to-end** through the new renderer to
  a real canvas, proving the IR is drawable as-is (an automated render test).
- A reusable **visual-regression (golden) harness** is stood up, with a first
  committed golden of the rendered S7 fixture, so later WPs cannot silently
  regress render output.

## Out of scope (deferred)

- **The layout engine.** Turning a real `Score` into an IR tree is WP3 (driver)
  + WP5/WP6 (rules). WP2 renders **hand-built** IR (the S7 fixture); `main.dart`
  therefore displays the fixture, not a parsed score, until WP3 lands.
- **Full widget/app integration.** WP2 ships a *minimal* `CustomPainter` (S4)
  and the golden harness (S5). The rich widget layer — responsive sizing, zoom,
  scroll, multiple systems — needs real parsed scores (WP3) and multi-system
  content, and folds into the **WP7** era (see "Note on the merged WP8" above).
- **Real engraving correctness.** The fixture is a contract demonstrator, not an
  engraved score (clefs at the staff origin, straight-line slur, fixed stems —
  as documented in WP1-S7).
