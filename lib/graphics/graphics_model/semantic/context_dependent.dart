import '../canvas_primitives.dart' show GroupElement;

/// Context-dependent semantic nodes — **placeholders** (WP1-S3).
///
/// These are elements whose geometry **cannot be computed yet** because it
/// depends on the final positions of other elements: a tie/slur spans
/// noteheads whose Y is not yet known; a dynamic/word is placed relative to a
/// staff; a wedge sits between two dynamic points.
///
/// Per the WP1-S3 scope, this story only **declares** these types as
/// placeholders and cross-references them to **S5** (the deferred-reference
/// mechanism — references to target elements/anchors, unresolved vs resolved
/// state) and **WP6** (the actual resolution math). Concretely:
/// - The **deferred-reference machinery** (an explicit unresolved state
///   carrying references, a traversal that finds unresolved elements, and a
///   throw-on-unresolved-geometry contract) is delivered by **S5**.
/// - The **resolution logic** (tie/slur/dynamic/direction math) is **WP6**.
///
/// Until S5 lands, the types below are plain [GroupElement] specialisations
/// carrying only the type identity; they have no reference fields and no
/// unresolved/resolved state here. S5 will evolve them (adding reference
/// fields and a distinct unresolved state) without changing their names or
/// the taxonomy mapping below.

/// A **beam** joining the stems of consecutive notes.
///
/// **Source:** `Beam` entries on `PitchNote.beams`.
/// **Composes:** one or more `RectElement`/`LineElement` leaves — the beam
/// segments — once the stem-tip positions are known. A beam is
/// context-dependent (its geometry depends on the stems it joins): its
/// segment count and geometry are produced by the WP6 beam rule, and the
/// deferred-reference *mechanism* it uses to find its stems is defined in S5.
/// It therefore stays an open [GroupElement] placeholder for now rather than a
/// fixed composite.
class BeamElement extends GroupElement {
  BeamElement(super.transform, [super.elements]);
}

/// A **tie** joining two noteheads of the same pitch.
///
/// **Source:** `Tied` notation.
/// **Composes:** (eventually) a `PathElement`/`LineElement` curve leaf, once
/// the start and end notehead positions are known.
/// **Deferred reference:** S5 (the noteheads it ties); **resolution math:**
/// WP6.
class TieElement extends GroupElement {
  TieElement(super.transform, [super.elements]);
}

/// A **slur** (legato) over a span of notes.
///
/// **Source:** `Slur` notation.
/// **Composes:** (eventually) a `PathElement` curve leaf, once the spanned
/// notehead positions are known.
/// **Deferred reference:** S5 (the noteheads it spans); **resolution math:**
/// WP6.
class SlurElement extends GroupElement {
  SlurElement(super.transform, [super.elements]);
}

/// A **dynamic** marking (p, f, mp, …).
///
/// **Source:** `Dynamics` notation.
/// **Composes:** one [GlyphElement] leaf per dynamic glyph
/// (`Glyph.dynamicPiano` / `dynamicForte` / …), placed relative to the staff
/// once the surrounding context is known.
/// **Deferred reference:** S5 (the staff/notes it attaches to); **resolution
/// math:** WP6.
class DynamicElement extends GroupElement {
  DynamicElement(super.transform, [super.elements]);
}

/// A **direction** — a wedge (hairpin), printed words, or an octave shift.
///
/// **Source:** `Direction` carrying one of `Wedge` / `Words` / `OctaveShift`.
/// **Composes:** (eventually) `LineElement`/`RectElement` leaves for a wedge,
/// [GlyphElement] leaves for words/octave-shift glyphs — once the endpoints'
/// positions are known.
/// **Deferred reference:** S5 (the notes/staff the direction spans); **resolution
/// math:** WP6.
class DirectionElement extends GroupElement {
  DirectionElement(super.transform, [super.elements]);
}
