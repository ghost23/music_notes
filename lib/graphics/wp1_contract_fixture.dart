/// The WP1 contract-validation fixture — a musically-faithful grand staff.
///
/// A **hand-built** multi-staff scene graph — constructed purely with IR
/// constructors and free functions, no layout engine, no rules — that both
/// exercises the whole WP1 contract end-to-end **and** reads as real music, so
/// its render can be compared against what other engraving software produces
/// (see `docs/wp1/test.png` for the reference this reproduces).
///
/// It exercises:
/// - **S1** staff-space transforms + free geometry (`absoluteTransform`,
///   `absoluteBoundingBox`);
/// - **S2** scale-free styling (color + staff-space stroke width; no `Paint`
///   or `TextStyle`);
/// - **S3** the semantic taxonomy (system/part/staff/measure/column + clef/
///   time-signature/note/rest/barline composites, an accidental, staff lines);
/// - **S4** named, transform-aware anchors (a stem placed at a notehead's
///   `stemUpSE` anchor);
/// - **S5** cross-references & the unresolved state — here the **staff lines**,
///   whose horizontal length is content-driven and therefore *deferred*: built
///   unresolved and completed by [resolveStaffLines] once the content width is
///   known (the same mechanism a slur/beam uses; any node may be unresolved);
/// - **S6** multi-staff vertical arrangement (`arrangeStavesVertical`).
///
/// It is the practical "definition of done" demonstrator for WP1 (see
/// `docs/wp1/README.md`) and the shared example WP2 (render) and WP3 (layout)
/// tests build against.
///
/// ## The music (matches `docs/wp1/test.png`)
///
///     Treble (staff 1), 4/4:
///       m1: half note G4, half note A4 (with a ♯), stems up          → 4 beats
///       m2: whole note F5
///     Bass (staff 2), 4/4:
///       m1: whole note D3
///       m2: whole rest
///     Barlines close every measure (regular between, final at the end),
///     aligned across the two staves; five staff lines per staff.
///
/// ## Coordinates (staff-space units, y-down; hand-computable)
///
/// Staff-local lines sit at `y = 0` (top) … `y = 4` (bottom); the middle line
/// is `y = 2`. Glyphs are placed at their **SMUFL registration** position (the
/// renderer aligns the glyph baseline to the node origin — see
/// `render/draw_primitives.dart`):
/// - gClef origin on the **G4 line** (`y = 3`); fClef origin on the **F3 line**
///   (`y = 1`);
/// - a notehead's origin is its **vertical centre**, so a note on the middle
///   line sits at `y = 2`; each diatonic step is `0.5` staff space;
/// - the two time-signature numerals are centred at `y = 1` and `y = 3`
///   (`timeSig4`'s origin is its vertical centre);
/// - the whole rest's origin hangs from the second line from the top (`y = 1`).
///
/// Staves are stacked by [arrangeStavesVertical]: staff 1 at `dy = 0`, staff 2
/// at `dy = 12`.
library;

import 'dart:ui' show Color, Offset;

import 'package:music_notes_2/graphics/generated/glyph_anchors.dart'
    show glyphAnchors;
import 'package:music_notes_2/graphics/generated/glyph_definitions.dart'
    show Glyph;
import 'package:music_notes_2/graphics/graphics_model/canvas_primitives.dart'
    show GlyphElement, GroupElement, LineElement;
import 'package:music_notes_2/graphics/graphics_model/semantic/semantic.dart';
import 'package:music_notes_2/graphics/graphics_model/styling.dart' show Styling;
import 'package:music_notes_2/graphics/graphics_model/transform.dart'
    show NodeTransform;
import 'package:music_notes_2/graphics/layout/system.dart'
    show arrangeStavesVertical;

// ----------------------------------------------------------------------
// Documented constants (hand-computed; see the library doc above).
// ----------------------------------------------------------------------

/// The `noteheadHalf` `stemUpSE` anchor offset (SMUFL, y-down): `(1.18, -0.168)`.
///
/// Read at build time from `glyphAnchors` (S4); exposed so tests assert against
/// the exact value the builder used.
const Offset noteheadHalfStemUpSe = Offset(1.18, -0.168);

/// The stem length (staff-space) the builder draws above the notehead anchor.
const double stemLength = 3.5;

/// The default inter-staff distance applied by [arrangeStavesVertical]: `12`
/// staff spaces (staff height 4 + gap 8). Staff 2's top line sits at `dy = 12`.
const double expectedStaff2Dy = 12.0;

/// Measure 2's horizontal offset within each staff (to the right of measure 1).
const double measure2Dx = 11.0;

// ----------------------------------------------------------------------
// Scale-free styling (S2): color + staff-space stroke width. No Paint /
// TextStyle is ever constructed in the model layer.
// ----------------------------------------------------------------------

const _black = Color(0xFF000000);
const _blackFill = Styling(fillColor: _black);

/// Stem stroke — `EngravingDefaults.stemThickness` (0.12 staff space).
const _stemStroke = Styling(strokeColor: _black, strokeWidth: 0.12);

/// Staff-line stroke — `EngravingDefaults.staffLineThickness` (0.13).
const _staffLineStroke = Styling(strokeColor: _black, strokeWidth: 0.13);

/// Thin barline stroke — `EngravingDefaults.thinBarlineThickness` (0.16).
const _thinBarlineStroke = Styling(strokeColor: _black, strokeWidth: 0.16);

/// Thick (final) barline stroke — `EngravingDefaults.thickBarlineThickness`
/// (0.5).
const _thickBarlineStroke = Styling(strokeColor: _black, strokeWidth: 0.5);

/// Separation between the thin and thick strokes of a final barline —
/// `EngravingDefaults.barlineSeparation` (0.4).
const double _barlineSeparation = 0.4;

// ----------------------------------------------------------------------
// The fixture handle.
// ----------------------------------------------------------------------

/// The built WP1 contract fixture: the scene-graph root plus handles to the
/// nodes the tests (and WP2/WP3) reach by identity.
class Wp1ContractFixture {
  Wp1ContractFixture._({
    required this.system,
    required this.part,
    required this.staff1,
    required this.staff2,
    required this.trebleClef,
    required this.bassClef,
    required this.timeSignature1,
    required this.timeSignature2,
    required this.halfNoteG,
    required this.halfNoteGStem,
    required this.halfNoteA,
    required this.halfNoteASharp,
    required this.trebleWholeNote,
    required this.bassWholeNote,
    required this.wholeRest,
    required this.barlines,
  });

  /// The scene-graph root: a 2-staff system arranged vertically (S6).
  final SystemElement system;

  /// The single part holding both staves.
  final PartElement part;

  /// Staff #1 (treble, `dy = 0`). Its deferred staff lines are
  /// `staff1.staffLines` (unresolved until [resolveStaffLines]).
  final StaffElement staff1;

  /// Staff #2 (bass, `dy = 12`).
  final StaffElement staff2;

  /// The treble clef (`gClef`) of staff 1, measure 1.
  final ClefElement trebleClef;

  /// The bass clef (`fClef`) of staff 2, measure 1.
  final ClefElement bassClef;

  /// The 4/4 time signature in staff 1's first measure.
  final TimeSignatureElement timeSignature1;

  /// The 4/4 time signature in staff 2's first measure.
  final TimeSignatureElement timeSignature2;

  /// Treble m1 first half note (G4) — its stem is placed at the notehead's
  /// `stemUpSE` anchor (S4).
  final PitchedNoteElement halfNoteG;

  /// The stem leaf on [halfNoteG], for asserting the S4 anchor attachment.
  final LineElement halfNoteGStem;

  /// Treble m1 second half note (A4) — carries a sharp accidental.
  final PitchedNoteElement halfNoteA;

  /// The sharp accidental on [halfNoteA] (`accidentalSharp`).
  final GlyphElement halfNoteASharp;

  /// Treble m2 whole note (F5) — `noteheadWhole`, no stem.
  final PitchedNoteElement trebleWholeNote;

  /// Bass m1 whole note (D3) — `noteheadWhole`, no stem.
  final PitchedNoteElement bassWholeNote;

  /// Bass m2 whole rest (`restWhole`).
  final RestElement wholeRest;

  /// Every barline in the score (two per staff: a regular barline closing
  /// measure 1 and a final barline closing measure 2), for taxonomy assertions.
  final List<BarlineElement> barlines;
}

// ----------------------------------------------------------------------
// The builder.
// ----------------------------------------------------------------------

/// Builds the WP1 contract fixture: a 2-staff grand staff (clefs + 4/4 + notes/
/// rests + barlines), a stem placed via a notehead anchor (S4), deferred staff
/// lines (S5), arranged vertically (S6) — all in staff-space units.
///
/// The tree is returned fully built and arranged; the **staff lines are left
/// unresolved** for the caller to resolve via [resolveStaffLines] (both staves)
/// before rendering — the S3 render walker refuses unresolved nodes (WP1-S5).
Wp1ContractFixture buildWp1ContractFixture() {
  final halfStemUpSe = glyphAnchors[Glyph.noteheadHalf]!.stemUpSE!;
  assert(halfStemUpSe == noteheadHalfStemUpSe); // sanity: matches documented value

  // A stem-up stem for a half note: from the notehead's stemUpSE anchor,
  // straight up (−y) by [stemLength], in the note's local space.
  LineElement stemUpHalf() => LineElement(
        const NodeTransform.identity(),
        halfStemUpSe,
        halfStemUpSe.translate(0, -stemLength),
        styling: _stemStroke,
      );

  // A single-glyph clef whose origin sits on its reference line.
  ClefElement clef(Glyph glyph, double lineY) => ClefElement(
        NodeTransform(translation: Offset(0.5, lineY)),
        glyph: GlyphElement(const NodeTransform.identity(), glyph,
            styling: _blackFill),
      );

  // A 4/4 time signature: two numerals centred at y = 1 (top) and y = 3
  // (bottom), i.e. in the upper and lower halves of the staff.
  TimeSignatureElement fourFour() => TimeSignatureElement(
        const NodeTransform(translation: Offset(3, 0)),
        beats: GlyphElement(const NodeTransform(translation: Offset(0, 1)),
            Glyph.timeSig4, styling: _blackFill),
        beatType: GlyphElement(const NodeTransform(translation: Offset(0, 3)),
            Glyph.timeSig4, styling: _blackFill),
      );

  GlyphElement wholeNoteHead() =>
      GlyphElement(const NodeTransform.identity(), Glyph.noteheadWhole,
          styling: _blackFill);

  // A vertical barline segment spanning the staff (top line y=0 to bottom y=4).
  LineElement barSegment(double x, Styling styling) => LineElement(
        NodeTransform(translation: Offset(x, 0)),
        Offset.zero,
        const Offset(0, 4),
        styling: styling,
      );

  BarlineElement regularBarline(double x) =>
      BarlineElement(NodeTransform(translation: Offset(x, 0)),
          [barSegment(0, _thinBarlineStroke)]);

  // A final barline: a thin then a thick segment, separated by barlineSeparation.
  BarlineElement finalBarline(double x) =>
      BarlineElement(NodeTransform(translation: Offset(x, 0)), [
        barSegment(0, _thinBarlineStroke),
        barSegment(_barlineSeparation, _thickBarlineStroke),
      ]);

  // An empty, unresolved staff-lines slot (S5): resolved by resolveStaffLines
  // once the content width is known.
  GroupElement deferredStaffLines() =>
      GroupElement(const NodeTransform.identity())..isResolved = false;

  // --- Staff 1 (treble) -------------------------------------------------

  final trebleClef = clef(Glyph.gClef, 3); // gClef origin on the G4 line
  final timeSignature1 = fourFour();

  // Half note G4 (y = 3), stem up.
  final halfNoteGHead = GlyphElement(
      const NodeTransform.identity(), Glyph.noteheadHalf,
      styling: _blackFill);
  final halfNoteGStem = stemUpHalf();
  final halfNoteG = PitchedNoteElement(
    const NodeTransform(translation: Offset(5.5, 3)),
    notehead: halfNoteGHead,
    stem: halfNoteGStem,
  );

  // Half note A4 (y = 2.5) with a sharp, stem up.
  final halfNoteAHead = GlyphElement(
      const NodeTransform.identity(), Glyph.noteheadHalf,
      styling: _blackFill);
  final halfNoteASharp = GlyphElement(
      const NodeTransform(translation: Offset(-1.3, 0)), Glyph.accidentalSharp,
      styling: _blackFill);
  final halfNoteA = PitchedNoteElement(
    const NodeTransform(translation: Offset(8.5, 2.5)),
    notehead: halfNoteAHead,
    stem: stemUpHalf(),
    accidental: halfNoteASharp,
  );

  final staff1Barline1 = regularBarline(10.5);
  final staff1Measure1 = MeasureElement(
    const NodeTransform.identity(),
    [
      ColumnElement(const NodeTransform.identity(), [halfNoteG]),
      ColumnElement(const NodeTransform.identity(), [halfNoteA]),
    ],
    GroupElement(const NodeTransform.identity(), [trebleClef, timeSignature1]),
    staff1Barline1,
  );

  // Whole note F5 (y = 0, top line).
  final trebleWholeNote = PitchedNoteElement(
    const NodeTransform(translation: Offset(2, 0)),
    notehead: wholeNoteHead(),
  );
  final staff1Barline2 = finalBarline(5);
  final staff1Measure2 = MeasureElement(
    const NodeTransform(translation: Offset(measure2Dx, 0)),
    [ColumnElement(const NodeTransform.identity(), [trebleWholeNote])],
    null,
    staff1Barline2,
  );

  final staff1 = StaffElement(
    const NodeTransform.identity(),
    1,
    [staff1Measure1, staff1Measure2],
  )..staffLines = deferredStaffLines();

  // --- Staff 2 (bass) ---------------------------------------------------

  final bassClef = clef(Glyph.fClef, 1); // fClef origin on the F3 line
  final timeSignature2 = fourFour();

  // Whole note D3 (y = 2, middle line).
  final bassWholeNote = PitchedNoteElement(
    const NodeTransform(translation: Offset(5.5, 2)),
    notehead: wholeNoteHead(),
  );
  final staff2Barline1 = regularBarline(10.5);
  final staff2Measure1 = MeasureElement(
    const NodeTransform.identity(),
    [
      ColumnElement(const NodeTransform.identity(), [bassWholeNote]),
    ],
    GroupElement(const NodeTransform.identity(), [bassClef, timeSignature2]),
    staff2Barline1,
  );

  // Whole rest, hanging from the second line from the top (y = 1), centred.
  final wholeRest = RestElement(
    const NodeTransform(translation: Offset(2.5, 1)),
    glyph: GlyphElement(const NodeTransform.identity(), Glyph.restWhole,
        styling: _blackFill),
  );
  final staff2Barline2 = finalBarline(5);
  final staff2Measure2 = MeasureElement(
    const NodeTransform(translation: Offset(measure2Dx, 0)),
    [ColumnElement(const NodeTransform.identity(), [wholeRest])],
    null,
    staff2Barline2,
  );

  final staff2 = StaffElement(
    const NodeTransform.identity(),
    2,
    [staff2Measure1, staff2Measure2],
  )..staffLines = deferredStaffLines();

  // --- System (S6 vertical arrangement) ---------------------------------

  final part = PartElement(const NodeTransform.identity(), [staff1, staff2]);
  final system = SystemElement(const NodeTransform.identity(), [part]);

  // Mutates each staff's transform.translation.dy in place (identity-stable).
  arrangeStavesVertical(part);

  return Wp1ContractFixture._(
    system: system,
    part: part,
    staff1: staff1,
    staff2: staff2,
    trebleClef: trebleClef,
    bassClef: bassClef,
    timeSignature1: timeSignature1,
    timeSignature2: timeSignature2,
    halfNoteG: halfNoteG,
    halfNoteGStem: halfNoteGStem,
    halfNoteA: halfNoteA,
    halfNoteASharp: halfNoteASharp,
    trebleWholeNote: trebleWholeNote,
    bassWholeNote: bassWholeNote,
    wholeRest: wholeRest,
    barlines: [
      staff1Barline1,
      staff1Barline2,
      staff2Barline1,
      staff2Barline2,
    ],
  );
}

/// Resolves a staff's deferred staff lines (S5 mechanism; the real length is a
/// content-driven layout quantity — see [StaffElement.staffLines]).
///
/// Builds one horizontal [LineElement] per staff line, spanning from the staff
/// origin (`x = 0`) to the staff's current content right edge, installs them as
/// the staff-lines group's children, and flips `isResolved` to `true` —
/// mutating the group **in place** so identity is preserved. Call it for **every
/// staff** before rendering; the render walker refuses the unresolved group
/// otherwise (WP1-S5).
///
/// Throws [StateError] if [staff] has no [StaffElement.staffLines] slot.
void resolveStaffLines(StaffElement staff) {
  final group = staff.staffLines;
  if (group == null) {
    throw StateError(
      'StaffElement #${staff.staffNumber} has no staffLines slot to resolve.',
    );
  }
  // The staff's content right edge. The staff-lines group is still empty
  // (unresolved), so it contributes nothing to this extent; the width is driven
  // by the measures/barlines.
  final width = staff.localBoundingBox.right;
  group
    ..elements = [
      for (var line = 0; line < staff.lineCount; line++)
        LineElement(
          NodeTransform(translation: Offset(0, line.toDouble())),
          Offset.zero,
          Offset(width, 0),
          styling: _staffLineStroke,
        ),
    ]
    ..isResolved = true;
}

/// Resolves the deferred staff lines of **every** staff in [fixture]
/// (convenience over calling [resolveStaffLines] per staff).
void resolveAllStaffLines(Wp1ContractFixture fixture) {
  resolveStaffLines(fixture.staff1);
  resolveStaffLines(fixture.staff2);
}
