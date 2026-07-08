/// Semantic IR nodes — the *layer 2* of the graphics model (WP1-S3).
///
/// The IR has two layers:
/// - **Primitive elements** (`GroupElement`, `PathElement`, `LineElement`,
///   `RectElement`, `GlyphElement` in `canvas_primitives.dart`) — the drawable
///   leaves;
/// - **Semantic elements** (the types in this library) — meaningful musical
///   nodes (a note, a clef, a measure) that *compose* primitives and carry
///   layout intent.
///
/// ## Bounded to the MusicXML vocabulary
///
/// The taxonomy is **deliberately minimal**: it mirrors only the vocabulary our
/// MusicXML parser already produces (`lib/musicXML/data.dart`), not the full
/// SMUFL catalogue. New semantic types are added later, on demand, as layout
/// rules need them. No type in this library lacks a MusicXML counterpart (see
/// the taxonomy table in `docs/wp1/S3-element-taxonomy.md`).
///
/// ## Semantic nodes compose primitive leaves — as collections or composites
///
/// A semantic node **composes** primitive leaves (typically `GlyphElement`s /
/// `LineElement`s) and is *not* itself a `GlyphElement`: a musical concept is
/// rarely one-to-one with a single glyph (a clef ≈ one glyph; a note ≈
/// notehead + stem + flag + dots). Glyph **identity** lives at the leaves; the
/// semantic node only knows *which* leaves it composes and *how they attach*
/// (anchors, S4). It does **not** store musical concept values (pitch, length,
/// clef sign) — those were consumed by the WP5 builder to choose and place the
/// leaves, and are encoded by the leaves / tree position afterwards.
///
/// There are **two shapes** of composing node, and the distinction is
/// deliberate (it is the whole point of separating `GroupElement` from
/// `CompositeElement`):
///
/// - **Collection** (`GroupElement` / a typed container): its `elements` are
///   an *open*, mutable list whose length is data-driven and which have **no
///   distinct named roles** — parts of a system, measures of a staff, columns
///   of a measure, the accidentals of a key signature, the style leaves of a
///   barline. A list is the right model here.
/// - **Composite** (`CompositeElement`): a *fixed set of named roles* — a time
///   signature's `beats`/`beatType`, a note's `notehead`/`stem`/`flag`/… . The
///   roles are typed named fields, so they are never anonymous and the arity
///   is codified (a time signature *cannot* be built with one numeral). Its
///   `elements` are a read-only list *derived* from the roles, so the generic
///   tree-walk still sees a plain ordered list.
///
/// A composite's role may be any `Element` — usually a **primitive leaf** (a
/// stem is a `LineElement`, a flag a `GlyphElement`). We start lean and do not
/// introduce a dedicated semantic wrapper type per part; one is added later
/// only if a rule needs it.
///
/// ## Fields are minimal for the first milestone
///
/// Each semantic type carries only the layout-relevant identity/structure it
/// genuinely needs for the first multi-staff line; anything speculative is
/// out of scope and is added by the WP5/WP6 rule that needs it. Most event and
/// attribute types therefore carry **no** extra fields for now — the *type
/// itself* is the contribution, giving WP4 selectors something to target and
/// S5 cross-references something to attach to.
///
/// ## Glyph-knowledge contract (governing rule for the whole IR)
///
/// Elements reference glyphs by **identity** (the `Glyph` enum key) — stored
/// only on `GlyphElement`, the one glyph fact a node holds. Per-glyph
/// **metadata** (bounding box, anchors, advance width) is **derived on
/// demand** via parameterised free functions that take the metadata table as a
/// parameter (the S4 testability rule) — never duplicated as fields on a node.
/// The musical-concept → `Glyph` mapping (e.g. `NoteLength.quarter →
/// noteheadBlack`) is **reference data** consulted when *building* the tree
/// (WP5), not stored on nodes. Global **engraving defaults** (stem/beam
/// thickness, ledger extension) are not per-glyph; they are resolved into
/// `Styling` by WP5 rules, never stored raw on nodes.
///
/// See `docs/wp1/S3-element-taxonomy.md` for the full taxonomy table and
/// `../layout/glyph_metadata.dart` for the parameterised per-glyph metadata
/// readers.
library;

export 'attributes.dart';
export 'context_dependent.dart';
export 'events.dart';
export 'separators.dart';
export 'structural.dart';
