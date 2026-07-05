import '../generated/glyph_advance_widths.dart' show glyphAdvanceWidths;
import '../generated/glyph_definitions.dart' show Glyph;

/// Parameterised per-glyph metadata readers (WP1-S3).
///
/// Per the glyph-knowledge contract (see `graphics_model/semantic/semantic.dart`),
/// per-glyph **metadata** — bounding box, anchors, advance width — is **never
/// copied** onto a node. It is read on demand via free functions that take the
/// metadata table as a **parameter**, so they unit-test with hand-built
/// fixtures and no global state (the S4 testability rule). The musical-concept
/// → `Glyph` mapping and the engraving defaults have their own named homes
/// (see `semantic.dart`); this library owns only the per-glyph *geometry*
/// readers.
///
/// ## What lives here (decided in WP1-S3)
///
/// **Advance width** is surfaced here in **WP1** — alongside the other
/// parameterised per-glyph metadata readers — rather than deferred to WP5,
/// so a copy of advance-width data can never sneak onto a node or get passed
/// around as a raw value. The other per-glyph readers join this library as
/// later stories need them:
/// - **Bounding box** is today exposed as the S1 *local* getter
///   `GlyphElement.localBoundingBox` (the primitive layer's own extent). A
///   parameterised bbox reader can be added here when a WP5/WP6 consumer needs
///   a node's bbox without going through the S1 getter; S1/S4 own any change
///   to that getter.
/// - **Anchors** are converted to the parameterised pattern in **S4** (local
///   lookup taking the anchor table as a parameter; absolute lookup composing
///   ancestor transforms via `layout/geometry.dart`). They will live here or
///   alongside `layout/geometry.dart` — S4 picks the final home; either way
///   the contract (parameter, never a copy) is the same.
///
/// ## Advance width is a spacing *input*, not the spacing itself
///
/// A glyph's advance width is the *horizontal space the glyph would occupy if
/// laid out in isolation* — a per-glyph fact. It is an **input/hint** the WP5
/// horizontal-spacing rule consumes, **not** the final gap between notes: the
/// spacing rule may widen the gap (for a comfortable layout), tighten it (to
/// justify a measure), or ignore advance width entirely (e.g. for rests
/// centred in a measure). Surfacing advance width here gives that rule a clean
/// parameterised input; the decision of *where the notes actually go* remains
/// a WP5 layout-rule concern.

/// The advance width of [glyph] in staff-space units, read from
/// [advanceWidths] (defaults to the generated `glyphAdvanceWidths` table).
///
/// The advance width is a per-glyph fact expressed in staff-space units (1
/// staff space = the SMUFL unit). It is a spacing *input* a layout rule may
/// override — see the file doc.
///
/// Throws [ArgumentError] if [glyph] has no entry in [advanceWidths]: a
/// missing advance width is a programmer/usage error (the generated table
/// covers every `Glyph`), not a recoverable condition — per the
/// exceptions-over-null principle. Passing [advanceWidths] explicitly lets
/// tests run with a hand-built table and no global state.
double glyphAdvanceWidth(Glyph glyph, {Map<Glyph, double>? advanceWidths}) {
  final table = advanceWidths ?? glyphAdvanceWidths;
  final width = table[glyph];
  if (width == null) {
    throw ArgumentError(
      'No advance width registered for glyph $glyph.',
    );
  }
  return width;
}
