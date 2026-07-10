import 'dart:ui' show Rect;

import '../canvas_primitives.dart' show Element, GroupElement, LineElement;
import 'separators.dart' show BarlineElement;

/// The number of lines in a standard staff (SMUFL convention: 5 lines).
const int staffLineCount = 5;

/// The height (top line to bottom line) of a staff with [lineCount] lines, in
/// staff-space units: `lineCount - 1`.
///
/// The staff lines sit at `y = 0, 1, …, lineCount - 1` in a staff's local
/// space — the line spacing is 1 staff space *by definition* (it is the
/// staff-space unit itself) — so the top line is at the local origin (`y = 0`)
/// and the bottom line at `y = lineCount - 1`. A standard 5-line staff is thus
/// `4` staff spaces tall (1 em = 4 staff spaces = 1 staff height), matching
/// the legacy renderer's `paintStaffLines` (lines drawn at `lS * 0..4` where
/// `lS` is one staff space).
///
/// This is a **derived** value — a function of the line count, not an
/// independent fact — so the height and the line count cannot drift apart.
/// It defaults to the standard [staffLineCount] (5); a [StaffElement] carries
/// its own [StaffElement.lineCount] and derives its [StaffElement.staffLineRegion]
/// via this function, so a non-standard line count (e.g. a 1-line or 6-line
/// staff for percussion/tab) yields the correct region.
///
/// Throws [ArgumentError] if [lineCount] is less than 1 (a staff must have at
/// least one line) — per the exceptions-over-null principle.
double staffHeightInStaffSpaces([int lineCount = staffLineCount]) {
  if (lineCount < 1) {
    throw ArgumentError('A staff must have at least 1 line; got $lineCount.');
  }
  return (lineCount - 1).toDouble();
}

/// Structural semantic nodes — the scene-graph skeleton that arranges the
/// music vertically and horizontally (WP1-S3).
///
/// Nesting for the first milestone (one multi-staff system):
///
///     SystemElement
///       └─ PartElement
///            └─ StaffElement            (one per staff in the part)
///                 └─ MeasureElement
///                      ├─ attributes (GroupElement of Clef/Key/Time)
///                      └─ ColumnElement (× n)   ← simultaneous events
///
/// The vertical-arrangement behaviour (how staves are stacked and spaced) is
/// fleshed out in S6 via the free functions in `layout/system.dart`; this
/// story (S3) only declares the nodes exist and carry minimal structural
/// identity. See the taxonomy table in `docs/wp1/S3-element-taxonomy.md`.

/// A rendered **system**: the top structural node holding one or more parts on
/// a single line.
///
/// **Source:** `Score` — for the first milestone one [SystemElement] is built
/// per score (one system per line); multi-system/page layout is WP7.
/// **Composes:** [PartElement] children only.
/// **Layout fields:** none for the first milestone; the system's vertical
/// extent is computed from its staves' transforms by the free functions in
/// `layout/system.dart` (S6). Brace/bracket grouping glyphs are a later WP.
///
/// This is a **typed container**: the typed constructor and the [parts]
/// accessor are compile-time-checked to hold only [PartElement] children. The
/// inherited mutable [GroupElement.elements] path is kept open for builders
/// but validates at runtime — assigning a list containing a non-[PartElement]
/// throws [ArgumentError] (per exceptions-over-null). This preserves
/// `is-a` [GroupElement] so the free geometry/render functions keep working
/// unchanged.
class SystemElement extends GroupElement {
  SystemElement(super.transform, [List<PartElement> super.parts = const []]);

  /// The parts in this system, in order. The live list; appending a
  /// [PartElement] is type-checked at compile time.
  List<PartElement> get parts => super.elements as List<PartElement>;

  @override
  set elements(List<Element> value) {
    for (final e in value) {
      if (e is! PartElement) {
        throw ArgumentError(
          'SystemElement only accepts PartElement children; got ${e.runtimeType}.',
        );
      }
    }
    super.elements
      ..clear()
      ..addAll(value.cast<PartElement>());
  }
}

/// One **part** within a system (e.g. the piano part in a grand staff).
///
/// **Source:** `Part`.
/// **Composes:** [StaffElement] children only (a multi-staff part owns one
/// [StaffElement] per staff declared by `Attributes.staves`).
/// **Layout fields:** none for the first milestone; the staves' vertical
/// transforms are set by `arrangeStavesVertical` in `layout/system.dart` (S6).
/// Part-level grouping/brace metadata is a later WP.
///
/// This is a **typed container**: the typed constructor and the [staves]
/// accessor are compile-time-checked to hold only [StaffElement] children.
/// The inherited mutable [GroupElement.elements] path is kept open for
/// builders but validates at runtime — assigning a list containing a
/// non-[StaffElement] throws [ArgumentError].
class PartElement extends GroupElement {
  PartElement(super.transform, [List<StaffElement> super.staves = const []]);

  /// The staves in this part, in order. The live list; appending a
  /// [StaffElement] is type-checked at compile time.
  List<StaffElement> get staves => super.elements as List<StaffElement>;

  @override
  set elements(List<Element> value) {
    for (final e in value) {
      if (e is! StaffElement) {
        throw ArgumentError(
          'PartElement only accepts StaffElement children; got ${e.runtimeType}.',
        );
      }
    }
    super.elements
      ..clear()
      ..addAll(value.cast<StaffElement>());
  }
}

/// One **staff** of a part.
///
/// **Source:** `Attributes.staves` (the count of staves in the part) together
/// with the `staff` field carried by `Note`/`Direction` and the
/// `staffNumber` on `Clef`.
/// **Composes:** its slice of the music — [MeasureElement] children only for
/// the first milestone (the exact staff/measure nesting is finalised in S6).
/// **Layout field:** [staffNumber] — the 1-based MusicXML staff number, the
/// structural identity of this staff. It mirrors the data model directly and
/// does not presuppose a particular nesting (so S6 is free to arrange staves
/// without re-deriving the number from sibling position).
///
/// ## Local origin & staff-line region (WP1-S6)
///
/// A staff node's **local origin** is its top line at `x = 0, y = 0`. The
/// **staff-line region** — the vertical span of its [lineCount] staff lines —
/// is `y ∈ [0, staffHeightInStaffSpaces(lineCount)]` (a standard 5-line staff:
/// `[0, 4]` staff spaces; see [staffLineRegion]). A note's staff-relative Y
/// therefore maps into system space purely through S1 transform composition:
/// a note on the middle line sits at local `y = 2`, and composing the staff's
/// (then the part's, then the system's) transform places it absolutely. No
/// separate positioning mechanism is involved.
///
/// The staff-line region contributes to [localBoundingBox] so that a staff's
/// own vertical extent is truthfully reported even before any content
/// (measures/notes) is attached — which lets the system's total vertical
/// extent be computed as a bounding box via S1's [absoluteBoundingBox]
/// (see `layout/system.dart`). The region's *horizontal* extent is
/// content-driven (the staff lines span the width of the music, owned by
/// descendants), so [staffLineRegion] carries only the vertical span (width 0)
/// and is unioned with descendants' boxes in [localBoundingBox].
///
/// This is a **typed container**: the typed constructor and the [measures]
/// accessor are compile-time-checked to hold only [MeasureElement] children.
/// The inherited mutable [GroupElement.elements] path is kept open for
/// builders but validates at runtime — assigning a list containing a
/// non-[MeasureElement] throws [ArgumentError].
class StaffElement extends GroupElement {
  StaffElement(
    super.transform,
    this.staffNumber, [
    List<MeasureElement> super.measures = const [],
    this.lineCount = staffLineCount,
  ]) : assert(lineCount >= 1, 'A staff must have at least 1 line; got $lineCount.');

  /// The 1-based MusicXML staff number this node represents.
  final int staffNumber;

  /// The number of staff lines this staff has. Defaults to the SMUFL standard
  /// [staffLineCount] (5); a non-standard count may be passed for a 1-line or
  /// 6-line staff (e.g. percussion / tab). MusicXML expresses this via
  /// `<staff-details><staff-lines>` (not yet parsed by the current parser; the
  /// field is present so the staff's [staffLineRegion] is genuinely per-staff
  /// rather than a global constant — see `docs/wp1/S6-multi-staff-containers.md`).
  final int lineCount;

  /// The vertical span of this staff's staff lines in local staff-space:
  /// `Rect.fromLTWH(0, 0, 0, staffHeightInStaffSpaces(lineCount))` — top line
  /// at the local origin (`y = 0`), bottom line at
  /// `y = staffHeightInStaffSpaces(lineCount)` (a 5-line staff: `y = 4`).
  ///
  /// The width is 0 because the staff lines' *horizontal* extent is
  /// content-driven (the lines span the width of the music, which is owned by
  /// this staff's [MeasureElement] descendants); [localBoundingBox] unions this
  /// region with the descendants' boxes to produce the staff's full local
  /// extent. Reading this getter on an empty staff returns just the line span.
  Rect get staffLineRegion =>
      Rect.fromLTWH(0, 0, 0, staffHeightInStaffSpaces(lineCount));

  /// The measures on this staff, in order. The live list; appending a
  /// [MeasureElement] is type-checked at compile time.
  List<MeasureElement> get measures => super.elements as List<MeasureElement>;

  /// The staff's drawable staff-line primitives — one [LineElement] per line —
  /// or `null` before they are built.
  ///
  /// ## Why this is a *deferred* role (WP1-S5)
  ///
  /// A staff line's vertical position is fixed (`y = 0 … lineCount − 1`), but
  /// its **horizontal length is content-driven**: the lines span the full width
  /// of the music, which is only known once this staff's measures are laid out
  /// (see [staffLineRegion], whose width is deliberately `0`). So the lines are
  /// modelled as a **deferred** node: a builder attaches an *unresolved*
  /// [GroupElement] here (`isResolved == false`, empty), and a resolver fills in
  /// the [LineElement]s and flips `isResolved` once the content width is known —
  /// exactly the S5 mechanism (any node may be unresolved, not just
  /// cross-references). The renderer refuses the unresolved group until then.
  ///
  /// Computing the width and building the lines is a layout concern (a WP5/WP7
  /// rule); the IR only provides the slot. Drawn **first** (behind the measures)
  /// so notes sit on top of the lines.
  GroupElement? staffLines;

  /// This staff's children in draw order: the [staffLines] group first (behind
  /// the music), then the [measures]. Mirrors [MeasureElement]'s attribute/
  /// column composition — [measures] stays the typed measure list (via
  /// `super.elements`) while the walk sees lines + measures uniformly.
  @override
  List<Element> get elements => [
        if (staffLines != null) staffLines!,
        ...measures,
      ];

  /// The staff's local extent: the union of its 5-line [staffLineRegion] and
  /// its descendants' folded boxes (S1's child-box fold). An empty staff
  /// reports just the line span (`[0, 4]` staff spaces tall); a staff with
  /// content widens/extends to include it.
  @override
  Rect get localBoundingBox {
    final region = staffLineRegion;
    final descendants = super.localBoundingBox; // GroupElement fold; Rect.zero if empty.
    if (descendants == Rect.zero) return region;
    return region.expandToInclude(descendants);
  }

  @override
  set elements(List<Element> value) {
    for (final e in value) {
      if (e is! MeasureElement) {
        throw ArgumentError(
          'StaffElement only accepts MeasureElement children; got ${e.runtimeType}.',
        );
      }
    }
    super.elements
      ..clear()
      ..addAll(value.cast<MeasureElement>());
  }
}

/// One **measure** — a horizontal slice of time spanning all staves of its
/// part.
///
/// **Source:** `Measure`.
/// **Composes:** an optional leading [GroupElement] of attribute elements
/// (`ClefElement`/`KeySignatureElement`/`TimeSignatureElement`), the measure's
/// [ColumnElement]s, and an optional trailing [BarlineElement]. This mirrors
/// the existing `noteGrid` + `attributesColumn` split, expressed as typed
/// fields.
/// **Layout fields:** [columns], [attributes] and [barline] (structural
/// composition of children); no musical-concept data is stored on the measure
/// itself.
class MeasureElement extends GroupElement {
  MeasureElement(
    super.transform, [
    List<ColumnElement> super.columns = const [],
    this.attributes,
    this.barline,
  ]);

  /// Optional leading group holding the measure's clef/key/time attribute
  /// elements (`null` when the measure carries no attribute change).
  final GroupElement? attributes;

  /// Optional trailing barline that closes this measure (`null` when the
  /// measure has no drawn barline). Positioned by its own transform at the
  /// measure's right edge; the barline *style* is encoded by the
  /// [LineElement]/[GlyphElement] leaves it composes, not stored here (see
  /// [BarlineElement]).
  final BarlineElement? barline;

  /// The vertical columns (the "note grid") of this measure. Each column
  /// groups the events that share a time-slice across the staves.
  List<ColumnElement> get columns => super.elements as List<ColumnElement>;

  @override
  List<Element> get elements => [
        if (attributes != null) attributes!,
        ...columns,
        if (barline != null) barline!,
      ];

  @override
  set elements(List<Element> value) {
    for (final e in value) {
      if (e is! ColumnElement) {
        throw ArgumentError(
          'MeasureElement only accepts ColumnElement children; got ${e.runtimeType}.',
        );
      }
    }
    super.elements
      ..clear()
      ..addAll(value.cast<ColumnElement>());
  }
}

/// A **column** — a vertical slice of a measure grouping the events that
/// sound simultaneously across the staves (the "note grid" cell).
///
/// **Source:** not a single `data.dart` type; a column is a *layout-derived*
/// grouping. Its MusicXML counterpart is the set of `MeasureContent` entries
/// that share a division offset within a measure — derived from cumulative
/// `Note.duration` / `Backup` / `Forward` against the `Attributes.divisions`
/// resolution (see `docs/legacy-render/measure.dart::createGridForMeasure`
/// for the existing derivation, archived as WP5 source material). It is listed here so coverage is auditable.
/// **Composes:** the simultaneous event elements ([PitchedNoteElement],
/// [RestElement], `BarlineElement`, …).
/// **Layout fields:** none for the first milestone; the division offset /
/// time-slice that defines the column is a WP5 horizontal-spacing input and is
/// not stored on the node (it is implied by the column's position in
/// [MeasureElement.columns]).
class ColumnElement extends GroupElement {
  ColumnElement(super.transform, [super.elements]);
}
