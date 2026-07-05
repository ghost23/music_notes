# WP1-S3 — Semantic element taxonomy bounded to MusicXML vocabulary

## Goal

Define the set of **semantic IR node types** that the layout model can contain,
and bound that set to the vocabulary our MusicXML parser already produces — not
the full SMUFL catalogue. Establish how each MusicXML data concept maps to an IR
node built from the primitive elements.

## Background

The IR has two layers:

1. **Primitive elements** — `PathElement`, `LineElement`, `RectElement`,
   `GlyphElement` (the drawable leaves) plus `GroupElement` (an open child
   collection); from `canvas_primitives.dart`.
2. **Semantic elements** — meaningful musical nodes (a note, a clef, a measure)
   that *compose* primitives and carry layout intent.

`MeasureElement`/`MeasureGrid` already hint at layer 2. This story defines layer
2 deliberately and minimally. Per the project note: **only model element types
we already know from the MusicXML parser** (`lib/musicXML/data.dart`). The SMUFL
standard's wider element set is out of scope until a rule needs it.

### Two shapes of composing node: collection vs. composite

A node that composes children is **one of two shapes**, and the distinction is
load-bearing (it is why the model separates `GroupElement` from
`CompositeElement`):

- **Collection** (`GroupElement` / a typed container subclass) — its
  `elements` are an *open*, mutable list whose length is **data-driven** and
  which have **no distinct named roles**: the parts of a system, the measures
  of a staff, the columns of a measure, the accidentals of a key signature, the
  style leaves of a barline. A list is genuinely the right model.
- **Composite** (`CompositeElement`) — a **fixed set of named roles**: a time
  signature's `beats`/`beatType`; a note's `notehead`/`stem`/`flag`/… . The
  roles are typed named fields, so they are never anonymous and the arity is
  **codified** — a `TimeSignatureElement` *cannot* be constructed with one
  numeral or five. Its `elements` are a **read-only list derived from the
  roles** (there is no open list to append anonymous children to), so the
  generic tree-walk still sees a plain ordered list.

The single traversal contract every node satisfies is `Element.elements` — the
ordered child list the walk (bbox folding, rendering, the WP3 transform index)
consumes. Leaves return `const []`; a collection exposes its mutable list; a
composite derives it from its named roles. `CompositeElement` extends `Element`
directly (not `GroupElement`): the only thing it needs is that `elements`
contract, which it implements from its roles.

## Scope

**In:**
- A documented taxonomy of semantic node types, each mapped to its MusicXML
  source type. Initial set (mirroring `data.dart`):
  - structural (collections): system/part container, **staff**, measure,
    column;
  - attributes: clef *(composite)*, key signature *(collection of
    accidentals)*, time signature *(composite)*;
  - events: pitched note *(composite)*, rest *(composite)*, beam *(collection
    placeholder — S5/WP6)*;
  - separators: barline *(collection — style-dependent leaves)*;
  - context-dependent (placeholders only here; resolved in S5/WP6): tie, slur,
    dynamic, direction (wedge/words/octave-shift).
- A note's **parts** — stem, flag, accidental, augmentation dots, ledger lines
  — are **not** separate semantic types. They are modelled as **primitive
  roles** of `PitchedNoteElement` (`LineElement` for stem/ledger lines,
  `GlyphElement` for flag/accidental/dots). We start lean and promote a part to
  its own type only if a rule later needs one.
- For each semantic type: whether it is a collection or a composite, which
  primitive(s) / roles it composes, and which layout fields it needs (kept
  minimal for the first milestone).
- A naming/organisation convention for semantic vs. primitive types (e.g. file
  layout under `graphics_model/`).

**Out:**
- The multi-staff container *vertical-arrangement* behaviour (S6 fleshes it out;
  here we only declare the staff/system node exists).
- Deferred-reference mechanics for ties/slurs/dynamics (S5).
- Any SMUFL element type with no MusicXML counterpart.

## Design notes

- Semantic nodes are primarily data that reference/compose primitives. Derived
  data computed purely from a node's own fields may be a getter/method; *building*
  a note's glyph children (which needs external glyph metadata / layout rules) is
  done by free functions in WP5, not in the node.
- Favour composition over deep inheritance. **Pick the shape by the data**: a
  fixed set of distinct parts → a `CompositeElement` with typed named roles
  (illegal arity is then unrepresentable); a data-driven list with no distinct
  roles → a `GroupElement` (or a typed container that restricts child type).
  Do *not* model a fixed composite as a bare `GroupElement` — that loses which
  child is which and lets an invalid count type-check (the failure mode this
  story's design pass corrected).
- A role field is nullable when the part is optional (`stem`, `flag`,
  `accidental`) and non-nullable when required (`notehead`, a time signature's
  `beats`/`beatType`); a variable count of one kind is a `List` role (`dots`,
  `ledgerLines`).
- Keep fields to what the first multi-staff line needs; mark anything
  speculative as out of scope to avoid premature SMUFL breadth.
- Each semantic type should trace back to a concrete `data.dart` type in a doc
  table, so coverage is auditable.

## Glyph-knowledge contract

Semantic and primitive elements need knowledge about the glyphs they represent
(geometry for layout, which glyph a musical concept maps to). This knowledge is
**referenced, never copied onto nodes**. State this once, here, as the governing
rule for the whole IR:

> Elements reference glyphs by **identity** (the `Glyph` enum key). Per-glyph
> metadata is **derived on demand** via free functions that take the metadata
> table as a parameter (the S4 testability rule) — never duplicated as node
> fields. The musical-concept → `Glyph` mapping is **reference data** consulted
> when *building* the tree (WP5), not stored on nodes. Global engraving defaults
> and per-glyph advance widths are **layout inputs/hints**, not authoritative
> values: the owning layout rule makes the final decision.

There are four distinct kinds of "glyph knowledge"; each has one home:

| Kind | Example | Home |
|---|---|---|
| Glyph **identity** | `Glyph.noteheadBlack` | stored on `GlyphElement` (the only glyph fact a node holds) |
| Per-glyph **geometry** | bbox, anchors, advance width | generated maps (`glyph_bboxes`, `glyph_anchors`, `glyph_advance_widths`), read via parameterised free functions — never copied |
| Concept→glyph **mapping** | `NoteLength.quarter → noteheadBlack` | reference tables (already in `lib/graphics/notes.dart`), used by WP5 builders |
| Global **engraving defaults** | stem/beam thickness, ledger extension | not per-glyph; resolved into `Styling` by WP5 rules, not stored raw on nodes |

Consequences for this story:

- Semantic nodes **compose** primitive leaves (as a collection or a composite —
  see above); they are *not* subclasses of `GlyphElement`. A concept is not
  one-to-one with a glyph (a clef ≈ one glyph; a note ≈ notehead + stem + flag +
  dots). Glyph identity therefore lives at the leaves; the semantic node only
  knows *which* leaves (its roles) and *how they attach* (anchors, S4).
- **Advance width** is per-glyph geometry that WP5 horizontal spacing will need.
  It is now surfaced **in WP1** as a parameterised free function
  (`glyphAdvanceWidth` in `layout/glyph_metadata.dart`, reading
  `glyph_advance_widths`), so no copy of the data can sneak onto a node. It is
  **not** the sole determinant of spacing — a layout rule may widen or tighten
  the gap for a good layout, so advance width is an *input/hint* the spacing
  rule consumes, not the spacing itself.

## Acceptance criteria

- [x] A documented taxonomy table maps every initial semantic node type to its
      MusicXML `data.dart` source type and the primitive(s) it composes.
- [x] The taxonomy contains **no** element type lacking a MusicXML counterpart.
- [x] Semantic node types are declared as data types (fields + copy, plus
      pure-derived getters where useful), consistent with S1/S2; no
      construction/layout logic that needs external metadata or the rest of the
      tree lives in them.
- [x] Fixed-arity composites (clef, time signature, note, rest) are modelled as
      `CompositeElement`s with typed **named roles** (not anonymous
      `GroupElement` children), so an invalid arity cannot be constructed;
      genuine collections stay `GroupElement`s. The single traversal accessor
      `Element.elements` is satisfied by leaves, collections and composites
      alike (composites derive it from their roles; they extend `Element`, not
      `GroupElement`).
- [x] Structural nodes for system/part, staff, measure and column exist (staff
      present so S6 can build on it).
- [x] Context-dependent types (tie, slur, dynamic, direction) are declared as
      placeholders and explicitly cross-referenced to S5.
- [x] The glyph-knowledge contract is documented: nodes hold glyph **identity**
      only; per-glyph metadata is read via parameterised free functions, never
      copied; the concept→glyph mapping and engraving defaults have named homes.
- [x] Advance width is explicitly scoped (surfaced in WP1 alongside the other
      per-glyph metadata readers), noted as a spacing *input* a layout rule may
      override, not the final gap.
- [x] Project compiles; the taxonomy doc is checked into `docs/wp1/`.

## Implementation

The taxonomy lives under
[`lib/graphics/graphics_model/semantic/`](../../lib/graphics/graphics_model/semantic/),
organised by category (one file per category, plus a `semantic.dart` barrel
that re-exports them and states the glyph-knowledge contract once for the whole
IR). The primitive layer stays in `canvas_primitives.dart` — semantic nodes
*compose* primitive leaves, either as a **collection** (`GroupElement` / a typed
container) or as a **composite** (`CompositeElement`, a fixed set of typed named
roles); they are **not** subclasses of `GlyphElement`. The single traversal
accessor `Element.elements` unifies the walk over leaves, collections and
composites (`CompositeElement` extends `Element` directly and implements
`elements` from its roles). The previous `MeasureElement`/`MeasureGrid`
scaffolding in `graphics_model/measure.dart` has been folded into this taxonomy
(`MeasureElement` + `ColumnElement`); `measure.dart` now keeps only the legacy
render-layer geometry typedefs until WP2 retires them.

Each semantic type is pure data: it composes primitive leaves and carries only
the minimal layout-relevant identity/structure the first multi-staff line
needs. Per the design note "the semantic node only knows *which* leaves and
*how they attach*", the nodes do **not** store musical-concept values (pitch,
length, clef sign, dot count, stem direction) — those are consumed by the WP5
builder to choose and place the leaves, and are afterwards encoded by the
leaves / tree position. Most event/attribute types therefore carry **no** extra
fields for now; the *type itself* is the contribution (it gives WP4 selectors a
target and S5 references something to attach to). Fields are added by the
WP5/WP6 rule that needs them.

### Taxonomy table

Shape is **collection** (`GroupElement` / typed container — open, data-driven
child list) or **composite** (`CompositeElement` — fixed typed named roles).

| Semantic type | MusicXML `data.dart` source | Shape | Roles / primitive(s) composed | Layout fields (first milestone) |
|---|---|---|---|---|
| **Structural** (`structural.dart`) | | | | |
| `SystemElement` | `Score` (one system per score for the first milestone) | collection (typed) | `PartElement` children | none (S6 adds vertical arrangement) |
| `PartElement` | `Part` | collection (typed) | `StaffElement` children | none |
| `StaffElement` | `Attributes.staves` + `Note.staff` / `Clef.staffNumber` | collection (typed) | `MeasureElement` children | `staffNumber` (1-based) |
| `MeasureElement` | `Measure` | collection (typed) | optional attributes `GroupElement` + `ColumnElement`s | `columns`, `attributes` |
| `ColumnElement` | derived: `MeasureContent` sharing a division offset (cumulative `duration` / `Backup` / `Forward` vs `Attributes.divisions`) | collection | simultaneous event elements | none (division offset is a WP5 input) |
| **Attributes** (`attributes.dart`) | | | | |
| `ClefElement` | `Clef` | **composite** | `glyph` — clef `GlyphElement` (sign = leaf identity) | none |
| `KeySignatureElement` | `MusicalKey` (via `Attributes.key`) | collection | accidental `GlyphElement`s (count from `fifths`) | none |
| `TimeSignatureElement` | `Time` (via `Attributes.time`) | **composite** | `beats`, `beatType` — two numeral `GlyphElement`s | none |
| **Events** (`events.dart`) | | | | |
| `PitchedNoteElement` | `PitchNote` | **composite** | `notehead` (req.); `stem?` (`LineElement`), `flag?`, `accidental?` (`GlyphElement`); `dots[]` (`GlyphElement`), `ledgerLines[]` (`LineElement`) | none (pitch/length/dots/stem = roles) |
| `RestElement` | `RestNote` | **composite** | `glyph` — rest `GlyphElement` | none |
| `BeamElement` | `Beam` (on `PitchNote.beams`) | collection (placeholder) | `RectElement`/`LineElement` segment(s) | none (built by WP6; uses S5 refs) |
| **Separators** (`separators.dart`) | | | | |
| `BarlineElement` | `Barline` (`BarLineTypes`) | collection | `LineElement`/`GlyphElement`(s) for the style | none (engraving defaults → `Styling` in WP5) |
| **Context-dependent** (`context_dependent.dart`) — placeholders; S5 = mechanism, WP6 = math | | | | |
| `TieElement` | `Tied` | collection (placeholder) | `PathElement`/`LineElement` curve (once endpoints known) | none here (S5 adds reference fields) |
| `SlurElement` | `Slur` | collection (placeholder) | `PathElement` curve | none here (S5) |
| `DynamicElement` | `Dynamics` | collection (placeholder) | `GlyphElement`(s) per dynamic glyph | none here (S5) |
| `DirectionElement` | `Direction` (`Wedge` / `Words` / `OctaveShift`) | collection (placeholder) | `LineElement`/`RectElement`/`GlyphElement`(s) | none here (S5) |

A note's **stem, flag, accidental, augmentation dots and ledger lines** are
modelled as **primitive roles** of `PitchedNoteElement`, not standalone semantic
types (WP1-S3 decision: start lean; promote a part to its own type only if a
rule later needs it).

Coverage check: every type traces to a `data.dart` concept. `ColumnElement` is
the one *layout-derived* type with no single `data.dart` class, but is derived
from listed `data.dart` fields (the division grid) and noted as such so coverage
stays auditable. No type lacks a MusicXML counterpart.

### Glyph-knowledge contract (governing rule)

Stated once in `semantic.dart` and enforced by structure:

- **Glyph identity** (`Glyph` enum key) is stored only on `GlyphElement` — the
  one glyph fact a node holds.
- **Per-glyph geometry** (bbox, anchors, advance width) is read via
  parameterised free functions that take the metadata table as a parameter —
  never copied as node fields. The advance-width reader lives in
  [`lib/graphics/layout/glyph_metadata.dart`](../../lib/graphics/layout/glyph_metadata.dart);
  the bbox local getter is the S1 primitive-layer getter, and anchors move to
  the parameterised pattern in S4.
- **Concept→glyph mapping** (e.g. `NoteLength.quarter → noteheadBlack`) is
  reference data in `lib/graphics/notes.dart`, consulted by the WP5 builder —
  not stored on nodes.
- **Global engraving defaults** (stem/beam thickness, ledger extension, …) are
  resolved into `Styling` by WP5 rules — never stored raw on nodes.

### Advance-width scope (decided)

**Advance width is surfaced in WP1** as a parameterised free function
(`glyphAdvanceWidth` in `layout/glyph_metadata.dart`), alongside the other
per-glyph metadata readers, so a copy can never sneak onto a node. It is a
spacing **input/hint** the WP5 horizontal-spacing rule consumes — **not** the
final gap: the rule may widen, tighten or ignore it. The decision of *where the
notes go* remains a WP5 layout-rule concern; only the per-glyph fact lives here.
