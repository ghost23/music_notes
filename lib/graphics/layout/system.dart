import 'dart:ui' show Offset;

import 'package:flutter/painting.dart' show MatrixUtils;
import 'package:vector_math/vector_math_64.dart' show Matrix4;

import '../graphics_model/canvas_primitives.dart' show Element;
import '../graphics_model/semantic/structural.dart'
    show PartElement, StaffElement, staffHeightInStaffSpaces;
import 'cross_references.dart' show absoluteTransformIndex;
import 'geometry.dart' show absoluteBoundingBox;

/// Free functions for multi-staff vertical arrangement (WP1-S6).
///
/// The first milestone is explicitly **multi-staff from the start** (see
/// `docs/rewrite-plan.md`): a single system containing more than one staff
/// (e.g. a piano grand staff), with the staves stacked vertically in
/// staff-space units. The structural nodes ([SystemElement] → [PartElement] →
/// [StaffElement]) are declared in S3; this library gives them their
/// **arrangement geometry** — the vertical placement of staves within a part
/// and the queries that read it back.
///
/// ## Staff offsets are transforms (S1), not a separate mechanism
///
/// A staff's vertical position is its `NodeTransform.translation` relative to
/// its parent part, composed by S1's free functions into system space. There
/// is no separate positioning field or mechanism: [arrangeStavesVertical] sets
/// each staff's `transform.translation.dy`, and [staffAbsoluteOrigin] /
/// [systemVerticalExtent] read the result back via S1's transform-composition
/// functions ([absoluteTransformIndex], [absoluteBoundingBox]). A note's
/// staff-relative Y therefore maps into system space purely through transform
/// composition (see `StaffElement`'s local-origin / staff-line-region docs).
///
/// ## Inter-staff distance is a parameter, not a global
///
/// The inter-staff distance (top line of staff N to top line of staff N+1) is
/// a parameter of [arrangeStavesVertical], defaulting to
/// [defaultInterStaffDistance]. The default and its source are documented on
/// that constant; **content-driven (collision-aware) inter-staff spacing is
/// deferred** — see `docs/rewrite-plan.md`'s open question "Multi-staff
/// vertical spacing". For the first milestone a fixed, parameterised distance
/// is acceptable (the [rewrite-plan.md] scope explicitly says so).
///
/// ## Node identity stays stable across arrangement
///
/// [arrangeStavesVertical] **mutates the staff transforms in place** (it
/// assigns to `staff.transform`), never replacing the [StaffElement] node
/// itself. This is the S5 identity-stability rule: cross-references and the
/// absolute-transform index key off Dart object identity, so a staff's
/// transform may change while every reference pointing at it stays valid.
/// After mutating, the index is rebuilt fresh (it is pass-local derived data,
/// not IR state) and the new positions are reflected.
///
/// All coordinates are staff-space units (see `NodeTransform`).

/// The default **gap** between consecutive staves (bottom line of staff N to
/// top line of staff N+1), in staff-space units: 2 staff heights = 8 staff
/// spaces.
///
/// **Source:** the legacy `MusicLineState.initState` set
/// `staffsSpacing = staffHeight * 2` (see `lib/graphics/music_line.dart`),
/// i.e. a gap of two staff heights between the bottom line of one staff and
/// the top line of the next. S6 keeps that value as the documented default so
/// the first milestone's output matches the legacy renderer's spacing.
///
/// **Content-driven (collision-aware) inter-staff spacing is deferred** — see
/// the open question "Multi-staff vertical spacing" in
/// `docs/rewrite-plan.md`. A later WP will make the gap grow to avoid
/// collisions between staves' contents (e.g. low ledger lines of the upper
/// staff vs. high ledger lines of the lower). That will likely be a
/// deferred/resolved property (S5's `isResolved`), but the mechanism is not
/// wired here: for the first milestone a fixed, parameterised distance is
/// acceptable.
double get defaultInterStaffGap => 2.0 * staffHeightInStaffSpaces();

/// The default **inter-staff distance** (top line of staff N to top line of
/// staff N+1), in staff-space units: the staff height plus the inter-staff
/// gap = `4 + 8 = 12` staff spaces (3 staff heights) for the standard 5-line
/// staff.
///
/// This is the per-step offset [arrangeStavesVertical] applies by default:
/// staff 0 sits at `dy = 0`, staff 1 at `dy = 12`, staff 2 at `dy = 24`, … .
/// See [defaultInterStaffGap] for the gap's source and the deferred
/// content-driven-spacing decision.
double get defaultInterStaffDistance =>
    staffHeightInStaffSpaces() + defaultInterStaffGap;

/// Arranges the staves of [part] vertically by setting each staff's
/// `transform.translation.dy` to `index * interStaffDistance` (the first
/// staff at the top, `dy = 0`).
///
/// This is the S6 vertical-arrangement step: staff offsets are **transforms on
/// the staff nodes**, composed by S1's functions — there is no separate
/// positioning mechanism. It **mutates the staff transforms in place** (not
/// the nodes), so cross-references and the absolute-transform index (S5) that
/// key off node identity keep pointing at the right staff after it moves;
/// rebuild the index afterwards to reflect the new positions.
///
/// [interStaffDistance] is the top-to-top distance (top line of staff N to top
/// line of staff N+1) in staff-space units; it defaults to
/// [defaultInterStaffDistance] (see its doc for the source and the deferred
/// content-driven-spacing decision). Each staff's existing X translation and
/// scale/rotation are preserved — only the vertical position is set.
///
/// A note's staff index from `data.dart` (`Note.staff`) selects which
/// [StaffElement] it belongs to; wiring notes into the right staff is layout
/// (WP3/WP5), but this contract makes it expressible: the staff nodes exist,
/// are ordered, and carry their 1-based [StaffElement.staffNumber].
void arrangeStavesVertical(
  PartElement part, {
  double? interStaffDistance,
}) {
  final distance = interStaffDistance ?? defaultInterStaffDistance;
  final staves = part.staves;
  for (var i = 0; i < staves.length; i++) {
    final t = staves[i].transform;
    staves[i].transform =
        t.copyWith(translation: Offset(t.translation.dx, i * distance));
  }
}

/// The absolute staff-space offset of [staff]'s local origin (its top line) in
/// the tree, given the [index] of absolute transforms (built by S5's
/// [absoluteTransformIndex]).
///
/// This is the S6 "each staff's absolute vertical position" query: the top
/// line's absolute Y is the result's `dy`; the bottom line is at
/// `result.dy + staffHeightInStaffSpaces(staff.lineCount)` (`+ 4` for a
/// standard 5-line staff). It reuses the S5/S1 absolute-transform index — a
/// single top-down walk's composed transforms — rather than re-walking from
/// the root per staff (the IR has no parent links by design).
///
/// Throws [StateError] if [staff] is not in [index] (e.g. it is outside the
/// indexed subtree): a programmer error, not a recoverable condition — per the
/// exceptions-over-null principle.
Offset staffAbsoluteOrigin(
  StaffElement staff,
  Map<Element, Matrix4> index,
) {
  final absolute = index[staff];
  if (absolute == null) {
    throw StateError(
      'StaffElement #${staff.staffNumber} is not in the absolute-transform '
      'index; it is outside the indexed subtree.',
    );
  }
  return MatrixUtils.transformPoint(absolute, Offset.zero);
}

/// The total **vertical extent** (height) of [system]'s subtree in staff-space
/// units, computed as a bounding box via S1's [absoluteBoundingBox].
///
/// Each [StaffElement] contributes its staff-line region (height
/// `staffHeightInStaffSpaces(lineCount)` = 4 staff spaces for a standard
/// 5-line staff — see `StaffElement`) plus its descendants' boxes, so for N
/// standard staves arranged by [arrangeStavesVertical] with inter-staff
/// distance `d` the extent is `(N - 1) * d + 4` (e.g. 2 staves at the default
/// distance 12 → `(2 - 1) * 12 + 4 = 16` staff spaces). Pass [parentAbsolute]
/// top-down if [system] is not a root. For the full bounding box (not just the
/// height), call [absoluteBoundingBox] directly.
double systemVerticalExtent(Element system, {Matrix4? parentAbsolute}) {
  return absoluteBoundingBox(system, parentAbsolute: parentAbsolute).height;
}
