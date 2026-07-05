import '../canvas_primitives.dart' show GroupElement;

/// Separator semantic nodes (WP1-S3).

/// A **barline** separating measures.
///
/// **Source:** `Barline` (carrying `BarLineTypes`).
/// **Composes:** the [LineElement] / [GlyphElement] leaves that draw the
/// barline style — a single thin line for `regular`, thin+thick lines and
/// repeat dots for `repeatLeft`/`repeatRight`, etc. Which leaves are built is
/// decided by the WP5 builder from `Barline.barStyle`; the style is encoded by
/// the leaves, not re-stored here.
/// **Layout fields:** none for the first milestone; the engraving defaults
/// (thin/thick barline thickness, barline separation, …) are resolved into
/// [Styling] by the WP5 barline rule, not stored here.
class BarlineElement extends GroupElement {
  BarlineElement(super.transform, [super.elements]);
}
