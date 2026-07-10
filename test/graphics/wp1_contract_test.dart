import 'dart:ui' show Offset, Rect;

import 'package:flutter/painting.dart' show MatrixUtils;
import 'package:flutter_test/flutter_test.dart';
import 'package:music_notes_2/graphics/generated/glyph_definitions.dart'
    show Glyph;
import 'package:music_notes_2/graphics/graphics_model/canvas_primitives.dart'
    show Element, GlyphElement, LineElement;
import 'package:music_notes_2/graphics/graphics_model/semantic/semantic.dart';
import 'package:music_notes_2/graphics/layout/cross_references.dart'
    show absoluteTransformIndex, unresolvedElements;
import 'package:music_notes_2/graphics/layout/geometry.dart'
    show absoluteBoundingBox;
import 'package:music_notes_2/graphics/layout/glyph_metadata.dart'
    show absoluteAnchorOffset;
import 'package:music_notes_2/graphics/layout/system.dart'
    show staffAbsoluteOrigin, systemVerticalExtent;

import 'package:music_notes_2/graphics/wp1_contract_fixture.dart';

/// WP1 — the contract-validation capstone (now a musically-faithful grand
/// staff; see `docs/wp1/test.png`).
///
/// These tests drive the shared [buildWp1ContractFixture] and assert that S1–S6
/// compose into a usable contract: per-staff absolute positions (S6), the
/// system's composed bounding box (S1), a stem placed via a notehead anchor
/// (S4), the **deferred staff lines** discovered by traversal and completed by
/// [resolveStaffLines] (S5), the taxonomy (S3), and scale-free styling (S2).
///
/// Expected geometry is derived from the fixture's own handles/constants where
/// possible (so the assertions track the builder), with the hand-computed
/// values documented in comments.
void main() {
  /// Matches a [Rect] field-by-field within [epsilon] (glyph bboxes use real
  /// SMUFL decimals, so a tiny fp tolerance is used).
  Matcher rectCloseTo(Rect expected, {double epsilon = 1e-9}) =>
      predicate<Rect>(
        (Rect r) =>
            (r.left - expected.left).abs() <= epsilon &&
            (r.top - expected.top).abs() <= epsilon &&
            (r.right - expected.right).abs() <= epsilon &&
            (r.bottom - expected.bottom).abs() <= epsilon,
        'a rect close to $expected within $epsilon',
      );

  /// Matches an [Offset] within [epsilon].
  Matcher offsetCloseTo(Offset expected, {double epsilon = 1e-9}) =>
      predicate<Offset>(
        (Offset o) =>
            (o.dx - expected.dx).abs() <= epsilon &&
            (o.dy - expected.dy).abs() <= epsilon,
        'an offset close to $expected within $epsilon',
      );

  /// A fresh fixture per test (so the staff-line-resolution test can mutate
  /// without affecting others).
  Wp1ContractFixture build() => buildWp1ContractFixture();

  group('S6: per-staff absolute vertical positions', () {
    test('staff origins via the S5 absolute-transform index', () {
      final f = build();
      final index = absoluteTransformIndex(f.system);
      // staff1 dy = 0; staff2 dy = 12 (default inter-staff distance).
      expect(staffAbsoluteOrigin(f.staff1, index), offsetCloseTo(Offset.zero));
      expect(staffAbsoluteOrigin(f.staff2, index),
          offsetCloseTo(const Offset(0, expectedStaff2Dy)));
    });

    test('note & rest absolute origins compose through the staff transforms', () {
      final f = build();
      final index = absoluteTransformIndex(f.system);
      Offset abs(Element e) =>
          MatrixUtils.transformPoint(index[e]!, Offset.zero);
      // halfNoteG (5.5,3) on staff1 (dy=0); halfNoteA (8.5,2.5);
      // trebleWholeNote (2,0) in staff1 m2 (dx=11) → (13,0);
      // bassWholeNote (5.5,2) on staff2 (dy=12) → (5.5,14);
      // wholeRest (2.5,1) in staff2 m2 (dx=11, dy=12) → (13.5,13).
      expect(abs(f.halfNoteG), offsetCloseTo(const Offset(5.5, 3)));
      expect(abs(f.halfNoteA), offsetCloseTo(const Offset(8.5, 2.5)));
      expect(abs(f.trebleWholeNote), offsetCloseTo(const Offset(13, 0)));
      expect(abs(f.bassWholeNote), offsetCloseTo(const Offset(5.5, 14)));
      expect(abs(f.wholeRest), offsetCloseTo(const Offset(13.5, 13)));
    });
  });

  group('S1: the system\'s composed bounding box', () {
    test('matches the hand-computed rect (real glyph bboxes + staff lines)', () {
      final f = build();
      resolveAllStaffLines(f); // rendered state: staff lines span the content
      final box = absoluteBoundingBox(f.system);
      // left = 0      (staff lines start at the staff origin x = 0);
      // top  = −1.392 (gClef NE.y −4.392 at its origin y = 3);
      // right = 16.4  (final barline thick segment: m2 dx 11 + 5 + separation 0.4);
      // bottom = 16   (staff2 line region: dy 12 + 4).
      expect(box, rectCloseTo(const Rect.fromLTRB(0, -1.392, 16.4, 16)));
    });

    test('systemVerticalExtent agrees with the bounding-box height', () {
      final f = build();
      resolveAllStaffLines(f);
      expect(systemVerticalExtent(f.system),
          absoluteBoundingBox(f.system).height);
      // height = 16 − (−1.392) = 17.392
      expect(systemVerticalExtent(f.system), closeTo(17.392, 1e-9));
    });
  });

  group('S4: a stem placed via a notehead anchor', () {
    test('the half note\'s stemUpSE anchor resolves to the expected absolute point',
        () {
      final f = build();
      final index = absoluteTransformIndex(f.system);
      // halfNoteG absolute origin (5.5,3); stemUpSE local (1.18,−0.168)
      // → absolute (6.68, 2.832).
      final anchorAbs = absoluteAnchorOffset(
        f.halfNoteG.notehead,
        noteheadHalfStemUpSe,
        parentAbsolute: index[f.halfNoteG],
      );
      expect(anchorAbs, offsetCloseTo(const Offset(6.68, 2.832)));
    });

    test('the stem\'s start lands on that anchor and it extends up by stemLength',
        () {
      final f = build();
      final index = absoluteTransformIndex(f.system);
      final stemAbs = index[f.halfNoteGStem]!;
      final startAbs =
          MatrixUtils.transformPoint(stemAbs, f.halfNoteGStem.startPoint);
      final endAbs =
          MatrixUtils.transformPoint(stemAbs, f.halfNoteGStem.endPoint);
      // Start == the notehead's stemUpSE absolute (proves attachment).
      expect(startAbs, offsetCloseTo(const Offset(6.68, 2.832)));
      // End is stemLength (3.5) up (−y) from the anchor.
      expect(endAbs, offsetCloseTo(const Offset(6.68, 2.832 - stemLength)));
    });
  });

  group('S3: taxonomy (clefs, time signatures, notes, rest, barlines)', () {
    test('each staff\'s first measure carries a clef and a 4/4 time signature',
        () {
      final f = build();
      expect(f.trebleClef.glyph.glyph, Glyph.gClef);
      expect(f.bassClef.glyph.glyph, Glyph.fClef);
      for (final ts in [f.timeSignature1, f.timeSignature2]) {
        expect(ts, isA<TimeSignatureElement>());
        expect(ts.beats.glyph, Glyph.timeSig4);
        expect(ts.beatType.glyph, Glyph.timeSig4);
        expect(ts.elements, [ts.beats, ts.beatType]);
      }
    });

    test('whole notes and a whole rest use the right glyphs', () {
      final f = build();
      expect(f.trebleWholeNote.notehead.glyph, Glyph.noteheadWhole);
      expect(f.trebleWholeNote.stem, isNull); // whole notes are stemless
      expect(f.bassWholeNote.notehead.glyph, Glyph.noteheadWhole);
      expect(f.wholeRest, isA<RestElement>());
      expect(f.wholeRest.glyph.glyph, Glyph.restWhole);
      expect(f.wholeRest.elements, [f.wholeRest.glyph]);
    });

    test('the sharped half note carries a sharp accidental drawn before the head',
        () {
      final f = build();
      expect(f.halfNoteA.accidental, same(f.halfNoteASharp));
      expect(f.halfNoteASharp.glyph, Glyph.accidentalSharp);
      expect(f.halfNoteA.elements.indexOf(f.halfNoteASharp),
          lessThan(f.halfNoteA.elements.indexOf(f.halfNoteA.notehead)));
    });

    test('each measure is closed by a barline; the last is a final barline', () {
      final f = build();
      expect(f.barlines.length, 4);
      expect(f.barlines, everyElement(isA<BarlineElement>()));
      // Every measure carries its trailing barline role.
      for (final staff in [f.staff1, f.staff2]) {
        expect(staff.measures.first.barline, isNotNull);
        expect(staff.measures.last.barline, isNotNull);
      }
      // A regular barline is a single (thin) segment; a final barline composes
      // two (thin + thick) segments.
      expect(f.staff1.measures.first.barline!.elements.length, 1);
      expect(f.staff1.measures.last.barline!.elements.length, 2);
    });

    test('each staff has two measures; measure2 is offset to the right', () {
      final f = build();
      expect(f.staff1.measures.length, 2);
      expect(f.staff2.measures.length, 2);
      expect(f.staff1.measures.last.transform.translation.dx, measure2Dx);
      expect(f.staff2.measures.last.transform.translation.dx, measure2Dx);
    });
  });

  group('S5: deferred staff lines discovered and resolved', () {
    test('both staves\' staff lines are the only unresolved nodes before resolution',
        () {
      final f = build();
      // Pre-order: staff1.staffLines then staff2.staffLines.
      expect(unresolvedElements(f.system).toList(),
          [f.staff1.staffLines, f.staff2.staffLines]);
      expect(f.staff1.staffLines!.isResolved, isFalse);
      expect(f.staff1.staffLines!.elements, isEmpty); // inspectable while unresolved
    });

    test('resolveStaffLines fills in one line per staff line and flags resolved',
        () {
      final f = build();
      final linesGroup = f.staff1.staffLines!;
      resolveStaffLines(f.staff1);
      expect(linesGroup.isResolved, isTrue);
      expect(linesGroup.elements.length, f.staff1.lineCount); // 5 lines
      expect(linesGroup.elements, everyElement(isA<LineElement>()));
      // Lines are horizontal, at y = 0..4, spanning from the staff origin.
      final first = linesGroup.elements.first as LineElement;
      expect(first.startPoint.dx, 0);
      expect(first.startPoint.dy, first.endPoint.dy); // horizontal
      expect(first.endPoint.dx, greaterThan(0)); // content-driven width
    });

    test('after resolving every staff, traversal reports nothing unresolved', () {
      final f = build();
      resolveAllStaffLines(f);
      expect(unresolvedElements(f.system).toList(), isEmpty);
    });

    test('the staff-lines group stays the same object across resolution', () {
      final f = build();
      final before = f.staff1.staffLines;
      resolveStaffLines(f.staff1);
      expect(identical(f.staff1.staffLines, before), isTrue);
    });
  });

  group('S2: scale-free styling (no Paint / TextStyle / pixel values)', () {
    test('noteheads fill; stems and staff lines stroke with staff-space widths',
        () {
      final f = build();
      resolveStaffLines(f.staff1);
      expect(f.halfNoteG.notehead.styling.hasFill, isTrue);
      expect(f.halfNoteG.notehead.styling.hasStroke, isFalse);
      expect(f.halfNoteGStem.styling.hasStroke, isTrue);
      expect(f.halfNoteGStem.styling.strokeWidth, 0.12); // staff-space
      final staffLine = f.staff1.staffLines!.elements.first;
      expect(staffLine.styling.hasStroke, isTrue);
      expect(staffLine.styling.strokeWidth, 0.13); // staff-space
    });

    test('no drawable leaf carries unresolved (inherit) styling', () {
      // Every drawable leaf the renderer would reach is styled — nothing reaches
      // the renderer with Styling.inherit (which would throw, WP2). Staff lines
      // are resolved first so their leaves exist.
      final f = build();
      resolveAllStaffLines(f);
      final leaves = <Type>[GlyphElement, LineElement];
      final unstyled = <Element>[];
      void walk(Element e) {
        if (leaves.contains(e.runtimeType) && e.styling.isInherit) {
          unstyled.add(e);
        }
        for (final c in e.elements) {
          walk(c);
        }
      }

      walk(f.system);
      expect(unstyled, isEmpty);
    });
  });
}
