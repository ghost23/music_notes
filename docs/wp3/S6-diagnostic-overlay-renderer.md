# WP3-S6 — Generic diagnostic overlay renderer

## Goal

Build a **semantically-agnostic** visual overlay: a second sink that consumes the
S5 record schema and draws element **bounding boxes** (flagged ones highlighted,
with the residual labelled) and, from the opaque payload hook, **color-coded
stacked measurement bars with a legend** (a VexFlow-style per-column width
breakdown). The renderer never understands the categories semantically — it draws
colored segments, legends, text, and boxes from `(categories, measurements,
positions, labels)`. Because it depends only on the schema, it is built and
**tested now against synthetic/hand-authored records**, independent of any real
rule.

See the [WP3 design reference](./README.md) — "What WP3 emits and ships" (the
overlay bullet) and "Building the overlay now (rather than deferring it)".

## Background

Building the overlay **now** is deliberate: it **hardens the schema** by forcing
a real consumer against it, and gives a **complete verification toolset** before
the rules arrive. It is the visual counterpart to S5's file sink — the "multiple
sinks" half of "one structured source of truth, multiple sinks".

Because it consumes only the S5 schema (not the driver, not real rules), this
story can proceed **in parallel** with S4/S5 the moment the record schema is
pinned, and its tests need no engine run.

## Scope

**In:**

- **Consume the S5 record schema** and render **bounding boxes**: draw each
  record's box, **highlight** the flagged ones, and **label** the residual — a
  *diagnostic-aware* overlay, not decorative.
- **Render color-coded stacked measurement bars + legend** from the payload hook
  (e.g. red = modifiers, green = note+flag), with the **anchor marked** and a
  **total label**, in the spirit of VexFlow's per-column width breakdown.
- **Stay generic.** The renderer draws only colored segments, a legend, text, and
  boxes from `(categories, measurements, positions, labels)`; it has **no**
  category-specific logic.
- **Reuse the WP2 drawing surface.** Prefer the existing WP2 tree-walker /
  `CustomPainter` plumbing for the actual drawing (per the reuse principle); the
  overlay is a diagnostic layer, not a music renderer.
- **Test against synthetic records** — hand-authored `(categories, measurements,
  positions, labels)` and flagged boxes — via a recording canvas and/or a golden
  (reusing the WP2-S5 harness). No real rule is involved.

**Out:**

- **Semantic interpretation** of categories — by design, never; the renderer is
  generic.
- The **rule-contributed** real payload content (WP5/WP6). Minor extensions to
  the renderer as real categories surface are expected and fine.
- The record **schema**, driver **emission**, and **file sink** (S5).

## Design notes

- **Schema-only dependency → parallelizable and self-testing.** The overlay's one
  input is the S5 record; that is what lets it be built and golden-tested now,
  against synthetic data, before any engine or rule exists.
- **A real consumer hardens the schema.** Forcing the overlay to draw every field
  (bbox, residual, the four payload arrays) surfaces schema gaps early — the
  point of building it now rather than deferring.
- **Reuse, don't reinvent.** Draw through the existing WP2 `CustomPainter` /
  primitives and the WP2-S5 golden harness rather than a bespoke image system
  (check for the existing solution first — `../code-principle.md`).
- **Agnostic by construction.** Keep the drawing driven purely off the four
  payload arrays + boxes so a new category needs no renderer change beyond, at
  most, more colors/legend entries.

## Acceptance criteria

- [ ] The overlay draws **bounding boxes** from records, **highlights** flagged
      ones, and **labels** their residuals.
- [ ] The overlay draws **color-coded stacked measurement bars with a legend**
      from the payload hook, with the anchor marked and a total labelled.
- [ ] The renderer is **semantically agnostic** — no category-specific branching;
      it drives purely off `(categories, measurements, positions, labels)` + boxes.
- [ ] It is **tested against synthetic, hand-authored records** (recording canvas
      and/or golden via the WP2-S5 harness), with **no** real rule involved.
