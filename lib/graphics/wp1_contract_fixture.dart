/// The WP1 contract-validation fixture (WP1-S7).
///
/// A **hand-built** multi-staff scene graph — constructed purely with IR
/// constructors and free functions, no layout engine, no rules — that
/// exercises the whole WP1 contract end-to-end:
/// - **S1** staff-space transforms + free geometry (`absoluteTransform`,
///   `absoluteBoundingBox`);
/// - **S2** scale-free styling (color + staff-space stroke width; no `Paint`
///   or `TextStyle`);
/// - **S3** the semantic taxonomy (system/part/staff/measure/column + clef/
///   time-signature/note/rest composites, accidentals, flags);
/// - **S4** named, transform-aware anchors (a stem placed at a notehead's
///   `stemUpSE` anchor, and an eighth-note flag placed at the stem top via the
///   flag's `stemUpNW` anchor);
/// - **S5** cross-references & the unresolved state (a placeholder slur over
///   two noteheads, resolved by [fakeResolveSlur]);
/// - **S6** multi-staff vertical arrangement (`arrangeStavesVertical`).
///
/// It is the practical "definition of done" demonstrator for WP1 (see
/// `docs/wp1/README.md`) and the shared golden example WP2 (render) and WP3
/// (layout) tests build against.
///
/// ## Layout (all values staff-space units; transforms hand-computable)
///
///     SystemElement (identity)
///       └ PartElement (identity)
///           ├ StaffElement #1 (dy = 0)   ← arranged by arrangeStavesVertical
///           │   ├ MeasureElement #1 (identity)
///           │   │   ├ attributes: gClef at (0,0), 4/4 time sig at (3,2)
///           │   │   ├ ColumnElement (identity)
///           │   │   │   ├ Note A at (5,2): noteheadBlack + stem (stem-up,
///           │   │   │   │                placed via notehead.stemUpSE)
///           │   │   │   └ SlurElement (unresolved) — spans A→B
///           │   │   └ ColumnElement (identity)
///           │   │       └ Note B at (8,1): noteheadBlack + sharp accidental
///           │   └ MeasureElement #2 (translation (12,0))
///           │       └ ColumnElement (identity)
///           │           └ Eighth note at (1,2)→(13,2): noteheadBlack + stem
///           │             + flag8thUp (placed via flag.stemUpNW at stem top)
///           └ StaffElement #2 (dy = 12)
///               ├ MeasureElement #1 (identity)
///               │   ├ attributes: fClef at (0,0), 4/4 time sig at (3,2)
///               │   └ ColumnElement (identity)
///               │       └ Note C at (5,3)→(5,15): noteheadBlack
///               └ MeasureElement #2 (translation (12,0))
///                   └ ColumnElement (identity)
///                       └ Full rest at (1,2)→(13,14): restWhole
///
/// ## Hand-computed expected geometry (documented for the tests)
///
/// Staff origins (S6): staff1 → `(0,0)`; staff2 → `(0,12)`.
///
/// Note absolute origins: A → `(5,2)`; B → `(8,1)`; C → `(5,15)`
/// (staff2 dy=12 + note y=3); eighth note → `(13,2)` (measure2 dx=12 + 1);
/// full rest → `(13,14)` (staff2 dy=12 + measure2 dx=12 + 1, y=2).
///
/// `noteheadBlack.stemUpSE = (1.18, -0.168)` (SMUFL). So:
/// - A's stemUpSE absolute = `(5+1.18, 2-0.168) = (6.18, 1.832)` (S4);
/// - the stem (length 3 up) starts at that anchor, so its absolute start =
///   `(6.18, 1.832)` — proving the stem is attached at the anchor;
/// - B's stemUpSE absolute = `(8+1.18, 1-0.168) = (9.18, 0.832)`.
///
/// The eighth note's flag is placed via `flag8thUp.stemUpNW = (0, 0.04)` at the
/// stem top `(1.18, -3.168)` in the note's local space → flag translation
/// `(1.18, -3.208)`. The flag's `stemUpNW` absolute therefore coincides with
/// the stem top absolute `(13+1.18, 2-3.168) = (14.18, -1.168)` (S4, a second
/// anchor attachment).
///
/// The slur (S5) cross-references A's and B's noteheads with `stemUpSE` as
/// their local anchor; [fakeResolveSlur] draws a straight line between the two
/// absolute anchor points: `(6.18, 1.832) → (9.18, 0.832)`.
///
/// System bounding box (S1, real glyph bboxes composed with clean transforms):
/// - top  = `−4.392`  (gClef bbox top at staff1; `gClef` NE.y = −4.392);
/// - bottom = `16`    (staff2's 5-line region bottom: 12 + 4);
/// - left = `−0.02`   (fClef bbox left at staff2; `fClef` SW.x = −0.02);
/// - right = `15.236` (eighth-note flag right edge: 13 + 1.18 + 1.056).
///
/// The resolved slur line `(6.18, 0.832)–(9.18, 1.832)` lies inside this box,
/// so the system bbox is unchanged by resolution.
library;

import 'dart:ui' show Color, Offset;

import 'package:vector_math/vector_math_64.dart' show Matrix4;

import 'package:music_notes_2/graphics/generated/glyph_anchors.dart'
    show glyphAnchors;
import 'package:music_notes_2/graphics/generated/glyph_definitions.dart'
    show Glyph;
import 'package:music_notes_2/graphics/graphics_model/canvas_primitives.dart'
    show Element, GlyphElement, GroupElement, LineElement;
import 'package:music_notes_2/graphics/graphics_model/semantic/semantic.dart';
import 'package:music_notes_2/graphics/graphics_model/styling.dart' show Styling;
import 'package:music_notes_2/graphics/graphics_model/transform.dart'
    show NodeTransform;
import 'package:music_notes_2/graphics/layout/cross_references.dart'
    show absoluteTransformIndex, crossReferenceAbsoluteOffset;
import 'package:music_notes_2/graphics/layout/system.dart'
    show arrangeStavesVertical;

// ----------------------------------------------------------------------
// Expected values (hand-computed; see the library doc above).
// ----------------------------------------------------------------------

/// The `noteheadBlack` `stemUpSE` anchor offset (SMUFL): `(1.18, -0.168)`.
///
/// Read at build time from `glyphAnchors` (S4); exposed here so tests assert
/// against the exact value the builder used.
const Offset noteheadBlackStemUpSe = Offset(1.18, -0.168);

/// The `flag8thUp` `stemUpNW` anchor offset (SMUFL): `(0, 0.04)`.
const Offset flag8thUpStemUpNw = Offset(0, 0.04);

/// The default inter-staff distance applied: `12` staff spaces (staff height
/// 4 + gap 8). Staff2's top line sits at `dy = 12`.
const double expectedStaff2Dy = 12.0;

/// Note A's `stemUpSE` anchor in absolute (system) space: `(6.18, 1.832)`.
const Offset expectedNoteheadAStemUpSeAbsolute = Offset(6.18, 1.832);

/// Note B's `stemUpSE` anchor in absolute (system) space: `(9.18, 0.832)`.
const Offset expectedNoteheadBStemUpSeAbsolute = Offset(9.18, 0.832);

/// The eighth note's stem-top / flag-`stemUpNW` absolute: `(14.18, -1.168)`
/// (`13 + 1.18`, `2 - 3.168`).
const Offset expectedEighthStemTopAbsolute = Offset(14.18, -1.168);

/// The stem length (staff-space) the builder attaches above the anchor.
const double stemLength = 3.0;

/// Measure 2's horizontal offset (to the right of measure 1's content).
const double measure2Dx = 12.0;

// ----------------------------------------------------------------------
// Scale-free styling (S2): color + staff-space stroke width. No Paint /
// TextStyle is ever constructed in the model layer.
// ----------------------------------------------------------------------

const _blackFill = Styling(fillColor: Color(0xFF000000));
const _blackStroke = Styling(
  strokeColor: Color(0xFF000000),
  strokeWidth: 0.12, // staff-space (EngravingDefaults.stemThickness)
);

// ----------------------------------------------------------------------
// The fixture.
// ----------------------------------------------------------------------

/// The built WP1 contract fixture: the scene-graph root plus handles to the
/// nodes the tests (and WP2/WP3) need to reach by identity.
///
/// Construct it with [buildWp1ContractFixture]. Every field is a node in the
/// tree returned by [system]; the handles let tests inspect / mutate specific
/// nodes (e.g. resolve [slur]) without re-searching the tree.
class Wp1ContractFixture {
  Wp1ContractFixture._({
    required this.system,
    required this.part,
    required this.staff1,
    required this.staff2,
    required this.timeSignature1,
    required this.timeSignature2,
    required this.noteA,
    required this.noteheadA,
    required this.stemA,
    required this.noteB,
    required this.noteheadB,
    required this.noteBAccidental,
    required this.noteC,
    required this.eighthNote,
    required this.eighthNoteFlag,
    required this.fullRest,
    required this.slur,
  });

  /// The scene-graph root: a 2-staff system arranged vertically (S6).
  final SystemElement system;

  /// The single part holding both staves.
  final PartElement part;

  /// Staff #1 (treble, `dy = 0`).
  final StaffElement staff1;

  /// Staff #2 (bass, `dy = 12`).
  final StaffElement staff2;

  /// The 4/4 time signature in staff1's first measure.
  final TimeSignatureElement timeSignature1;

  /// The 4/4 time signature in staff2's first measure.
  final TimeSignatureElement timeSignature2;

  /// Note A (staff1 m1, at `(5,2)`) — has a stem attached via [noteheadA]'s
  /// `stemUpSE` anchor (S4).
  final PitchedNoteElement noteA;

  /// Note A's notehead leaf — the cross-reference target for the slur and the
  /// anchor host for the stem.
  final GlyphElement noteheadA;

  /// The stem on note A, placed at [noteheadA]'s `stemUpSE` anchor.
  final LineElement stemA;

  /// Note B (staff1 m1, at `(8,1)`) — carries a sharp accidental and is the
  /// slur's other endpoint.
  final PitchedNoteElement noteB;

  /// Note B's notehead leaf.
  final GlyphElement noteheadB;

  /// The sharp accidental on note B (`accidentalSharp`).
  final GlyphElement noteBAccidental;

  /// Note C (staff2 m1, at `(5,3)`).
  final PitchedNoteElement noteC;

  /// The eighth note (staff1 m2, at `(13,2)`) — notehead + stem + flag, the
  /// flag placed via [eighthNoteFlag]'s `stemUpNW` anchor (S4).
  final PitchedNoteElement eighthNote;

  /// The flag leaf on the eighth note (`flag8thUp`).
  final GlyphElement eighthNoteFlag;

  /// The full rest (staff2 m2, at `(13,14)`) — `restWhole`.
  final RestElement fullRest;

  /// The placeholder slur spanning A→B (unresolved by default; S5). Resolve
  /// it with [fakeResolveSlur].
  final SlurElement slur;
}

/// Builds the WP1 contract fixture: a 2-staff system, each with two measures
/// (clef + 4/4 time signature + notes/rests), a stem and a flag placed via
/// notehead/flag anchors (S4), and a deferred slur (S5), arranged vertically
/// (S6) — all in staff-space units.
///
/// The tree is returned fully built and arranged (staves stacked); the slur
/// is left unresolved for the caller to resolve via [fakeResolveSlur].
Wp1ContractFixture buildWp1ContractFixture() {
  // --- Shared SMUFL anchors (S4: read at build time, table as parameter) ----

  final stemUpSe = glyphAnchors[Glyph.noteheadBlack]!.stemUpSE!;
  final flagStemUpNw = glyphAnchors[Glyph.flag8thUp]!.stemUpNW!;
  assert(stemUpSe == noteheadBlackStemUpSe); // sanity: matches documented value
  assert(flagStemUpNw == flag8thUpStemUpNw);

  // A stem-up stem: from the notehead's stemUpSE anchor, straight up by
  // [stemLength]. Returns (startPoint, endPoint) in the note's local space.
  LineElement stemUpStem() {
    final end = stemUpSe.translate(0, -stemLength);
    return LineElement(
      const NodeTransform.identity(),
      stemUpSe,
      end,
      styling: _blackStroke,
    );
  }

  // --- Staff 1 (treble) -------------------------------------------------

  final noteheadA = GlyphElement(
    const NodeTransform.identity(),
    Glyph.noteheadBlack,
    styling: _blackFill,
  );
  final stemA = stemUpStem();
  final noteA = PitchedNoteElement(
    const NodeTransform(translation: Offset(5, 2)),
    notehead: noteheadA,
    stem: stemA,
  );

  final noteBAccidental = GlyphElement(
    const NodeTransform(translation: Offset(-1.5, 0)),
    Glyph.accidentalSharp,
    styling: _blackFill,
  );
  final noteheadB = GlyphElement(
    const NodeTransform.identity(),
    Glyph.noteheadBlack,
    styling: _blackFill,
  );
  final noteB = PitchedNoteElement(
    const NodeTransform(translation: Offset(8, 1)),
    notehead: noteheadB,
    accidental: noteBAccidental,
  );

  // The slur (S5): unresolved, cross-referencing both noteheads by identity,
  // each with the notehead's stemUpSE anchor as its local anchor.
  final slur = SlurElement(const NodeTransform.identity())
    ..crossReferences = [
      CrossReference(noteheadA, localAnchor: stemUpSe),
      CrossReference(noteheadB, localAnchor: stemUpSe),
    ];

  final timeSignature1 = TimeSignatureElement(
    const NodeTransform(translation: Offset(3, 2)),
    beats: GlyphElement(
      const NodeTransform(translation: Offset(0, -1)),
      Glyph.timeSig4,
      styling: _blackFill,
    ),
    beatType: GlyphElement(
      const NodeTransform(translation: Offset(0, 1)),
      Glyph.timeSig4,
      styling: _blackFill,
    ),
  );

  final staff1Measure1 = MeasureElement(
    const NodeTransform.identity(),
    [
      ColumnElement(const NodeTransform.identity(), [noteA, slur]),
      ColumnElement(const NodeTransform.identity(), [noteB]),
    ],
    GroupElement(
      const NodeTransform.identity(),
      [
        ClefElement(
          const NodeTransform.identity(),
          glyph: GlyphElement(
            const NodeTransform.identity(),
            Glyph.gClef,
            styling: _blackFill,
          ),
        ),
        timeSignature1,
      ],
    ),
  );

  // Eighth note (staff1 measure2): notehead + stem + flag8thUp. The flag is
  // placed at the stem top via its stemUpNW anchor (S4).
  final eighthNoteFlag = GlyphElement(
    NodeTransform(
      translation: stemUpSe.translate(0, -stemLength) - flagStemUpNw,
    ),
    Glyph.flag8thUp,
    styling: _blackFill,
  );
  final eighthNote = PitchedNoteElement(
    const NodeTransform(translation: Offset(1, 2)),
    notehead: GlyphElement(
      const NodeTransform.identity(),
      Glyph.noteheadBlack,
      styling: _blackFill,
    ),
    stem: stemUpStem(),
    flag: eighthNoteFlag,
  );

  final staff1Measure2 = MeasureElement(
    const NodeTransform(translation: Offset(measure2Dx, 0)),
    [ColumnElement(const NodeTransform.identity(), [eighthNote])],
  );

  final staff1 = StaffElement(
    const NodeTransform.identity(),
    1,
    [staff1Measure1, staff1Measure2],
  );

  // --- Staff 2 (bass) ---------------------------------------------------

  final noteheadC = GlyphElement(
    const NodeTransform.identity(),
    Glyph.noteheadBlack,
    styling: _blackFill,
  );
  final noteC = PitchedNoteElement(
    const NodeTransform(translation: Offset(5, 3)),
    notehead: noteheadC,
  );

  final timeSignature2 = TimeSignatureElement(
    const NodeTransform(translation: Offset(3, 2)),
    beats: GlyphElement(
      const NodeTransform(translation: Offset(0, -1)),
      Glyph.timeSig4,
      styling: _blackFill,
    ),
    beatType: GlyphElement(
      const NodeTransform(translation: Offset(0, 1)),
      Glyph.timeSig4,
      styling: _blackFill,
    ),
  );

  final staff2Measure1 = MeasureElement(
    const NodeTransform.identity(),
    [
      ColumnElement(const NodeTransform.identity(), [noteC]),
    ],
    GroupElement(
      const NodeTransform.identity(),
      [
        ClefElement(
          const NodeTransform.identity(),
          glyph: GlyphElement(
            const NodeTransform.identity(),
            Glyph.fClef,
            styling: _blackFill,
          ),
        ),
        timeSignature2,
      ],
    ),
  );

  final fullRest = RestElement(
    const NodeTransform(translation: Offset(1, 2)),
    glyph: GlyphElement(
      const NodeTransform.identity(),
      Glyph.restWhole,
      styling: _blackFill,
    ),
  );

  final staff2Measure2 = MeasureElement(
    const NodeTransform(translation: Offset(measure2Dx, 0)),
    [ColumnElement(const NodeTransform.identity(), [fullRest])],
  );

  final staff2 = StaffElement(
    const NodeTransform.identity(),
    2,
    [staff2Measure1, staff2Measure2],
  );

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
    timeSignature1: timeSignature1,
    timeSignature2: timeSignature2,
    noteA: noteA,
    noteheadA: noteheadA,
    stemA: stemA,
    noteB: noteB,
    noteheadB: noteheadB,
    noteBAccidental: noteBAccidental,
    noteC: noteC,
    eighthNote: eighthNote,
    eighthNoteFlag: eighthNoteFlag,
    fullRest: fullRest,
    slur: slur,
  );
}

/// A trivial fake resolver for the fixture's slur (S5 mechanism; WP6 owns the
/// real curve math).
///
/// Draws a straight [LineElement] between the two cross-references' absolute
/// anchor positions (read from [index] via [crossReferenceAbsoluteOffset]),
/// installs it as the slur's only child, and flips `isResolved` to `true` —
/// mutating the slur **in place** so cross-references / the index keep
/// pointing at it. This proves the S5 mechanism gives a resolver something
/// well-defined to operate on; it is not real slur geometry.
///
/// [index] is the absolute-transform index built by [absoluteTransformIndex]
/// over the slur's tree (the WP3↔resolver contract).
void fakeResolveSlur(
  SlurElement slur,
  Map<Element, Matrix4> index,
) {
  final start = crossReferenceAbsoluteOffset(slur.crossReferences[0], index);
  final end = crossReferenceAbsoluteOffset(slur.crossReferences[1], index);
  slur
    ..elements = [
      LineElement(
        const NodeTransform.identity(),
        start,
        end,
        styling: _blackStroke,
      ),
    ]
    ..isResolved = true;
}
