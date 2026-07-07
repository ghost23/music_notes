import 'dart:ui' show Offset;

import 'package:flutter/painting.dart' show MatrixUtils;
import 'package:vector_math/vector_math_64.dart' show Matrix4;

import '../generated/glyph_advance_widths.dart' show glyphAdvanceWidths;
import '../generated/glyph_definitions.dart' show Glyph;
import '../graphics_model/canvas_primitives.dart' show GlyphElement;
import 'geometry.dart' show absoluteTransform;

/// Parameterised per-glyph metadata readers (WP1-S3).
///
/// Per the glyph-knowledge contract (see `graphics_model/semantic/semantic.dart`),
/// per-glyph **metadata** — bounding box, anchors, advance width — is **never
/// copied** onto a node. It is read on demand via free functions that take the
/// metadata table as a **parameter**, so they unit-test with hand-built
/// fixtures and no global state (the S4 testability rule). The musical-concept
/// → `Glyph` mapping and the engraving defaults have their own named homes
/// (see `semantic.dart`); this library owns only the per-glyph *geometry*
/// readers.
///
/// ## What lives here (decided in WP1-S3 / WP1-S4)
///
/// **Advance width** is surfaced here in **WP1** — alongside the other
/// parameterised per-glyph metadata readers — rather than deferred to WP5,
/// so a copy of advance-width data can never sneak onto a node or get passed
/// around as a raw value. The other per-glyph readers live here too:
/// - **Bounding box** is today exposed as the S1 *local* getter
///   `GlyphElement.localBoundingBox` (the primitive layer's own extent). A
///   parameterised bbox reader can be added here when a WP5/WP6 consumer needs
///   a node's bbox without going through the S1 getter; S1/S4 own any change
///   to that getter.
/// - **Anchors** (WP1-S4): a glyph's anchors are read by **direct field
///   access** on the `GlyphAnchor` record (the `glyphAnchors` table is passed
///   as a parameter — the S4 testability rule), so there is no separate
///   named-vocabulary type or dispatch. The one anchor-related free function
///   here, [absoluteAnchorOffset], is a thin transform-composition util: it
///   takes an already-resolved local anchor offset and composes it with the
///   element's absolute transform (reusing S1's `absoluteTransform`).
///
/// ## Advance width is a spacing *input*, not the spacing itself
///
/// A glyph's advance width is the *horizontal space the glyph would occupy if
/// laid out in isolation* — a per-glyph fact. It is an **input/hint** the WP5
/// horizontal-spacing rule consumes, **not** the final gap between notes: the
/// spacing rule may widen the gap (for a comfortable layout), tighten it (to
/// justify a measure), or ignore advance width entirely (e.g. for rests
/// centred in a measure). Surfacing advance width here gives that rule a clean
/// parameterised input; the decision of *where the notes actually go* remains
/// a WP5 layout-rule concern.

/// The advance width of [glyph] in staff-space units, read from
/// [advanceWidths] (defaults to the generated `glyphAdvanceWidths` table).
///
/// The advance width is a per-glyph fact expressed in staff-space units (1
/// staff space = the SMUFL unit). It is a spacing *input* a layout rule may
/// override — see the file doc.
///
/// Throws [ArgumentError] if [glyph] has no entry in [advanceWidths]: a
/// missing advance width is a programmer/usage error (the generated table
/// covers every `Glyph`), not a recoverable condition — per the
/// exceptions-over-null principle. Passing [advanceWidths] explicitly lets
/// tests run with a hand-built table and no global state.
double glyphAdvanceWidth(Glyph glyph, {Map<Glyph, double>? advanceWidths}) {
  final table = advanceWidths ?? glyphAdvanceWidths;
  final width = table[glyph];
  if (width == null) {
    throw ArgumentError(
      'No advance width registered for glyph $glyph.',
    );
  }
  return width;
}

// ----------------------------------------------------------------------
// Transform-aware anchor resolution (WP1-S4)
// ----------------------------------------------------------------------
//
// An anchor is a named point in a glyph's own coordinate space (staff-space
// units). Its **local** offset is a static per-glyph fact: a builder resolves
// it eagerly by reading the field directly off the `GlyphAnchor` record (the
// `glyphAnchors` table is passed as a parameter — the S4 testability rule),
// so there is no separate named-vocabulary type or dispatch here. Absence is
// real: the `GlyphAnchor` fields are nullable (`null` = the glyph does not
// define that anchor), and `Offset.zero` is a legitimate anchor position for
// some glyphs — so a builder that needs an anchor reads the field and fails
// fast (throw / assert) on `null` rather than treating zero as a sentinel.
//
// The only thing deferred for context-dependent elements (S5: slurs, beams,
// ties) is the **absolute** position, because that depends on the target's
// final transform — which is not known at build time. The deferred element
// stores the already-resolved local offset plus a reference to the target
// node; the WP3 pass driver builds an absolute-transform index, and a
// resolver composes the target's indexed transform with the local offset.
// `absoluteAnchorOffset` below is the thin composition step — it reuses S1's
// `absoluteTransform` (no recomputation, no re-walk from the root).

/// The **absolute** staff-space offset of a local [localOffset] on [element],
/// composing ancestor transforms from S1.
///
/// This is the transform-composition step a context-dependent symbol's
/// resolver (S5, WP6) uses to turn an already-resolved local anchor offset
/// into an absolute attachment point: a stem attaches to a notehead's
/// `stemUpSE`, a beam to stem tips, a slur to notehead edges — all in absolute
/// coordinates once the notehead is placed.
///
/// [localOffset] is the anchor's offset in the glyph's own coordinate space
/// (resolved by the caller via direct field access on `GlyphAnchor`, e.g.
/// `glyphAnchors[glyph]!.stemUpSE!`). It is composed with [element]'s
/// **absolute** transform, i.e. its own `NodeTransform` composed onto
/// [parentAbsolute] — reusing S1's [absoluteTransform] free function, not
/// duplicating the composition. Pass [parentAbsolute] top-down while walking
/// the tree (the IR has no parent links by design); when omitted, [element] is
/// treated as a root.
///
/// This deliberately takes a resolved `Offset`, not an anchor name + table:
/// the local offset is a static per-glyph fact known at build time, so a
/// builder resolves it once and a deferred element carries the `Offset`. The
/// absolute-transform index that the resolver pairs it with is a WP3 concern.
Offset absoluteAnchorOffset(
  GlyphElement element,
  Offset localOffset, {
  Matrix4? parentAbsolute,
}) {
  final absolute = absoluteTransform(element, parentAbsolute: parentAbsolute);
  return MatrixUtils.transformPoint(absolute, localOffset);
}
