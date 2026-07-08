import 'dart:ui' show Color, Offset, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:music_notes_2/graphics/generated/glyph_definitions.dart';
import 'package:music_notes_2/graphics/graphics_model/canvas_primitives.dart';
import 'package:music_notes_2/graphics/graphics_model/semantic/semantic.dart';
import 'package:music_notes_2/graphics/graphics_model/styling.dart';
import 'package:music_notes_2/graphics/graphics_model/transform.dart';

/// Unit tests for the WP1-S3 semantic element taxonomy.
///
/// These tests pin the taxonomy contract:
/// - semantic nodes **compose** primitive leaves and are never `GlyphElement`
///   subclasses;
/// - **collections** (`GroupElement`) hold an open, data-driven child list;
///   **composites** (`CompositeElement`) hold a fixed set of *named roles*,
///   codifying arity and keeping the roles addressable by name;
/// - both shapes fold their children's local boxes through the child
///   transforms (S1 local geometry) and expose them via `children`;
/// - a composite has no open child list (the mutable `elements` path throws);
/// - semantic nodes carry **no** per-glyph metadata fields (glyph identity
///   lives at the `GlyphElement` leaves; per-glyph metadata is read via the
///   parameterised free functions in `layout/glyph_metadata.dart`).
void main() {
  const black = Styling(fillColor: Color(0xFF000000));

  /// A glyph leaf registered in `glyphBBoxes`, so its local box is non-empty.
  GlyphElement glyphLeaf(Glyph glyph, [NodeTransform t = const NodeTransform.identity()]) =>
      GlyphElement(t, glyph, styling: black);

  GlyphElement noteheadLeaf([NodeTransform t = const NodeTransform.identity()]) =>
      glyphLeaf(Glyph.noteheadBlack, t);

  LineElement stemLeaf() => LineElement(
        const NodeTransform.identity(),
        Offset.zero,
        const Offset(0, -3),
        styling: const Styling(strokeColor: Color(0xFF000000), strokeWidth: 0.12),
      );

  group('collections: open, data-driven child lists (GroupElement)', () {
    test('structural collections are constructible and are GroupElements', () {
      final nodes = <GroupElement>[
        SystemElement(const NodeTransform.identity()),
        PartElement(const NodeTransform.identity()),
        StaffElement(const NodeTransform.identity(), 1),
        ColumnElement(const NodeTransform.identity()),
        MeasureElement(const NodeTransform.identity()),
        KeySignatureElement(const NodeTransform.identity()),
        BeamElement(const NodeTransform.identity()),
        BarlineElement(const NodeTransform.identity()),
        TieElement(const NodeTransform.identity()),
        SlurElement(const NodeTransform.identity()),
        DynamicElement(const NodeTransform.identity()),
        DirectionElement(const NodeTransform.identity()),
      ];
      for (final node in nodes) {
        expect(node, isA<GroupElement>());
        expect(node, isNot(isA<CompositeElement>()));
        expect(node, isNot(isA<GlyphElement>()));
      }
    });

    test('a GroupElement exposes its open, mutable list via elements', () {
      final leaves = [noteheadLeaf(), noteheadLeaf(const NodeTransform(translation: Offset(2, 0)))];
      final key = KeySignatureElement(const NodeTransform.identity(), leaves);
      expect(key.elements, same(leaves)); // the field, mutable and identical
    });
  });

  group('composites: fixed named roles (CompositeElement)', () {
    test('attribute/event composites are CompositeElements, NOT GroupElements', () {
      final nodes = <CompositeElement>[
        ClefElement(const NodeTransform.identity(), glyph: glyphLeaf(Glyph.gClef)),
        TimeSignatureElement(
          const NodeTransform.identity(),
          beats: glyphLeaf(Glyph.timeSig4),
          beatType: glyphLeaf(Glyph.timeSig4),
        ),
        RestElement(const NodeTransform.identity(), glyph: glyphLeaf(Glyph.restQuarter)),
        PitchedNoteElement(const NodeTransform.identity(), notehead: noteheadLeaf()),
      ];
      for (final node in nodes) {
        expect(node, isA<CompositeElement>());
        expect(node, isA<Element>()); // is-a Element → the free walk works via elements
        expect(node, isNot(isA<GroupElement>())); // composites are not collections
        expect(node, isNot(isA<GlyphElement>()));
      }
    });

    test('a composite exposes its parts by NAME, not as an anonymous list', () {
      final beats = glyphLeaf(Glyph.timeSig3);
      final beatType = glyphLeaf(Glyph.timeSig4);
      final time = TimeSignatureElement(const NodeTransform.identity(),
          beats: beats, beatType: beatType);
      // Roles are addressable and typed.
      expect(time.beats, same(beats));
      expect(time.beatType, same(beatType));
      // elements derives from the roles, in order.
      expect(time.elements, [beats, beatType]);
    });

    test('a composite has no open child list: elements is a derived, read-only view', () {
      final time = TimeSignatureElement(const NodeTransform.identity(),
          beats: glyphLeaf(Glyph.timeSig3), beatType: glyphLeaf(Glyph.timeSig4));
      // There is no `elements` setter (unlike GroupElement): `elements` is a
      // fresh derived list each read, not a stored mutable field. (Assigning
      // `time.elements = ...` would not even compile.)
      expect(identical(time.elements, time.elements), isFalse);
    });

    test('a note composite orders its named roles in draw order', () {
      final ledger = LineElement(const NodeTransform(translation: Offset(0, 1)),
          const Offset(-0.5, 0), const Offset(1.5, 0),
          styling: const Styling(strokeColor: Color(0xFF000000), strokeWidth: 0.16));
      final accidental = glyphLeaf(Glyph.accidentalFlat, const NodeTransform(translation: Offset(-1.5, 0)));
      final head = noteheadLeaf();
      final stem = stemLeaf();
      final dot = glyphLeaf(Glyph.augmentationDot, const NodeTransform(translation: Offset(1.5, 0)));
      final note = PitchedNoteElement(
        const NodeTransform.identity(),
        notehead: head,
        stem: stem,
        accidental: accidental,
        dots: [dot],
        ledgerLines: [ledger],
      );
      // ledger(s) → accidental → notehead → stem → flag → dots.
      expect(note.elements, [ledger, accidental, head, stem, dot]);
    });

    test('optional roles default to absent; only the notehead is required', () {
      final note = PitchedNoteElement(const NodeTransform.identity(), notehead: noteheadLeaf());
      expect(note.stem, isNull);
      expect(note.flag, isNull);
      expect(note.accidental, isNull);
      expect(note.dots, isEmpty);
      expect(note.ledgerLines, isEmpty);
      expect(note.elements.length, 1);
    });
  });

  group('local geometry: composing nodes fold their children', () {
    test('a composite folds its role leaves through their child transforms', () {
      // notehead at identity + a dot translated to (2,0): the box widens.
      final note = PitchedNoteElement(
        const NodeTransform.identity(),
        notehead: noteheadLeaf(),
        dots: [glyphLeaf(Glyph.augmentationDot, const NodeTransform(translation: Offset(2, 0)))],
      );
      final headOnly = noteheadLeaf().localBoundingBox;
      expect(note.localBoundingBox.width, greaterThan(headOnly.width));
    });

    test('a single-role composite equals its leaf box (within fp tolerance)', () {
      final clef = ClefElement(const NodeTransform.identity(), glyph: glyphLeaf(Glyph.gClef));
      final leaf = glyphLeaf(Glyph.gClef).localBoundingBox;
      // The composite folds the leaf through its (identity) child transform,
      // so the result matches the leaf box up to floating-point rounding.
      expect(clef.localBoundingBox.left, moreOrLessEquals(leaf.left));
      expect(clef.localBoundingBox.top, moreOrLessEquals(leaf.top));
      expect(clef.localBoundingBox.right, moreOrLessEquals(leaf.right));
      expect(clef.localBoundingBox.bottom, moreOrLessEquals(leaf.bottom));
      expect(clef.localBoundingBox, isNot(equals(Rect.zero)));
    });
  });

  group('structural collections: measure/column composition', () {
    test('MeasureElement exposes its columns and optional attributes group', () {
      final attributes = GroupElement(
        const NodeTransform.identity(),
        [ClefElement(const NodeTransform.identity(), glyph: glyphLeaf(Glyph.gClef))],
      );
      final columns = [
        ColumnElement(const NodeTransform.identity()),
        ColumnElement(const NodeTransform(translation: Offset(3, 0))),
      ];
      final measure = MeasureElement(const NodeTransform.identity(), columns, attributes);

      expect(measure.columns, columns);
      expect(measure.attributes, same(attributes));
      expect(measure.elements.first, same(attributes));
      expect(measure.elements.skip(1).toList(), columns);
    });

    test('StaffElement carries its 1-based staffNumber', () {
      expect(StaffElement(const NodeTransform.identity(), 1).staffNumber, 1);
      expect(StaffElement(const NodeTransform.identity(), 2).staffNumber, 2);
    });
  });

  group('typed containers restrict their children', () {
    test('SystemElement exposes only PartElement children via parts', () {
      final p1 = PartElement(const NodeTransform.identity());
      final p2 = PartElement(const NodeTransform.identity());
      final system = SystemElement(const NodeTransform.identity(), [p1, p2]);
      expect(system.parts, [p1, p2]);
      expect(system.elements, same(system.parts));
    });

    test('the inherited elements setter throws ArgumentError on a wrong-typed child', () {
      final system = SystemElement(const NodeTransform.identity());
      expect(
        () => system.elements = [
          PartElement(const NodeTransform.identity()),
          StaffElement(const NodeTransform.identity(), 1),
        ],
        throwsArgumentError,
      );
      expect(system.parts, isEmpty);
    });

    test('a typed container is still a GroupElement for tree-walks', () {
      final system = SystemElement(
        const NodeTransform.identity(),
        [PartElement(const NodeTransform.identity())],
      );
      expect(system, isA<GroupElement>());
      expect(system, isA<Element>());
      expect(system.localBoundingBox, Rect.zero);
    });
  });

  group('glyph-knowledge contract: nodes hold glyph identity only', () {
    test('the only glyph fact in the tree is the identity on a GlyphElement leaf', () {
      final note = PitchedNoteElement(const NodeTransform.identity(), notehead: noteheadLeaf());
      // The glyph identity lives on the leaf (a named role), not the note.
      expect(note.notehead.glyph, Glyph.noteheadBlack);
      expect(note, isNot(isA<GlyphElement>()));
    });
  });

  group('context-dependent types hold cross-references (S5 mechanism, WP6 math)', () {
    test('tie/slur/beam/dynamic/direction are CrossReferenceElements, unresolved by default', () {
      for (final node in [
        BeamElement(const NodeTransform.identity()),
        TieElement(const NodeTransform.identity()),
        SlurElement(const NodeTransform.identity()),
        DynamicElement(const NodeTransform.identity()),
        DirectionElement(const NodeTransform.identity()),
      ]) {
        expect(node, isA<CrossReferenceElement>());
        expect(node, isA<GroupElement>()); // CrossReferenceElement is-a GroupElement
        expect(node, isNot(isA<CompositeElement>()));
        expect(node, isNot(isA<GlyphElement>()));
        // S5: a freshly built cross-reference element is unresolved and carries
        // an empty cross-reference list.
        expect(node.isResolved, isFalse);
        expect(node.crossReferences, isEmpty);
      }
    });

    test('an unresolved cross-reference element is inspectable without throwing (S5)', () {
      // Reading geometry of an unresolved node returns tentative (current)
      // values so a layout pass may inspect it for assessment — the getters do
      // not throw. Unresolved geometry is refused only at the render boundary.
      final slur = SlurElement(const NodeTransform.identity());
      expect(slur.elements, isEmpty); // empty backing list, no throw
      expect(slur.localBoundingBox, Rect.zero); // folds the empty list, no throw
    });
  });
}
