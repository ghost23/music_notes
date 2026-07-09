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

import '../support/wp1_contract_fixture.dart';

/// WP1-S7 — the contract-validation capstone.
///
/// These tests drive the shared [buildWp1ContractFixture] (a hand-built
/// multi-staff scene graph) and assert that S1–S6 compose into a usable
/// contract: per-staff absolute positions (S6), the system's total bounding
/// box (S1), a stem placed via a notehead anchor resolving to the expected
/// absolute point (S4), a deferred slur discovered by traversal and resolved
/// by a fake resolver (S5), and scale-free styling throughout (S2).
///
/// All expected values are hand-computed and documented in the fixture's
/// library doc; the arithmetic is restated in the assertions' comments.
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

  /// The fixture under test, built once per test (each test gets a fresh tree
  /// so the slur-resolution test can mutate without affecting others).
  Wp1ContractFixture build() => buildWp1ContractFixture();

  group('S6: per-staff absolute vertical positions', () {
    test('staff origins via the S5 absolute-transform index', () {
      final f = build();
      final index = absoluteTransformIndex(f.system);
      // staff1 dy = 0; staff2 dy = 12 (default inter-staff distance).
      expect(staffAbsoluteOrigin(f.staff1, index), offsetCloseTo(Offset.zero));
      expect(staffAbsoluteOrigin(f.staff2, index),
          offsetCloseTo(const Offset(0, 12)));
    });

    test('note & rest absolute origins compose through the staff transforms', () {
      final f = build();
      final index = absoluteTransformIndex(f.system);
      // noteA (5,2) on staff1 (dy=0) → (5,2); noteB (8,1) → (8,1);
      // noteC (5,3) on staff2 (dy=12) → (5,15);
      // eighthNote (1,2) in staff1 m2 (dx=12) → (13,2);
      // fullRest (1,2) in staff2 m2 (dy=12, dx=12) → (13,14).
      expect(MatrixUtils.transformPoint(index[f.noteA]!, Offset.zero),
          offsetCloseTo(const Offset(5, 2)));
      expect(MatrixUtils.transformPoint(index[f.noteB]!, Offset.zero),
          offsetCloseTo(const Offset(8, 1)));
      expect(MatrixUtils.transformPoint(index[f.noteC]!, Offset.zero),
          offsetCloseTo(const Offset(5, 15)));
      expect(MatrixUtils.transformPoint(index[f.eighthNote]!, Offset.zero),
          offsetCloseTo(const Offset(13, 2)));
      expect(MatrixUtils.transformPoint(index[f.fullRest]!, Offset.zero),
          offsetCloseTo(const Offset(13, 14)));
    });
  });

  group('S1: the system\'s total bounding box (composed geometry)', () {
    test('matches the hand-computed rect (real glyph bboxes + line regions)', () {
      final f = build();
      final box = absoluteBoundingBox(f.system);
      // top  = −4.392 (gClef NE.y at staff1);
      // bottom = 16   (staff2 line region: 12 + 4);
      // left = −0.02  (fClef SW.x at staff2);
      // right = 15.236 (eighth-note flag right edge: 13 + 1.18 + 1.056).
      expect(box,
          rectCloseTo(const Rect.fromLTRB(-0.02, -4.392, 15.236, 16)));
    });

    test('systemVerticalExtent agrees with the bounding-box height', () {
      final f = build();
      // height = 16 − (−4.392) = 20.392
      expect(systemVerticalExtent(f.system), 20.392);
      expect(systemVerticalExtent(f.system), absoluteBoundingBox(f.system).height);
    });

    test('the bbox is unchanged by slur resolution (the line fits inside)', () {
      final f = build();
      final before = absoluteBoundingBox(f.system);
      final index = absoluteTransformIndex(f.system);
      fakeResolveSlur(f.slur, index);
      final after = absoluteBoundingBox(f.system);
      expect(after, rectCloseTo(before));
    });
  });

  group('S4: a stem placed via a notehead anchor', () {
    test('the notehead\'s stemUpSE anchor resolves to the expected absolute point', () {
      final f = build();
      final index = absoluteTransformIndex(f.system);
      // noteA absolute origin (5,2); stemUpSE local (1.18, −0.168);
      // → absolute (5+1.18, 2−0.168) = (6.18, 1.832).
      final anchorAbs = absoluteAnchorOffset(
        f.noteheadA,
        noteheadBlackStemUpSe,
        parentAbsolute: index[f.noteA],
      );
      expect(anchorAbs, offsetCloseTo(expectedNoteheadAStemUpSeAbsolute));
    });

    test('the stem\'s start point lands exactly on that anchor', () {
      final f = build();
      final index = absoluteTransformIndex(f.system);
      // The stem is a LineElement child of noteA at identity; its startPoint
      // IS the anchor offset. Composed with noteA's absolute transform it
      // must equal the anchor's absolute position — proving attachment.
      final stemAbs = index[f.stemA]!;
      final stemStartAbs =
          MatrixUtils.transformPoint(stemAbs, f.stemA.startPoint);
      expect(stemStartAbs, offsetCloseTo(expectedNoteheadAStemUpSeAbsolute));
      // And the stem extends upward by stemLength (3) from the anchor.
      final stemEndAbs =
          MatrixUtils.transformPoint(stemAbs, f.stemA.endPoint);
      expect(stemEndAbs,
          offsetCloseTo(const Offset(6.18, 1.832 - stemLength)));
    });

    test('note B\'s stemUpSE anchor resolves to its expected absolute point', () {
      final f = build();
      final index = absoluteTransformIndex(f.system);
      // noteB (8,1) + stemUpSE (1.18, −0.168) = (9.18, 0.832).
      final anchorAbs = absoluteAnchorOffset(
        f.noteheadB,
        noteheadBlackStemUpSe,
        parentAbsolute: index[f.noteB],
      );
      expect(anchorAbs, offsetCloseTo(expectedNoteheadBStemUpSeAbsolute));
    });
  });

  group('S4 (second anchor): an eighth-note flag placed via flag.stemUpNW', () {
    test('the flag\'s stemUpNW anchor coincides with the stem top', () {
      final f = build();
      final index = absoluteTransformIndex(f.system);
      // The eighth note (13,2); stem top in note-local space = stemUpSE +
      // (0, −3) = (1.18, −3.168); absolute stem top = (14.18, −1.168).
      // The flag is placed so its stemUpNW (0, 0.04) sits at that stem top;
      // resolving the flag\'s stemUpNW to absolute must give the same point.
      final flagAnchorAbs = absoluteAnchorOffset(
        f.eighthNoteFlag,
        flag8thUpStemUpNw,
        parentAbsolute: index[f.eighthNote],
      );
      expect(flagAnchorAbs, offsetCloseTo(expectedEighthStemTopAbsolute));
    });

    test('the eighth note\'s stem ends exactly at the flag anchor', () {
      final f = build();
      final index = absoluteTransformIndex(f.system);
      final stem = f.eighthNote.stem!;
      final stemEndAbs = MatrixUtils.transformPoint(index[stem]!, stem.endPoint);
      expect(stemEndAbs, offsetCloseTo(expectedEighthStemTopAbsolute));
    });
  });

  group('S3: extended taxonomy (time signature, eighth note, rest, accidental)', () {
    test('each staff\'s first measure carries a 4/4 time signature', () {
      final f = build();
      for (final ts in [f.timeSignature1, f.timeSignature2]) {
        expect(ts, isA<TimeSignatureElement>());
        expect(ts.beats.glyph, Glyph.timeSig4);
        expect(ts.beatType.glyph, Glyph.timeSig4);
        // A time signature is a fixed composite of exactly two numeral roles.
        expect(ts.elements, [ts.beats, ts.beatType]);
      }
    });

    test('the eighth note is a notehead + stem + flag composite', () {
      final f = build();
      expect(f.eighthNote.notehead.glyph, Glyph.noteheadBlack);
      expect(f.eighthNote.stem, isNotNull);
      expect(f.eighthNoteFlag.glyph, Glyph.flag8thUp);
      // Draw order: notehead → stem → flag (see PitchedNoteElement.elements).
      expect(f.eighthNote.elements, contains(f.eighthNote.notehead));
      expect(f.eighthNote.elements, contains(f.eighthNote.stem));
      expect(f.eighthNote.elements, contains(f.eighthNoteFlag));
    });

    test('the second measure of staff2 holds a full (whole) rest', () {
      final f = build();
      expect(f.fullRest, isA<RestElement>());
      expect(f.fullRest.glyph.glyph, Glyph.restWhole);
      expect(f.fullRest.elements, [f.fullRest.glyph]);
    });

    test('note B carries a sharp accidental as a named role', () {
      final f = build();
      expect(f.noteB.accidental, same(f.noteBAccidental));
      expect(f.noteBAccidental.glyph, Glyph.accidentalSharp);
      // The accidental is drawn before the notehead (draw order).
      expect(f.noteB.elements.indexOf(f.noteBAccidental),
          lessThan(f.noteB.elements.indexOf(f.noteheadB)));
    });

    test('each staff has two measures; measure2 is offset to the right', () {
      final f = build();
      expect(f.staff1.measures.length, 2);
      expect(f.staff2.measures.length, 2);
      // measure2 translation.dx = 12 (to the right of measure1\'s content).
      expect(f.staff1.measures.last.transform.translation.dx, measure2Dx);
      expect(f.staff2.measures.last.transform.translation.dx, measure2Dx);
    });
  });

  group('S5: a deferred slur discovered and resolved by a fake resolver', () {
    test('the slur is the only unresolved node before resolution', () {
      final f = build();
      expect(unresolvedElements(f.system).toList(), [f.slur]);
      expect(f.slur.isResolved, isFalse);
      expect(f.slur.elements, isEmpty); // inspectable while unresolved
    });

    test('fakeResolveSlur draws a line between the two anchor absolutes', () {
      final f = build();
      final index = absoluteTransformIndex(f.system);
      fakeResolveSlur(f.slur, index);

      // Resolved in place: the same node, now flagged resolved and carrying
      // one drawable leaf.
      expect(f.slur.isResolved, isTrue);
      expect(f.slur.elements.length, 1);
      final line = f.slur.elements.first as LineElement;
      // (6.18, 1.832) → (9.18, 0.832) — the two stemUpSE absolutes.
      expect(line.startPoint, offsetCloseTo(expectedNoteheadAStemUpSeAbsolute));
      expect(line.endPoint, offsetCloseTo(expectedNoteheadBStemUpSeAbsolute));
    });

    test('after resolution, traversal no longer reports the slur', () {
      final f = build();
      final index = absoluteTransformIndex(f.system);
      fakeResolveSlur(f.slur, index);
      expect(unresolvedElements(f.system).toList(), isEmpty);
    });

    test('the slur stays the same object across resolution (identity-stable)', () {
      final f = build();
      final index = absoluteTransformIndex(f.system);
      final before = f.slur;
      fakeResolveSlur(f.slur, index);
      expect(identical(f.slur, before), isTrue);
    });
  });

  group('S2: scale-free styling (no Paint / TextStyle / pixel values)', () {
    test('noteheads carry a fill color; the stem carries a stroke + width', () {
      final f = build();
      // A notehead is filled (fill-vs-stroke intent derived from color presence).
      expect(f.noteheadA.styling.hasFill, isTrue);
      expect(f.noteheadA.styling.hasStroke, isFalse);
      // The stem is stroked, with a staff-space (not pixel) thickness.
      expect(f.stemA.styling.hasStroke, isTrue);
      expect(f.stemA.styling.strokeWidth, 0.12); // staff-space
      expect(f.stemA.styling.hasFill, isFalse);
    });

    test('no drawable leaf carries unresolved (inherit) styling', () {
      // Every drawable leaf the renderer would reach is styled — the layout
      // phase is the sole source of styling, and nothing reaches the renderer
      // with Styling.inherit (which would throw at the render boundary, WP2).
      final f = build();
      final leaves = <Type>[GlyphElement, LineElement];
      final unstyled = <Element>[];
      void walk(Element e) {
        final isLeaf = leaves.any((t) => t == e.runtimeType);
        if (isLeaf && e.styling.isInherit) unstyled.add(e);
        for (final c in e.elements) {
          walk(c);
        }
      }
      walk(f.system);
      expect(unstyled, isEmpty); // clefs, noteheads, stem, slur line all styled
    });
  });
}
