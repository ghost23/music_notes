# WP1 — Intermediate Layout Model (the IR contract)

This package defines the **intermediate representation (IR)** that sits between
the layout phase and the render phase: a scene graph of `Element`s carrying
positions, transforms, anchors and layout metadata, expressed **exclusively in
staff-space units**.

See the parent [`../rewrite-plan.md`](../rewrite-plan.md) for how WP1 fits the
overall rewrite, and [`../code-principle.md`](../code-principle.md) for the
coding/design principles every story must follow.

## Scope note: element taxonomy

The full SMUFL standard defines a huge number of glyph/element types. WP1 does
**not** model that catalogue. The semantic element types are limited to the
vocabulary our MusicXML parser already produces (`lib/musicXML/data.dart`):
clefs, key, time, notes/rests, accidentals, beams, stems, ledger lines,
barlines, ties/slurs, dynamics, directions. New element types are added later,
on demand, as layout rules need them.

## Stories

| ID | Title | Depends on |
|---|---|---|
| [S1](./S1-transform-model.md) | Staff-space transform model + geometry as free functions | — |
| [S2](./S2-scale-free-model.md) | Scale-free IR: pixel units out, scale-free styling in | S1 |
| [S3](./S3-element-taxonomy.md) | Semantic element taxonomy bounded to MusicXML vocabulary | S1 |
| [S4](./S4-named-anchors.md) | Named, transform-aware anchors | S1, S3 |
| [S5](./S5-deferred-references.md) | Cross-references & the unresolved state | S3, S4 |
| [S6](./S6-multi-staff-containers.md) | Multi-staff system container & vertical arrangement | S1, S3 |
| [S7](./S7-contract-validation.md) | Contract-validation fixture (multi-staff) | S1–S6 |

Suggested order: S1 → S2 → S3 → S4 → S5 → S6 → S7. S7 is the capstone that
proves the contract on a hand-built multi-staff example before any layout rules
exist. **All seven stories are complete** (S1–S7); the capstone fixture lives
in [`test/support/wp1_contract_fixture.dart`](../../test/support/wp1_contract_fixture.dart)
and its tests in [`test/graphics/wp1_contract_test.dart`](../../test/graphics/wp1_contract_test.dart).

## Definition of done for WP1 — ✓ satisfied

- ✓ A documented, unit-tested IR that can represent **one multi-staff line** of
  music as a pure-data scene graph in staff-space units.
- ✓ Geometry covered by tests using hand-built fixtures: *local* extents may be
  node getters; *absolute*/composed geometry, traversal and anchor resolution
  are free functions.
- ✓ No pixel values, pixel font sizing, or Flutter `Paint`/`TextStyle` anywhere
  in the model. Scale-free presentational styling (stroke/fill color,
  staff-space thickness; fill-vs-stroke intent derived from color presence) is
  permitted (see [S2](./S2-scale-free-model.md)); the renderer has no styling
  defaults.
- ✓ WP2 (render tree-walker) and WP3 (layout engine) can build against this
  contract without further IR changes for the first milestone (proven by S7,
  which consumes the contract as-is).
