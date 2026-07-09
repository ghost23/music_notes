import 'dart:ui' show Offset, Rect;

import 'package:flutter/painting.dart' show MatrixUtils;
import 'package:flutter_test/flutter_test.dart';
import 'package:music_notes_2/graphics/graphics_model/canvas_primitives.dart';
import 'package:music_notes_2/graphics/graphics_model/semantic/semantic.dart';
import 'package:music_notes_2/graphics/graphics_model/transform.dart';
import 'package:music_notes_2/graphics/layout/cross_references.dart';
import 'package:music_notes_2/graphics/layout/geometry.dart';
import 'package:music_notes_2/graphics/layout/system.dart';

/// Unit tests for WP1-S6 — multi-staff system container & vertical
/// arrangement.
///
/// These build hand-built `Element` trees (no glyph metadata, no parser) and
/// assert that:
/// - a 2-staff (and 3-staff) system is arranged vertically with the
///   documented inter-staff distance, via transforms on the staff nodes (S1);
/// - a staff-relative point composes into system space (the staff's local
///   origin is its top line; the staff-line region is `[0, 4]` staff spaces);
/// - a free function returns each staff's absolute vertical position (via the
///   S5 absolute-transform index) and the system's total vertical extent (via
///   S1's `absoluteBoundingBox`), both against hand-computed values;
/// - the inter-staff distance is a parameter (custom value changes the
///   offsets and the extent); node identity stays stable across arrangement
///   (mutating transforms in place keeps cross-references/identity valid).
///
/// All coordinates are staff-space units (1 staff space = the SMUFL unit;
/// 4 staff spaces = 1 staff height = 1 em).
void main() {
  /// Matches a [Rect] field-by-field within [epsilon] (default 1e-10).
  Matcher rectCloseTo(Rect expected, {double epsilon = 1e-10}) =>
      predicate<Rect>(
        (Rect r) =>
            (r.left - expected.left).abs() <= epsilon &&
            (r.top - expected.top).abs() <= epsilon &&
            (r.right - expected.right).abs() <= epsilon &&
            (r.bottom - expected.bottom).abs() <= epsilon,
        'a rect close to $expected within $epsilon',
      );

  /// Matches an [Offset] within [epsilon] (default 1e-10).
  Matcher offsetCloseTo(Offset expected, {double epsilon = 1e-10}) =>
      predicate<Offset>(
        (Offset o) =>
            (o.dx - expected.dx).abs() <= epsilon &&
            (o.dy - expected.dy).abs() <= epsilon,
        'an offset close to $expected within $epsilon',
      );

  /// A 2-staff (piano-grand-staff-shaped) system with empty staves.
  /// Staff #1 (top, treble) and staff #2 (bottom, bass), no measures yet.
  (SystemElement, PartElement, StaffElement, StaffElement) twoStaffSystem() {
    final staff1 = StaffElement(const NodeTransform.identity(), 1);
    final staff2 = StaffElement(const NodeTransform.identity(), 2);
    final part = PartElement(const NodeTransform.identity(), [staff1, staff2]);
    final system = SystemElement(const NodeTransform.identity(), [part]);
    return (system, part, staff1, staff2);
  }

  group('staff-line region & local origin (StaffElement)', () {
    test('an empty staff reports its 5-line span as the local bounding box', () {
      final staff = StaffElement(const NodeTransform.identity(), 1);
      expect(staff.lineCount, 5); // defaults to the SMUFL standard
      // 5 lines at y = 0,1,2,3,4 → vertical span [0, 4]; width 0 (content-driven).
      expect(staff.staffLineRegion, Rect.fromLTWH(0, 0, 0, 4));
      expect(staff.localBoundingBox, Rect.fromLTWH(0, 0, 0, 4));
    });

    test('a non-standard lineCount yields the matching region (per-staff)', () {
      // A 6-line staff: lines at y = 0..5 → height 5.
      final six = StaffElement(const NodeTransform.identity(), 1, const [], 6);
      expect(six.lineCount, 6);
      expect(six.staffLineRegion, Rect.fromLTWH(0, 0, 0, 5));
      expect(six.localBoundingBox, Rect.fromLTWH(0, 0, 0, 5));
      // A single-line staff: height 0 (top line == bottom line).
      final one = StaffElement(const NodeTransform.identity(), 1, const [], 1);
      expect(one.staffLineRegion, Rect.fromLTWH(0, 0, 0, 0));
    });

    test('a staff with content unions the line region with descendants', () {
      // A "note" leaf placed at the middle line (y = 2), translated to x = 5,
      // occupying a 1×1 box: descendants' box is (5, 2, 6, 3).
      final note = RectElement(
        const NodeTransform(translation: Offset(5, 2)),
        Rect.fromLTWH(0, 0, 1, 1),
      );
      final staff = StaffElement(const NodeTransform.identity(), 1, [
        // Wrap the leaf in a measure so the typed container accepts it.
        MeasureElement(const NodeTransform.identity(), [
          ColumnElement(const NodeTransform.identity(), [note]),
        ]),
      ]);
      // Union of line region (0,0,0,4) and note box (5,2,6,3) = (0,0,6,4).
      expect(staff.localBoundingBox, rectCloseTo(Rect.fromLTWH(0, 0, 6, 4)));
    });

    test('staffHeightInStaffSpaces is derived from the line count', () {
      // height = lineCount - 1 (lines at y = 0..lineCount-1, spacing 1 staff space).
      expect(staffHeightInStaffSpaces(), 4.0); // default 5-line staff: 5 - 1
      expect(staffHeightInStaffSpaces(5), 4.0);
      expect(staffHeightInStaffSpaces(6), 5.0); // a 6-line staff
      expect(staffHeightInStaffSpaces(1), 0.0); // a single-line staff
      expect(staffLineCount, 5);
      expect(() => staffHeightInStaffSpaces(0), throwsArgumentError);
    });
  });

  group('arrangeStavesVertical: transforms on staff nodes', () {
    test('a 2-staff system: staff 2 offset by the default distance (12)', () {
      final (_, part, staff1, staff2) = twoStaffSystem();
      arrangeStavesVertical(part);
      expect(staff1.transform.translation, Offset.zero);
      expect(staff2.transform.translation, const Offset(0, 12));
      // Scale/rotation untouched.
      expect(staff1.transform.scale, const Offset(1, 1));
      expect(staff1.transform.rotation, 0);
    });

    test('a 3-staff system: offsets accumulate per index', () {
      final staff3 = StaffElement(const NodeTransform.identity(), 3);
      final part = PartElement(const NodeTransform.identity(), [
        StaffElement(const NodeTransform.identity(), 1),
        StaffElement(const NodeTransform.identity(), 2),
        staff3,
      ]);
      arrangeStavesVertical(part);
      final staves = part.staves;
      expect(staves[0].transform.translation.dy, 0);
      expect(staves[1].transform.translation.dy, 12);
      expect(staves[2].transform.translation.dy, 24);
    });

    test('the inter-staff distance is a parameter (custom value)', () {
      final (_, part, staff1, staff2) = twoStaffSystem();
      arrangeStavesVertical(part, interStaffDistance: 10);
      expect(staff1.transform.translation.dy, 0);
      expect(staff2.transform.translation.dy, 10);
    });

    test('each staff\'s X translation is preserved', () {
      final staff1 = StaffElement(
        const NodeTransform(translation: Offset(7, 0)),
        1,
      );
      final staff2 = StaffElement(
        const NodeTransform(translation: Offset(7, 0)),
        2,
      );
      final part = PartElement(const NodeTransform.identity(), [staff1, staff2]);
      arrangeStavesVertical(part);
      expect(staff1.transform.translation, const Offset(7, 0));
      expect(staff2.transform.translation, const Offset(7, 12));
    });

    test('defaultInterStaffDistance = staff height + 2-staff-height gap = 12', () {
      expect(defaultInterStaffDistance, 12.0);
      expect(defaultInterStaffGap, 8.0);
      expect(defaultInterStaffDistance,
          staffHeightInStaffSpaces() + defaultInterStaffGap);
    });
  });

  group('transform composition: a staff-relative point maps into system space', () {
    test('a note on staff 2\'s middle line lands at system y = 12 + 2', () {
      // A "notehead" leaf placed at the middle line: local (0, 2).
      final note = RectElement(
        const NodeTransform(translation: Offset(0, 2)),
        Rect.fromLTWH(0, 0, 1, 1),
      );
      final staff1 = StaffElement(const NodeTransform.identity(), 1);
      final staff2 = StaffElement(
        const NodeTransform.identity(),
        2,
        [
          MeasureElement(const NodeTransform.identity(), [
            ColumnElement(const NodeTransform.identity(), [note]),
          ]),
        ],
      );
      final part =
          PartElement(const NodeTransform.identity(), [staff1, staff2]);
      final system = SystemElement(const NodeTransform.identity(), [part]);
      arrangeStavesVertical(part); // staff2 dy = 12
      // Compose top-down: system(0,0) · part(0,0) · staff2(0,12) · note(0,2).
      // The note's origin maps to system (0, 14).
      final systemAbs = absoluteTransform(system);
      final partAbs = absoluteTransform(part, parentAbsolute: systemAbs);
      final staffAbs = absoluteTransform(staff2, parentAbsolute: partAbs);
      final noteAbs = absoluteTransform(note, parentAbsolute: staffAbs);
      expect(MatrixUtils.transformPoint(noteAbs, Offset.zero),
          offsetCloseTo(const Offset(0, 14)));
      // The system's absolute bounding box spans staff 1's top line (y = 0) to
      // staff 2's bottom line (y = 12 + 4 = 16); the note (y = 14..15) sits
      // inside that span. The line region is reflected via StaffElement's
      // localBoundingBox + absoluteBoundingBox.
      expect(absoluteBoundingBox(system), rectCloseTo(Rect.fromLTWH(0, 0, 1, 16)));
    });

    test('a note on staff 1 maps without any vertical staff offset', () {
      final note = RectElement(
        // bottom line of staff 1 (y = 4)
        const NodeTransform(translation: Offset(3, 4)),
        Rect.fromLTWH(0, 0, 1, 1),
      );
      final staff1 = StaffElement(
        const NodeTransform.identity(),
        1,
        [
          MeasureElement(const NodeTransform.identity(), [
            ColumnElement(const NodeTransform.identity(), [note]),
          ]),
        ],
      );
      final staff2 = StaffElement(const NodeTransform.identity(), 2);
      final part =
          PartElement(const NodeTransform.identity(), [staff1, staff2]);
      final system = SystemElement(const NodeTransform.identity(), [part]);
      arrangeStavesVertical(part); // staff1 dy = 0
      final systemAbs = absoluteTransform(system);
      final partAbs = absoluteTransform(part, parentAbsolute: systemAbs);
      final staffAbs = absoluteTransform(staff1, parentAbsolute: partAbs);
      final noteAbs = absoluteTransform(note, parentAbsolute: staffAbs);
      expect(MatrixUtils.transformPoint(noteAbs, Offset.zero),
          offsetCloseTo(const Offset(3, 4)));
    });
  });

  group('staffAbsoluteOrigin: each staff\'s absolute vertical position', () {
    test('returns the top-line Y for each staff via the S5 index', () {
      final (system, part, staff1, staff2) = twoStaffSystem();
      arrangeStavesVertical(part); // staff1 dy=0, staff2 dy=12
      final index = absoluteTransformIndex(system);
      expect(staffAbsoluteOrigin(staff1, index), offsetCloseTo(Offset.zero));
      expect(staffAbsoluteOrigin(staff2, index),
          offsetCloseTo(const Offset(0, 12)));
    });

    test('the bottom line is origin.dy + staffHeightInStaffSpaces(lineCount)', () {
      final (system, part, _, staff2) = twoStaffSystem();
      arrangeStavesVertical(part);
      final index = absoluteTransformIndex(system);
      final origin = staffAbsoluteOrigin(staff2, index);
      expect(origin.dy + staffHeightInStaffSpaces(staff2.lineCount), 16.0); // 12 + 4
    });

    test('reflects a custom inter-staff distance', () {
      final (system, part, _, staff2) = twoStaffSystem();
      arrangeStavesVertical(part, interStaffDistance: 10);
      final index = absoluteTransformIndex(system);
      expect(staffAbsoluteOrigin(staff2, index),
          offsetCloseTo(const Offset(0, 10)));
    });

    test('throws StateError for a staff outside the indexed subtree', () {
      final (system, part, _, _) = twoStaffSystem();
      arrangeStavesVertical(part);
      final index = absoluteTransformIndex(system);
      // A staff not in the tree is a dangling target → descriptive throw.
      final orphan = StaffElement(const NodeTransform.identity(), 9);
      expect(() => staffAbsoluteOrigin(orphan, index), throwsStateError);
    });
  });

  group('systemVerticalExtent: the system\'s total vertical extent', () {
    test('2 empty staves at default distance → (2-1)*12 + 4 = 16', () {
      final (system, part, _, _) = twoStaffSystem();
      arrangeStavesVertical(part);
      expect(systemVerticalExtent(system), 16.0);
    });

    test('3 empty staves at default distance → (3-1)*12 + 4 = 28', () {
      final part = PartElement(const NodeTransform.identity(), [
        StaffElement(const NodeTransform.identity(), 1),
        StaffElement(const NodeTransform.identity(), 2),
        StaffElement(const NodeTransform.identity(), 3),
      ]);
      final system = SystemElement(const NodeTransform.identity(), [part]);
      arrangeStavesVertical(part);
      expect(systemVerticalExtent(system), 28.0);
    });

    test('a custom inter-staff distance changes the extent: 2 staves @10 → 14', () {
      final (system, part, _, _) = twoStaffSystem();
      arrangeStavesVertical(part, interStaffDistance: 10);
      expect(systemVerticalExtent(system), 14.0); // (2-1)*10 + 4
    });

    test('content extending below the bottom line widens the extent', () {
      // A note 6 staff spaces below staff 2's origin → absolute y = 12 + 6 = 18,
      // box reaching 19, beyond staff 2's bottom line (12 + 4 = 16).
      final note = RectElement(
        const NodeTransform(translation: Offset(0, 6)),
        Rect.fromLTWH(0, 0, 1, 1),
      );
      final staff1 = StaffElement(const NodeTransform.identity(), 1);
      final staff2 = StaffElement(
        const NodeTransform.identity(),
        2,
        [
          MeasureElement(const NodeTransform.identity(), [
            ColumnElement(const NodeTransform.identity(), [note]),
          ]),
        ],
      );
      final part =
          PartElement(const NodeTransform.identity(), [staff1, staff2]);
      final system = SystemElement(const NodeTransform.identity(), [part]);
      arrangeStavesVertical(part); // staff2 dy = 12
      expect(systemVerticalExtent(system), 19.0); // staff1 top (0) .. note bottom (19)
    });

    test('agrees with absoluteBoundingBox(system).height', () {
      final (system, part, _, _) = twoStaffSystem();
      arrangeStavesVertical(part);
      expect(systemVerticalExtent(system), absoluteBoundingBox(system).height);
    });
  });

  group('identity stability: arrangement mutates transforms, not nodes', () {
    test('re-arranging in place keeps node identity stable', () {
      final (_, part, _, staff2) = twoStaffSystem();
      arrangeStavesVertical(part); // dy = 12
      final sameStaff2 = part.staves.last;
      expect(identical(sameStaff2, staff2), isTrue);
      // Re-arrange with a different distance: the node object is unchanged.
      arrangeStavesVertical(part, interStaffDistance: 10);
      expect(identical(part.staves.last, staff2), isTrue);
      expect(staff2.transform.translation.dy, 10);
    });

    test('the S5 index, rebuilt after re-arrangement, tracks the new position', () {
      final (system, part, _, staff2) = twoStaffSystem();
      arrangeStavesVertical(part); // dy = 12
      final indexBefore = absoluteTransformIndex(system);
      expect(staffAbsoluteOrigin(staff2, indexBefore).dy, 12);
      // Mutate the transform in place and rebuild the index (pass-local data).
      arrangeStavesVertical(part, interStaffDistance: 20);
      final indexAfter = absoluteTransformIndex(system);
      expect(staffAbsoluteOrigin(staff2, indexAfter).dy, 20);
      // The same StaffElement object is still keyed in the rebuilt index —
      // arrangement mutates transforms, not nodes, so identity is stable
      // (Map keys compare by identity for the unmodified Element identity).
      expect(indexAfter.containsKey(staff2), isTrue);
      expect(staff2.staffNumber, 2); // structural identity untouched
    });
  });

  group('N ≥ 2: a single staff is representable but not "multi-staff"', () {
    test('a 1-staff system still arranges (offset 0) and reports height 4', () {
      final part = PartElement(const NodeTransform.identity(), [
        StaffElement(const NodeTransform.identity(), 1),
      ]);
      final system = SystemElement(const NodeTransform.identity(), [part]);
      arrangeStavesVertical(part);
      expect(part.staves.first.transform.translation.dy, 0);
      expect(systemVerticalExtent(system), 4.0); // 1 staff: 0 + 4
    });

    test('a 6-line staff system reports height 5 (per-staff lineCount)', () {
      final part = PartElement(const NodeTransform.identity(), [
        StaffElement(const NodeTransform.identity(), 1, const [], 6),
      ]);
      final system = SystemElement(const NodeTransform.identity(), [part]);
      arrangeStavesVertical(part);
      expect(systemVerticalExtent(system), 5.0); // 6-line staff: 6 - 1
    });
  });
}
