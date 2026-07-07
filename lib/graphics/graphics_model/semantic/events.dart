import '../canvas_primitives.dart'
    show CompositeElement, Element, GlyphElement, LineElement;

/// Event semantic nodes — the sounding symbols placed on the staff (WP1-S3).
///
/// Per the glyph-knowledge contract (see `semantic.dart`), an event knows
/// *which* leaves it composes and *how they attach*; it does **not** store the
/// musical concept values (pitch, length, stem direction, dot count, …) that
/// the WP5 builder consumed to choose and place those leaves.
///
/// ## Parts are primitives, not wrapper types (WP1-S3 decision)
///
/// A note's parts — stem, flag, accidental, augmentation dots, ledger lines —
/// are modelled directly as primitive leaves ([LineElement] for the stem and
/// ledger lines, [GlyphElement] for the flag/accidental/dots) rather than as
/// dedicated semantic wrapper types. They carry no layout intent a primitive
/// cannot express yet, so we start lean; a dedicated sub-type is introduced
/// later only if a rule needs one. This is why [PitchedNoteElement] exposes
/// its parts as **named [GlyphElement]/[LineElement] roles**.

/// A **pitched note** — a note with pitch.
///
/// **Source:** `PitchNote`.
/// **Composes** (named roles, all primitives except where a rule later needs
/// more):
/// - [notehead] — required; the note's length is encoded by its glyph identity
///   and its pitch by its [transform];
/// - [stem] — a stem line, present for lengths below whole; the direction is
///   encoded by which notehead anchor (S4) it attaches to;
/// - [flag] — a flag glyph, present on an unbeamed stemmed note ≥ eighth;
/// - [accidental] — an accidental glyph drawn before the head, when the pitch
///   requires one;
/// - [dots] — augmentation-dot glyphs (0..n, one per `PitchNote.dots`);
/// - [ledgerLines] — ledger line segments (0..n) for a note off the staff.
///
/// A beam rule (WP6) may reposition [stem] via its reference (S5).
class PitchedNoteElement extends CompositeElement {
  PitchedNoteElement(
    super.transform, {
    required this.notehead,
    this.stem,
    this.flag,
    this.accidental,
    this.dots = const [],
    this.ledgerLines = const [],
  });

  /// The notehead glyph — the one required part of a pitched note.
  GlyphElement notehead;

  /// The stem line, or `null` for a stemless note (e.g. a whole note).
  LineElement? stem;

  /// The flag glyph on an unbeamed stemmed note, or `null`.
  GlyphElement? flag;

  /// The accidental glyph drawn before the head, or `null`.
  GlyphElement? accidental;

  /// The augmentation-dot glyphs (one per dot), in reading order.
  List<GlyphElement> dots;

  /// The ledger line segments for a note lying outside the staff.
  List<LineElement> ledgerLines;

  @override
  List<Element> get elements => [
        ...ledgerLines,
        if (accidental != null) accidental!,
        notehead,
        if (stem != null) stem!,
        if (flag != null) flag!,
        ...dots,
      ];
}

/// A **rest**.
///
/// **Source:** `RestNote`.
/// **Composes:** one named [glyph] role — the rest glyph for the duration
/// (`Glyph.restWhole` / `restHalf` / `restQuarter` / …). The duration is
/// encoded by the rest glyph identity.
class RestElement extends CompositeElement {
  RestElement(super.transform, {required this.glyph});

  /// The single rest glyph leaf.
  GlyphElement glyph;

  @override
  List<Element> get elements => [glyph];
}
