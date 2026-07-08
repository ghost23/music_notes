import 'dart:ui' show Color, Offset, Rect;

import 'package:flutter/painting.dart' show MatrixUtils;
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;
import 'package:music_notes_2/graphics/generated/glyph_definitions.dart' show Glyph;
import 'package:music_notes_2/graphics/graphics_model/canvas_primitives.dart'
    show Element, GlyphElement, GroupElement, LineElement;
import 'package:music_notes_2/graphics/graphics_model/semantic/context_dependent.dart'
    show CrossReference, CrossReferenceElement, SlurElement, TieElement;
import 'package:music_notes_2/graphics/graphics_model/semantic/events.dart'
    show PitchedNoteElement;
import 'package:music_notes_2/graphics/graphics_model/styling.dart'
    show Styling;
import 'package:music_notes_2/graphics/graphics_model/transform.dart'
    show NodeTransform;
import 'package:music_notes_2/graphics/layout/cross_references.dart'
    show
        absoluteTransformIndex,
        crossReferenceAbsoluteOffset,
        unresolvedElements;
import 'package:music_notes_2/graphics/layout/geometry.dart'
    show absoluteBoundingBox;

/// Unit tests for the WP1-S5 cross-reference / resolution mechanism.
///
/// S5 ships only the *mechanism* — [CrossReference] handles that cross the
/// tree, an [Element.isResolved] flag any node can carry, a traversal that
/// finds unresolved nodes, an absolute-transform index a resolver consumes,
/// and an inspectable (non-throwing) model. The actual beam/slur/tie/dynamic
/// resolution math is WP6; the resolver used here is a trivial fake that draws
/// a straight line between two cross-references' absolute positions, purely to
/// prove the mechanism gives a resolver something well-defined to operate on.
///
/// All coordinates are staff-space units.
void main() {
  const black = Styling(strokeColor: Color(0xFF000000), strokeWidth: 0.12);

  /// A notehead leaf placed at [tx, ty], registered in `glyphBBoxes`.
  GlyphElement noteheadAt(double tx, double ty) => GlyphElement(
        NodeTransform(translation: Offset(tx, ty)),
        Glyph.noteheadBlack,
        styling: const Styling(fillColor: Color(0xFF000000)),
      );

  /// A trivial fake resolver for a slur/tie: draws a straight line between the
  /// absolute positions of its two cross-references and marks it resolved.
  ///
  /// This is *not* real slur math — it only proves the S5 mechanism gives a
  /// resolver something well-defined to operate on.
  void fakeResolveTwoPointCurve(
    CrossReferenceElement element,
    Map<Element, Matrix4> index,
  ) {
    final start = crossReferenceAbsoluteOffset(element.crossReferences[0], index);
    final end = crossReferenceAbsoluteOffset(element.crossReferences[1], index);
    element
      ..elements = [
        LineElement(const NodeTransform.identity(), start, end, styling: black),
      ]
      ..isResolved = true;
  }

  group('isResolved lives on Element and defaults to true', () {
    test('a plain primitive/collection node is resolved by default', () {
      expect(LineElement(const NodeTransform.identity(), Offset.zero,
              const Offset(0, -3), styling: black).isResolved,
          isTrue);
      expect(noteheadAt(1, 2).isResolved, isTrue);
      expect(GroupElement(const NodeTransform.identity(), const []).isResolved,
          isTrue);
    });

    test('a cross-reference element is unresolved by default', () {
      expect(SlurElement(const NodeTransform.identity()).isResolved, isFalse);
      expect(TieElement(const NodeTransform.identity()).isResolved, isFalse);
    });

    test('any node can be flagged unresolved (e.g. a beamed note stem)', () {
      // Deferral is not a property of a fixed set of types: a primitive leaf a
      // builder leaves tentative is unresolved too. (WP5/WP6 decide *when* a
      // stem is built deferred; WP1 only allows it.)
      final stem = LineElement(const NodeTransform.identity(), Offset.zero,
          const Offset(0, -3), styling: black)
        ..isResolved = false;
      expect(stem.isResolved, isFalse);
      expect(stem, isA<LineElement>());
      expect(stem, isNot(isA<CrossReferenceElement>()));
    });
  });

  group('cross-reference element: state + crossReferences', () {
    test('a freshly built element has an empty cross-reference list', () {
      final slur = SlurElement(const NodeTransform.identity());
      expect(slur.crossReferences, isEmpty);
    });

    test('holds cross-references to targets by identity', () {
      final noteA = noteheadAt(1, 2);
      final noteB = noteheadAt(5, 3);
      const anchor = Offset(1.18, -0.168);
      final slur = SlurElement(const NodeTransform.identity())
        ..crossReferences = [
          CrossReference(noteA, localAnchor: anchor),
          CrossReference(noteB, localAnchor: anchor),
        ];

      expect(slur.crossReferences.length, 2);
      // Cross-references point at the exact node instances (identity, not copies).
      expect(identical(slur.crossReferences[0].target, noteA), isTrue);
      expect(identical(slur.crossReferences[1].target, noteB), isTrue);
      expect(slur.crossReferences[0].localAnchor, anchor);
    });

    test('a cross-reference with no anchor targets the node origin (null localAnchor)', () {
      final staff = GroupElement(const NodeTransform.identity(), const []);
      final ref = CrossReference(staff);
      expect(ref.localAnchor, isNull);
    });
  });

  group('unresolved nodes are inspectable (no throw)', () {
    test('reading elements of an unresolved cross-reference element returns []', () {
      final slur = SlurElement(const NodeTransform.identity());
      expect(slur.elements, isEmpty); // no throw — tentative empty list
    });

    test('reading localBoundingBox of an unresolved element returns Rect.zero', () {
      final slur = SlurElement(const NodeTransform.identity());
      expect(slur.localBoundingBox, Rect.zero); // folds the empty list, no throw
    });

    test('absoluteBoundingBox of a tree containing an unresolved element computes', () {
      // The generic geometry walk reads `elements`/`localBoundingBox`, which are
      // inspectable while unresolved — so it computes over the current (tentative)
      // geometry instead of throwing. The unresolved slur contributes nothing
      // (empty children); the noteheads' box is returned.
      final tree = GroupElement(
        const NodeTransform.identity(),
        [
          noteheadAt(1, 2),
          SlurElement(const NodeTransform.identity()),
          noteheadAt(5, 3),
        ],
      );
      final box = absoluteBoundingBox(tree);
      expect(box, isNot(equals(Rect.zero)));
      expect(box.left, lessThanOrEqualTo(1.0));
      expect(box.right, greaterThanOrEqualTo(5.0));
    });

    test('a deferred stem leaf reports its tentative box (no throw)', () {
      // The motivating case: a beamed note's stem is built with a tentative
      // length and flagged unresolved. Its geometry is still readable for
      // layout assessment.
      final stem = LineElement(const NodeTransform.identity(),
          Offset.zero, const Offset(0, -3), styling: black)
        ..isResolved = false;
      expect(stem.isResolved, isFalse);
      expect(stem.localBoundingBox, Rect.fromLTWH(0, -3, 0, 3));
      expect(stem.elements, isEmpty);
    });

    test('a deferred composite reports its tentative folded box (no throw)', () {
      // A whole note can be flagged unresolved too. Its roles are still listed
      // and folded — tentative, but readable.
      final note = PitchedNoteElement(
        const NodeTransform.identity(),
        notehead: noteheadAt(0, 0),
      )..isResolved = false;
      expect(note.isResolved, isFalse);
      expect(note.elements.length, 1); // the notehead role, tentative
      expect(note.localBoundingBox, isNot(equals(Rect.zero)));
    });
  });

  group('unresolvedElements traversal', () {
    test('yields unresolved nodes in deterministic pre-order', () {
      final slurA = SlurElement(const NodeTransform.identity());
      final slurB = SlurElement(const NodeTransform.identity());
      final tree = GroupElement(
        const NodeTransform.identity(),
        [
          slurA,
          noteheadAt(1, 2),
          GroupElement(const NodeTransform.identity(), [slurB, noteheadAt(3, 4)]),
        ],
      );

      expect(unresolvedElements(tree).toList(), [slurA, slurB]);
    });

    test('a resolved cross-reference element is skipped', () {
      final resolved = SlurElement(const NodeTransform.identity())
        ..elements = [noteheadAt(2, 2)]
        ..isResolved = true;
      final tree = GroupElement(
        const NodeTransform.identity(),
        [resolved, noteheadAt(4, 4)],
      );
      expect(unresolvedElements(tree).toList(), isEmpty);
    });

    test('finds a deferred primitive leaf inside a composite (the stem case)', () {
      // The generalised contract: a primitive leaf a builder left tentative is
      // reported as unresolved, even though it is not a CrossReferenceElement.
      final stem = LineElement(const NodeTransform.identity(), Offset.zero,
          const Offset(0, -3), styling: black)
        ..isResolved = false;
      final note = PitchedNoteElement(
        const NodeTransform.identity(),
        notehead: noteheadAt(0, 0),
        stem: stem,
      ); // note itself stays resolved
      final root = GroupElement(const NodeTransform.identity(), [note]);

      expect(unresolvedElements(root).toList(), [stem]);
    });

    test('finds a deferred composite itself', () {
      final note = PitchedNoteElement(
        const NodeTransform.identity(),
        notehead: noteheadAt(0, 0),
      )..isResolved = false;
      final root = GroupElement(const NodeTransform.identity(), [note]);
      expect(unresolvedElements(root).toList(), [note]);
    });

    test('an empty tree yields nothing', () {
      expect(
        unresolvedElements(
          GroupElement(const NodeTransform.identity(), const []),
        ).toList(),
        isEmpty,
      );
    });
  });

  group('absoluteTransformIndex', () {
    test('records every node keyed by identity, with composed absolute transforms', () {
      // root translate (100, 200); child translate (1, 2); leaf at (0,0).
      final leaf = noteheadAt(0, 0);
      final child = GroupElement(
        const NodeTransform(translation: Offset(1, 2)),
        [leaf],
      );
      final root = GroupElement(
        const NodeTransform(translation: Offset(100, 200)),
        [child],
      );

      final index = absoluteTransformIndex(root);
      expect(index.containsKey(root), isTrue);
      expect(index.containsKey(child), isTrue);
      expect(index.containsKey(leaf), isTrue);

      // child absolute: (0,0) -> (101, 202)
      expect(
        MatrixUtils.transformPoint(index[child]!, const Offset(0, 0)),
        const Offset(101, 202),
      );
      // leaf absolute folds child: (0,0) -> (101, 202) too (leaf has no own offset)
      expect(
        MatrixUtils.transformPoint(index[leaf]!, const Offset(0, 0)),
        const Offset(101, 202),
      );
    });

    test('records an unresolved cross-reference element and recurses through the tree', () {
      // The walk is uniform: it indexes unresolved nodes (their own transform)
      // and continues into their `elements`. An unresolved slur has no children,
      // so it contributes itself and nothing below it.
      final slur = SlurElement(const NodeTransform.identity());
      final root = GroupElement(
        const NodeTransform(translation: Offset(10, 0)),
        [noteheadAt(1, 1), slur],
      );

      final index = absoluteTransformIndex(root);
      expect(index.containsKey(slur), isTrue);
      expect(index.length, 3); // root + notehead + slur
    });

    test('indexes tentative children of a deferred composite', () {
      // A deferred note with a tentative stem: the stem is indexed even though
      // the note is unresolved (the walk recurses uniformly).
      final stem = LineElement(const NodeTransform(translation: Offset(0, -1)),
          Offset.zero, const Offset(0, -3), styling: black)
        ..isResolved = false;
      final note = PitchedNoteElement(
        const NodeTransform(translation: Offset(5, 5)),
        notehead: noteheadAt(0, 0),
        stem: stem,
      )..isResolved = false;
      final root = GroupElement(const NodeTransform.identity(), [note]);

      final index = absoluteTransformIndex(root);
      expect(index.containsKey(note), isTrue);
      expect(index.containsKey(stem), isTrue);
      // stem absolute: note translate (5,5) + stem translate (0,-1) = (5,4)
      expect(
        MatrixUtils.transformPoint(index[stem]!, const Offset(0, 0)),
        const Offset(5, 4),
      );
    });

    test('after a target transform mutates in place, a rebuild reflects the new position', () {
      // The identity scheme: mutating a node's transform in place keeps it the
      // same object, so cross-references/index still point at the right node
      // and a rebuilt index reflects the new transform.
      final note = noteheadAt(1, 2);
      final root = GroupElement(const NodeTransform.identity(), [note]);

      var index = absoluteTransformIndex(root);
      expect(
        MatrixUtils.transformPoint(index[note]!, const Offset(0, 0)),
        const Offset(1, 2),
      );

      // Mutate in place — do NOT replace the node object.
      note.transform = note.transform.copyWith(translation: const Offset(10, 20));
      index = absoluteTransformIndex(root);
      expect(
        MatrixUtils.transformPoint(index[note]!, const Offset(0, 0)),
        const Offset(10, 20),
      );
    });
  });

  group('crossReferenceAbsoluteOffset', () {
    test('composes a target absolute transform with a local anchor offset', () {
      final note = noteheadAt(5, 3);
      final root = GroupElement(const NodeTransform.identity(), [note]);
      final index = absoluteTransformIndex(root);

      const anchor = Offset(1.18, -0.168);
      final ref = CrossReference(note, localAnchor: anchor);
      expect(
        crossReferenceAbsoluteOffset(ref, index),
        const Offset(6.18, 2.832),
      );
    });

    test('a cross-reference with no anchor returns the target origin', () {
      final note = noteheadAt(5, 3);
      final root = GroupElement(const NodeTransform.identity(), [note]);
      final index = absoluteTransformIndex(root);

      final ref = CrossReference(note);
      expect(
        crossReferenceAbsoluteOffset(ref, index),
        const Offset(5, 3),
      );
    });

    test('throws StateError when the target is outside the indexed subtree', () {
      final outside = noteheadAt(0, 0);
      final root = GroupElement(
        const NodeTransform.identity(),
        [noteheadAt(1, 1)], // does NOT contain `outside`
      );
      final index = absoluteTransformIndex(root);
      final ref = CrossReference(outside);
      expect(() => crossReferenceAbsoluteOffset(ref, index), throwsStateError);
    });
  });

  group('identity scheme: cross-references survive a target transform mutation', () {
    test('a cross-reference still points at the correct node after its target moves', () {
      final note = noteheadAt(1, 2);
      final slur = SlurElement(const NodeTransform.identity())
        ..crossReferences = [
          CrossReference(note, localAnchor: const Offset(0.5, 0)),
        ];

      var index = absoluteTransformIndex(
        GroupElement(const NodeTransform.identity(), [note]),
      );
      // Before: (1 + 0.5, 2 + 0) = (1.5, 2)
      expect(crossReferenceAbsoluteOffset(slur.crossReferences[0], index),
          const Offset(1.5, 2));

      // Move the target in place — same object.
      note.transform = note.transform.copyWith(translation: const Offset(9, 8));
      index = absoluteTransformIndex(
        GroupElement(const NodeTransform.identity(), [note]),
      );
      // The cross-reference still points at `note` (identity), and the rebuilt
      // index reflects its new transform: (9 + 0.5, 8 + 0) = (9.5, 8).
      expect(identical(slur.crossReferences[0].target, note), isTrue);
      expect(crossReferenceAbsoluteOffset(slur.crossReferences[0], index),
          const Offset(9.5, 8));
    });
  });

  group('fake resolver (mechanism demonstrated end-to-end)', () {
    test('resolving an unresolved element populates geometry and flips isResolved', () {
      final noteA = noteheadAt(1, 2);
      final noteB = noteheadAt(5, 3);
      const anchor = Offset(1.18, -0.168);
      final slur = SlurElement(const NodeTransform.identity())
        ..crossReferences = [
          CrossReference(noteA, localAnchor: anchor),
          CrossReference(noteB, localAnchor: anchor),
        ];
      final root = GroupElement(
        const NodeTransform.identity(),
        [noteA, noteB, slur],
      );

      // Before resolution: the slur is unresolved and reported by the traversal.
      expect(unresolvedElements(root).toList(), [slur]);

      final index = absoluteTransformIndex(root);
      fakeResolveTwoPointCurve(slur, index);

      // After resolution: the slur is resolved, has drawable geometry, and is
      // no longer reported as unresolved.
      expect(slur.isResolved, isTrue);
      expect(slur.elements.length, 1);
      expect(unresolvedElements(root).toList(), isEmpty);

      // The whole tree's geometry now reflects the resolved slur's line.
      final box = absoluteBoundingBox(root);
      expect(box, isNot(equals(Rect.zero)));
      final start = crossReferenceAbsoluteOffset(slur.crossReferences[0], index);
      final end = crossReferenceAbsoluteOffset(slur.crossReferences[1], index);
      expect(box.left, lessThanOrEqualTo(start.dx));
      expect(box.right, greaterThanOrEqualTo(end.dx));
    });

    test('a tie can be resolved the same way (mechanism is type-agnostic)', () {
      final noteA = noteheadAt(0, 0);
      final noteB = noteheadAt(4, 0);
      final tie = TieElement(const NodeTransform.identity())
        ..crossReferences = [CrossReference(noteA), CrossReference(noteB)];
      final root = GroupElement(
        const NodeTransform.identity(),
        [noteA, noteB, tie],
      );

      expect(unresolvedElements(root).toList(), [tie]);
      fakeResolveTwoPointCurve(tie, absoluteTransformIndex(root));
      expect(tie.isResolved, isTrue);
      expect(tie.localBoundingBox, isNot(equals(Rect.zero)));
      expect(unresolvedElements(root).toList(), isEmpty);
    });

    test('a deferred stem leaf can be finalised in place (the general case)', () {
      // Demonstrates that deferral is not exclusive to CrossReferenceElement:
      // a primitive stem flagged unresolved is found by the traversal and
      // finalised by mutating it in place (a WP6 beam pass would do this).
      final stem = LineElement(const NodeTransform.identity(),
          Offset.zero, const Offset(0, -3), styling: black)
        ..isResolved = false;
      final note = PitchedNoteElement(
        const NodeTransform.identity(),
        notehead: noteheadAt(0, 0),
        stem: stem,
      );
      final root = GroupElement(const NodeTransform.identity(), [note]);

      expect(unresolvedElements(root).toList(), [stem]);

      // "Resolve" the stem: set its final endpoints and flip the flag in place.
      stem
        ..startPoint = const Offset(0, -3.5)
        ..endPoint = const Offset(0, -1)
        ..isResolved = true;

      expect(unresolvedElements(root).toList(), isEmpty);
      expect(stem.isResolved, isTrue);
      expect(stem.localBoundingBox, Rect.fromLTWH(0, -3.5, 0, 2.5));
    });
  });
}
