import '../canvas_primitives.dart' show CompositeElement, Element, GlyphElement, GroupElement;

/// Attribute semantic nodes — the notational attributes that set the staff
/// reference and meter (WP1-S3).
///
/// The musical-concept → `Glyph` mapping (e.g. `Clefs.G → Glyph.gClef`) is
/// **reference data** in `lib/graphics/notes.dart`, consulted by the WP5
/// builder when *building* the tree; it is not stored on these nodes (see the
/// glyph-knowledge contract on `semantic.dart`).
///
/// [ClefElement] and [TimeSignatureElement] are **composites**: they have a
/// fixed set of named glyph roles, so they extend [CompositeElement].
/// [KeySignatureElement] is an **open collection** (a data-driven number of
/// same-kind accidental glyphs, with no distinct named roles), so it stays a
/// [GroupElement].

/// A **clef** setting the staff-line reference for note placement.
///
/// **Source:** `Clef`.
/// **Composes:** one named [glyph] role — the clef glyph (`Glyph.gClef` /
/// `Glyph.fClef`). The clef *sign* is encoded by the glyph identity on that
/// leaf, not re-stored here.
class ClefElement extends CompositeElement {
  ClefElement(super.transform, {required this.glyph});

  /// The single clef glyph leaf.
  GlyphElement glyph;

  @override
  List<Element> get elements => [glyph];
}

/// A **key signature** — the accidentals in effect.
///
/// **Source:** `MusicalKey` (via `Attributes.key`).
/// **Composes:** one [GlyphElement] leaf per accidental (`Glyph.accidentalSharp`
/// / `Glyph.accidentalFlat`), ordered as SMUFL prescribes. This is a genuine
/// **collection**: the count is data-driven (`MusicalKey.fifths`, via the
/// concept→accidentals reference data in `lib/graphics/notes.dart`) and the
/// accidentals share a single role, so an open list — not named roles — is the
/// right model.
class KeySignatureElement extends GroupElement {
  KeySignatureElement(super.transform, [super.elements]);
}

/// A **time signature** — the meter.
///
/// **Source:** `Time` (via `Attributes.time`).
/// **Composes:** exactly two named glyph roles — the [beats] numeral above and
/// the [beatType] numeral below, drawn from the SMUFL time-signature numeral
/// glyphs. The beat/beat-type *values* were consumed by the WP5 builder to
/// select the numeral glyphs and are not re-stored here; the arity (exactly
/// two numerals) is codified by the required role fields.
class TimeSignatureElement extends CompositeElement {
  TimeSignatureElement(
    super.transform, {
    required this.beats,
    required this.beatType,
  });

  /// The beats (numerator) numeral glyph.
  GlyphElement beats;

  /// The beat-type (denominator) numeral glyph.
  GlyphElement beatType;

  @override
  List<Element> get elements => [beats, beatType];
}
