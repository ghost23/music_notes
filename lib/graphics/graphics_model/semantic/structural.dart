import '../canvas_primitives.dart' show Element, GroupElement;
import '../transform.dart';

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
/// fleshed out in S6; this story only declares the nodes exist and carry
/// minimal structural identity. See the taxonomy table in
/// `docs/wp1/S3-element-taxonomy.md`.

/// A rendered **system**: the top structural node holding one or more parts on
/// a single line.
///
/// **Source:** `Score` — for the first milestone one [SystemElement] is built
/// per score (one system per line); multi-system/page layout is WP7.
/// **Composes:** [PartElement] children only.
/// **Layout fields:** none for the first milestone; S6 adds vertical-
/// arrangement fields (staff spacing, brace/bracket grouping).
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
/// **Layout fields:** none for the first milestone; S6 may add part-level
/// grouping/brace metadata.
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
  ]);

  /// The 1-based MusicXML staff number this node represents.
  final int staffNumber;

  /// The measures on this staff, in order. The live list; appending a
  /// [MeasureElement] is type-checked at compile time.
  List<MeasureElement> get measures => super.elements as List<MeasureElement>;

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
/// (`ClefElement`/`KeySignatureElement`/`TimeSignatureElement`) followed by
/// the measure's [ColumnElement]s. This mirrors the existing
/// `noteGrid` + `attributesColumn` split, expressed as typed fields.
/// **Layout fields:** [columns] and [attributes] (structural composition of
/// children); no musical-concept data is stored on the measure itself.
class MeasureElement extends GroupElement {
  MeasureElement(
    super.transform, [
    List<ColumnElement> super.columns = const [],
    this.attributes,
  ]);

  /// Optional leading group holding the measure's clef/key/time attribute
  /// elements (`null` when the measure carries no attribute change).
  final GroupElement? attributes;

  /// The vertical columns (the "note grid") of this measure. Each column
  /// groups the events that share a time-slice across the staves.
  List<ColumnElement> get columns => super.elements as List<ColumnElement>;

  @override
  List<Element> get elements => [
        if (attributes != null) attributes!,
        ...columns,
      ];

  @override
  set elements(List<Element> value) {
    for (final e in value) {
      if (e is! ColumnElement) {
        throw ArgumentError(
          'StaffElement only accepts ColumnElement children; got ${e.runtimeType}.',
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
/// resolution (see `render/measure.dart::createGridForMeasure` for the existing
/// derivation). It is listed here so coverage is auditable.
/// **Composes:** the simultaneous event elements ([PitchedNoteElement],
/// [RestElement], `BarlineElement`, …).
/// **Layout fields:** none for the first milestone; the division offset /
/// time-slice that defines the column is a WP5 horizontal-spacing input and is
/// not stored on the node (it is implied by the column's position in
/// [MeasureElement.columns]).
class ColumnElement extends GroupElement {
  ColumnElement(super.transform, [super.elements]);
}
