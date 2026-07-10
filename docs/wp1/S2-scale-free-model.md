# WP1-S2 — Scale-free IR: pixel units out, scale-free styling in

## Goal

Make the layout model **scale-free and decoupled from Flutter's paint model**,
*without* making it style-blind. Two different things get conflated under the
word "styling", and this story separates them:

- **Pixel-bearing / scale-dependent render data** (pixel font sizes, pixel
  stroke widths, Flutter's `Paint`/`TextStyle`) — **does not belong** in the IR.
  It depends on the render scaling measure and couples layout to Flutter.
- **Scale-free presentational styling** (stroke/fill **color**, fill-vs-stroke
  **intent**) — **does belong** in the IR. It carries no pixel units, does not
  depend on the scaling measure, and is a genuine layout-time decision
  (e.g. an editorially red note, a greyed-out cue, a highlighted symbol).

The dividing line is **scale-dependence and Flutter-paint coupling, not styling
in general.** The IR describes *what*, *where* (staff-space), and *which
scale-free presentational properties* an element carries; the renderer decides
everything that needs the scaling measure (concrete font size, pixel stroke
width) and turns IR intent into Flutter `Paint`/`TextStyle`.

## Background

`canvas_primitives.dart` currently stores a `Paint` on every `Element` and a
`TextStyle` on `GlyphElement`:

- `Paint` → bundles **color** (scale-free, keep) together with **stroke width /
  style** (pixel-scale, drop) and other Flutter-paint machinery;
- `TextStyle` → font family and **font size in pixels** (both render concerns;
  a glyph's size derives from staff-space × the scaling measure at render time).

So `Paint` is not wholly wrong — it mixes one property we want to keep (color)
with several we must remove. This story unbundles it: extract the scale-free
intent into the IR, and leave the pixel-scale parts to the renderer.

This aligns with the resolved coordinate decision (the IR stores no pixel
values; scaling is a render-phase concern) while preserving color as
first-class, scale-free layout data.

## Resolved decisions (refined during implementation)

Two points were left open in the original scope and are now pinned:

1. **No separate fill-vs-stroke intent type.** Intent is *derived from color
   presence*: a set `strokeColor` means stroke, a set `fillColor` means fill,
   both means stroke+fill, neither means unresolved. A separate
   `PaintIntent` enum would be redundant with the nullable colors and would
   open a state space ("intent set but no color") that has no consumer yet.
   `Styling.hasStroke` / `Styling.hasFill` expose the derived intent.

2. **The renderer has no styling defaults.** Styling is resolved entirely
   during layout; the renderer draws exactly what it is given and **throws** if
   a required scale-free property is missing (no color, or a stroke without a
   staff-space thickness). "Unset / inherit" therefore does **not** mean "fall
   back to a renderer default" — it means *unresolved*, and the layout must
   resolve it before the renderer sees it: by inheriting from the parent in the
   scene-graph cascade, or by applying a **default style defined in the IR
   element definition**. Such default styles are layout-time defaults defined
   in the element definitions (introduced in later work packages), never
   render-time defaults. The renderer remains a dumb consumer whose only
   own contribution is the *scale-dependent pixel conversion* from the single
   render scaling measure (staff-space → pixel font size / pixel stroke width).

## Scope

**In:**
- Remove `Paint` from `Element` and `TextStyle` from `GlyphElement`.
- Retain scale-free presentational styling on the IR, kept minimal and
  unit-free:
  - **Color** for stroke and/or fill, using Flutter's `Color`. It is a plain
    ARGB value type with no pixel units, so reusing it ("reuse first") keeps the
    IR scale-free; we deliberately do **not** introduce a custom color type. The
    only constraint is that no `Paint` is constructed in the model — the IR holds
    the bare `Color`, the renderer builds the `Paint`. A `null` color means
    *unresolved* (the layout must resolve it, see decision 2 above); it is
    **not** a renderer default.
  - **Fill-vs-stroke intent is derived from color presence** — there is no
    separate intent enum/record. `Styling.hasStroke` / `Styling.hasFill` read
    the derived intent.
- Express any genuine **thickness / length** that is intrinsic to engraving
  (stem thickness, beam thickness, staff-line thickness) in **staff spaces**,
  sourced from `EngravingDefaults` — never in pixels.
- Define where pixel-scale render styling now lives: the renderer (WP2) maps
  the resolved scale-free color + staff-space thickness + the single scaling
  measure → concrete `Paint`/`TextStyle`. The renderer supplies only the
  scale-dependent pixel conversion; it supplies **no** styling defaults.

**Out:**
- Implementing the renderer mapping (that is WP2; this story only removes the
  pixel-bearing fields, retains the scale-free ones, and documents the boundary).
- Glyph sizing math (the glyph's size derives from staff-space + the render
  scaling measure, computed at render time).
- A full theming / cascade model for color. Only the per-element scale-free
  color + staff-space thickness are in scope; rule-driven color assignment and
  the element-definition default styles are later WPs.

## Design notes

- The glyph node references the SMUFL `Glyph` (semantic identity), its
  staff-space placement, and any scale-free presentational properties (e.g.
  color). Font family and pixel size are supplied at render time.
- Keep the styling surface deliberately small: color + staff-space thickness,
  with intent derived from color presence. Resist re-introducing pixel- or
  Flutter-specific fields, or a separate intent type, under a different name.
- Keep model types pure data; no `Paint`/`TextStyle` construction inside the
  model.
- "Unset → inherit" means *unresolved*, to be resolved during layout (cascade
  from parent, or a default style from the element definition). It is **not** a
  renderer default — the renderer throws on unresolved styling. This keeps the
  renderer a dumb consumer and makes styling ownership unambiguous.

## Acceptance criteria

- [x] No `Element` subclass references `Paint`, `TextStyle`, or any **pixel**
      font size or **pixel** stroke width.
- [x] Scale-free presentational styling is **retained**: an element can carry a
      stroke and/or fill **color** and a staff-space stroke **thickness**;
      fill-vs-stroke intent is **derived from color presence**
      (`Styling.hasStroke` / `Styling.hasFill`). A `null` color means
      *unresolved* (the layout must resolve it), **not** a renderer default.
- [x] `GlyphElement` carries the SMUFL glyph identity, its staff-space
      transform/placement, and its scale-free presentational properties (e.g.
      color) — but no `TextStyle` and no pixel font size.
- [x] Any retained stroke/thickness values are documented as staff-space units
      and (where applicable) sourced from `EngravingDefaults`.
- [x] A short doc note records the boundary: scale-free styling (color,
      staff-space thickness) lives in the IR and is resolved during layout; the
      renderer has **no styling defaults** and throws on unresolved styling — it
      only turns the resolved color/thickness + the scaling measure into concrete
      `Paint`/`TextStyle`.
- [x] Project compiles; a temporary render-side shim may supply the
      scale-dependent pixel conversion (font size, stroke width) from a scaling
      measure until WP2, but supplies **no** styling defaults.
- [x] A test (or assertion/grep in review) confirms the model layer has no
      dependency on `Paint`/`TextStyle` and no pixel-bearing values — while the
      color/thickness fields and derived-intent helpers are present. A test
      pins the no-defaults renderer contract (throws on missing styling).
