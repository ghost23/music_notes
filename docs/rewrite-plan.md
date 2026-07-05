# Rewrite Plan: Layout / Render Separation

This is the living plan for the layout-engine rewrite described in
[`architecture.md`](./architecture.md). It decomposes the work into major
packages and records the key decisions made so far.

## Goal (recap)

Split the current single-pass renderer into two phases:

1. **Layout phase** — a *multi-pass* process that computes positions, scales,
   rotations and other layout properties for every symbol, producing an
   intermediate data structure (a scene graph of `Element`s).
2. **Render phase** — a pure consumer of that structure that walks the tree and
   draws to the canvas.

Layout rules should be **modular and composable**, CSS-inspired: isolated units
that can be added one at a time and combined to build complex layouts.

We **keep**: the MusicXML parser (`lib/musicXML/parser.dart`), the data model
(`lib/musicXML/data.dart`), and the generated SMUFL glyph data
(`lib/graphics/generated/*`).

## First milestone (agreed)

**One line of music, multi-staff from the start.**

A single rendered system containing more than one staff (e.g. piano grand staff),
laid out correctly via the new layout→render pipeline. Multi-staff is in scope
for the first slice — not deferred — so the IR and layout engine are designed for
vertical staff spacing from day one. Line breaking, multiple systems and page
layout remain later (WP7).

## Current state of the codebase

The refactor branch already contains partial scaffolding. Summary:

| Area | State | Notes |
|---|---|---|
| MusicXML parser + data model | Keep as-is | Full sealed hierarchy; beams/slurs/ties/dynamics parsed |
| Generated SMUFL data | Keep as-is | glyphs, bboxes, anchors, advance widths, engraving defaults |
| Graphics model (`Element` AST) | Exists, underpowered | Layout↔render boundary, but no transform/scale/rotation fields yet |
| Render phase (`render/*`) | ~80% but mis-layered | Works, but computes layout *while drawing* |
| Layout phase (`layout/*`) | Skeleton only | Context + orchestration stubs; grid columns created empty |
| Rule system (CSS-like) | Not started | `layout_definition.dart` = empty `Selector`; `load_layouting_rules.dart` empty |

**Central insight:** much of `render/*` (note widths, accidental placement,
ledger lines, beam geometry, measure grid) is layout logic embedded in draw
calls. The rewrite is largely about *moving that logic into a layout pass that
emits the `Element` tree*, leaving render as a dumb tree-walker.

## Major work packages

### WP1 — Intermediate Layout Model (the Intermediate Representation, "IR", contract)
Promote the `Element` AST into a real scene graph: explicit transform
(position / scale / rotation) per node, parent/child links, named anchors, and a
way to hold *unresolved* references (e.g. a beam that knows its notes but not
their final Y). Must support multi-staff vertical arrangement.
**Foundational — blocks everything else.**
Broken into developer stories in [`wp1/`](./wp1/README.md).

### WP2 — Render phase as pure tree-walker
Strip all measurement/positioning out of `render/*`; the renderer consumes WP1's
tree and only translates/draws. `draw_primitives.dart` is already close. Proves
the IR end-to-end and removes the legacy single-pass coupling.

### WP3 — Layout engine core (multi-pass driver)
The pass scheduler: build the layout tree from the data model, run passes until
stable, expose the tree to rules. The spine for "setting one symbol affects
another we already touched."

**Note — absolute-transform/anchor index (cross-tree references).** IR nodes
carry no parent link (by design; see WP1-S1/S5). Deferred elements (slurs,
beams, ties) hold references to distant nodes by identity, but need those
targets' **absolute** (composed) positions to resolve. The pass driver supplies
this via a `node → absolute geometry` index (e.g. `Map<Element, Matrix4>` and/or
resolved anchor points), produced by a single **top-down** walk that threads
each parent's absolute transform down — never by walking up or storing absolute
values on nodes. Key properties:

- **Pass-local derived data, not IR state.** The index belongs to WP3, not the
  WP1 element model. It is rebuilt from the current tree, not persisted on nodes.
- **Rebuilt after mutating passes.** Absolute positions are a pure function of
  current transforms, so any pass that mutates a transform invalidates the
  affected subtree. The simple, correct default is to rebuild the index (O(n))
  after each mutating pass and before resolvers read it. Rebuilding fresh means
  it can never be stale — this is *why* we prefer it over cached absolute
  transforms or parent pointers, which would demand careful invalidation.
- **Optimise only if measured.** Skipping rebuilds after read-only passes, or
  dirty-tracking single subtrees, are later optimisations that reintroduce
  invalidation complexity — resist until profiling justifies it.

### WP4 — Modular rule system (CSS-inspired)
The novel design piece: selectors (what element/context a rule targets),
rules/properties, and a cascade/combination engine so rules compose in
isolation. **Design deferred** — kept at altitude for now; to be specified
before implementation (selector model, property resolution order, conflict
handling).

### WP5 — Element layout rules (intra-measure)
Port existing logic into WP4 rules: note vertical position, accidentals,
clefs/key/time signatures, ledger lines, rests, intra-measure horizontal
spacing. Mostly migration of code already present in `render/note/*` and
`render/measure.dart`.

### WP6 — Context-dependent / cross-element symbols
The actual motivation for the rewrite: beams, slurs/legato, ties, dynamics,
hairpins/wedges — created early with anchor references, resolved in a later pass
once notes are placed.

### WP7 — System / line / page layout
Cross-measure spacing, line breaking, multi-system vertical spacing, page layout.
(Note: multi-*staff* within a single system is in scope from WP1; this package is
about multiple *systems* and pages.)

### WP8 — Integration & visual validation
Widget / `CustomPaint` rewiring and a visual-regression harness (golden images),
so layout-rule refinements don't silently break earlier results. Stand up early.

## Suggested sequencing

```
WP1  →  WP2  →  WP3  →  WP4  →  WP5  →  WP6
                                            
WP8 (stand up early, run throughout)        WP7 (last)
```

WP1 → WP2 first to prove the IR on a trivial example, then the engine (WP3),
the rule system (WP4), intra-measure rules (WP5), and finally the
context-dependent symbols (WP6) that justify the whole effort.

## Resolved design decisions

- **Coordinate system**: The layout engine works **exclusively in staff-space
  units** (the SMUFL native unit, where 1 em = 1 staff height = 4 staff spaces).
  All layout output — positions, widths, anchors — is unitless / scale-free. The
  **renderer** is handed a single concrete scaling measure (e.g. a font size for
  the SMUFL font) and converts staff-space → pixels at draw time. Consequences:
  scaling is a render-phase concern only; the IR (WP1) stores no pixel values;
  zoom/resize never re-runs layout.
- **Styling ownership**: The layout phase is the **sole source of styling**
  (color, fill-vs-stroke intent, staff-space thickness). The renderer has **no
  styling defaults**: it draws exactly what the IR carries and **throws** if a
  required scale-free property is missing. "Unset / inherit" on an IR node means
  *unresolved* — to be resolved during layout (cascade from the parent, or a
  default style defined in the IR element definition), never a renderer default.
  Fill-vs-stroke intent is **derived from color presence**
  (`Styling.hasStroke` / `Styling.hasFill`), not carried as a separate enum.
  Default styles, when wanted, are defined in the element definitions (later
  WPs) as layout-time defaults. The renderer's only own contribution is the
  scale-dependent pixel conversion (staff-space → pixel font size / pixel
  stroke width) from the single render scaling measure.

## Open design questions (to resolve later)

- **WP4 rule system**: selector grammar, property model, cascade/conflict
  resolution, how rules are registered (`load_layouting_rules.dart`).
- **Multi-staff vertical spacing**: fixed vs content-driven; brace/bracket
  grouping.
- **Pass convergence**: how the multi-pass driver decides it has stabilised.

## What to salvage from existing scaffolding

- `graphics_model/canvas_primitives.dart` — basis for WP1's IR.
- `render/draw_primitives.dart`, `render/glyph.dart` — basis for WP2.
- `render/note/*`, `render/measure.dart`, `render/beam.dart`, `render/ledger.dart`
  — source logic to migrate into WP5/WP6 rules.
- `layout/layouter.dart`, `layout/layouting_context.dart` — starting point for WP3.

## Code and design principles

We adhere to the coding and design principles specified here: [code-principle.md](Code and Design prindicples)