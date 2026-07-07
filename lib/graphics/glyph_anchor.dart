import 'dart:ui' show Offset;

/// Per-glyph SMUFL anchor set (WP1-S4).
///
/// Each field is a named SMUFL anchor point in the glyph's own coordinate
/// space (staff-space units). A field is **nullable** to express *presence*:
/// `null` means the glyph does not define that anchor — the generated
/// `glyphAnchors` map entries only set the anchors a glyph actually has. This
/// is what makes absence distinguishable from a legitimate anchor at the
/// origin (e.g. some noteheads' `stemDownNW` is `Offset.zero`): zero is **not**
/// a sentinel for "absent", `null` is.
///
/// An anchor's local offset is a **static per-glyph fact** — it is known the
/// moment the tree is built and does not change across layout passes. Only the
/// *absolute* position (the offset composed with ancestor transforms) is
/// deferred for context-dependent elements (S5). A builder therefore resolves
/// the local offset eagerly by reading the field directly off the
/// [GlyphAnchor] record (taking the `glyphAnchors` table as a parameter — the
/// S4 testability rule) and stores that `Offset` if a deferred element needs
/// it; the absolute resolution is a transform composition, not an anchor
/// lookup (see `absoluteAnchorOffset` in `layout/glyph_metadata.dart`).
///
/// This class is **hand-written** (it carries the nullable-presence logic and
/// the `translate` helper), not generated. Only the `glyphAnchors` data map in
/// `generated/glyph_anchors.dart` is generated; it imports this class. Keeping
/// the class out of `generated/` ensures a regeneration of the SMUFL data does
/// not discard the hand-written logic (see `docs/code-principle.md`).
class GlyphAnchor {
  const GlyphAnchor({
    this.splitStemUpSE,
    this.splitStemUpSW,
    this.splitStemDownNE,
    this.splitStemDownNW,
    this.stemUpSE,
    this.stemDownNW,
    this.stemUpNW,
    this.stemDownSW,
    this.nominalWidth,
    this.numeralTop,
    this.numeralBottom,
    this.cutOutNE,
    this.cutOutSE,
    this.cutOutSW,
    this.cutOutNW,
    this.graceNoteSlashSW,
    this.graceNoteSlashNE,
    this.graceNoteSlashNW,
    this.graceNoteSlashSE,
    this.repeatOffset,
    this.noteheadOrigin,
    this.opticalCenter,
  });

  final Offset? splitStemUpSE;
  final Offset? splitStemUpSW;
  final Offset? splitStemDownNE;
  final Offset? splitStemDownNW;
  final Offset? stemUpSE;
  final Offset? stemDownNW;
  final Offset? stemUpNW;
  final Offset? stemDownSW;
  final Offset? nominalWidth;
  final Offset? numeralTop;
  final Offset? numeralBottom;
  final Offset? cutOutNE;
  final Offset? cutOutSE;
  final Offset? cutOutSW;
  final Offset? cutOutNW;
  final Offset? graceNoteSlashSW;
  final Offset? graceNoteSlashNE;
  final Offset? graceNoteSlashNW;
  final Offset? graceNoteSlashSE;
  final Offset? repeatOffset;
  final Offset? noteheadOrigin;
  final Offset? opticalCenter;

  /// Returns a copy with every **present** anchor shifted by [offset]; absent
  /// (`null`) anchors stay absent (presence is preserved, not invented).
  ///
  /// Used by legacy render code that offsets a notehead's anchors by its staff
  /// position; retired when WP2 makes the renderer a pure tree-walker.
  GlyphAnchor translate(Offset offset) {
    Offset? shift(Offset? p) => p == null ? null : p + offset;
    return GlyphAnchor(
      splitStemUpSE: shift(splitStemUpSE),
      splitStemUpSW: shift(splitStemUpSW),
      splitStemDownNE: shift(splitStemDownNE),
      splitStemDownNW: shift(splitStemDownNW),
      stemUpSE: shift(stemUpSE),
      stemDownNW: shift(stemDownNW),
      stemUpNW: shift(stemUpNW),
      stemDownSW: shift(stemDownSW),
      nominalWidth: shift(nominalWidth),
      numeralTop: shift(numeralTop),
      numeralBottom: shift(numeralBottom),
      cutOutNE: shift(cutOutNE),
      cutOutSE: shift(cutOutSE),
      cutOutSW: shift(cutOutSW),
      cutOutNW: shift(cutOutNW),
      graceNoteSlashSW: shift(graceNoteSlashSW),
      graceNoteSlashNE: shift(graceNoteSlashNE),
      graceNoteSlashNW: shift(graceNoteSlashNW),
      graceNoteSlashSE: shift(graceNoteSlashSE),
      repeatOffset: shift(repeatOffset),
      noteheadOrigin: shift(noteheadOrigin),
      opticalCenter: shift(opticalCenter),
    );
  }
}
