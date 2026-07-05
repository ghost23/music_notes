import 'package:flutter/painting.dart';

import '../generated/glyph_definitions.dart';
import '/graphics/graphics_model/canvas_primitives.dart';
import '/graphics/graphics_model/styling.dart';

/// Temporary render-side shim (WP1-S2 → WP2).
///
/// Now that the IR carries only scale-free [Styling] (no `Paint`/`TextStyle`,
/// no pixel font size or pixel stroke width), this shim bridges the gap until
/// the WP2 render tree-walker lands.
///
/// **Styling ownership.** The layout phase is the sole source of styling. This
/// renderer has **no styling defaults**: it draws exactly what the IR carries
/// and **throws** if a required scale-free property is missing (no stroke or
/// fill color, or a stroke without a staff-space [Styling.strokeWidth]).
/// Default styles, when wanted, are defined in the IR element definitions and
/// resolved during layout — never invented here. Fill-vs-stroke intent is
/// derived from which colors are set (see [Styling.hasStroke] / [Styling.hasFill]).
///
/// The only thing this shim supplies itself is the **scale-dependent pixel
/// conversion** from the single render scaling measure — the pixels-per-
/// staff-space [scale] argument — because that is a genuine render concern,
/// not styling:
/// - a staff-space `strokeWidth` becomes `strokeWidth × scale` pixels;
/// - a glyph's staff-space size becomes a pixel font size of `4 × scale`
///   (1 em = 4 staff spaces = 1 staff height).
///
/// [_defaultPixelsPerStaffSpace] is a placeholder for that scaling measure
/// until WP2 threads the real one (a SMUFL font size) through every draw call.
const double _defaultPixelsPerStaffSpace = 8;

void drawTranslated(Canvas canvas, Element element, VoidCallback command) {
  canvas.translate(element.pointOfOrigin.dx, element.pointOfOrigin.dy);
  command();
  canvas.translate(-element.pointOfOrigin.dx, -element.pointOfOrigin.dy);
}

/// Resolves a staff-space [Styling.strokeWidth] to pixels via [scale], or
/// throws if the element is stroked without a width. The renderer has no
/// default thickness.
double _strokeWidthOrThrow(Element element, Styling s, double scale) {
  final w = s.strokeWidth;
  if (w == null) {
    throw StateError(
      '${element.runtimeType} is stroked but carries no strokeWidth '
      '(staff-space). Styling must be resolved during layout; the renderer '
      'has no defaults.',
    );
  }
  return w * scale;
}

/// Builds a [Paint] from [element]'s resolved scale-free [Styling] and the
/// pixels-per-staff-space [scale]. The model never constructs a `Paint`; this
/// is the boundary where scale-free intent meets the render scaling measure.
/// Throws if the styling is unresolved or incomplete — see the file doc.
Paint _paintFor(Element element, double scale) {
  final s = element.styling;
  if (!s.hasStroke && !s.hasFill) {
    throw StateError(
      '${element.runtimeType} carries no stroke or fill color. Styling must '
      'be resolved during layout; the renderer has no defaults.',
    );
  }

  // Intent is derived from color presence (Styling.hasStroke / hasFill).
  // Flutter draws fill or stroke per call, not both; a real two-pass
  // stroke+fill is left to WP2. For now, when both are set, the shim fills
  // (the more common case for music notation primitives like noteheads) and
  // configures the stroke width so a stroke pass could follow.
  if (s.hasStroke && s.hasFill) {
    return Paint()
      ..style = PaintingStyle.fill
      ..color = s.fillColor!
      ..strokeWidth = _strokeWidthOrThrow(element, s, scale);
  }
  if (s.hasStroke) {
    return Paint()
      ..style = PaintingStyle.stroke
      ..color = s.strokeColor!
      ..strokeWidth = _strokeWidthOrThrow(element, s, scale);
  }
  // hasFill only.
  return Paint()
    ..style = PaintingStyle.fill
    ..color = s.fillColor!;
}

/// Builds a [TextStyle] for a glyph from its resolved [Styling] and the
/// pixels-per-staff-space [scale]. Glyphs are filled, so a fill color is
/// required and the renderer throws if it is missing. The font size is
/// `4 × scale` (1 em = 4 staff spaces); font family is a render-phase resource
/// binding, not IR state.
TextStyle _textStyleFor(GlyphElement element, double scale) {
  final color = element.styling.fillColor;
  if (color == null) {
    throw StateError(
      '${element.runtimeType} (glyph ${element.glyph}) carries no fill color. '
      'Styling must be resolved during layout; the renderer has no defaults.',
    );
  }
  return TextStyle(
    fontFamily: 'Bravura',
    fontSize: 4 * scale,
    height: 1,
    color: color,
  );
}

void drawPathElement(Canvas canvas, PathElement element,
        [double scale = _defaultPixelsPerStaffSpace]) =>
    drawTranslated(
        canvas, element, () => canvas.drawPath(element.path, _paintFor(element, scale)));

void drawLineElement(Canvas canvas, LineElement element,
        [double scale = _defaultPixelsPerStaffSpace]) =>
    drawTranslated(canvas, element,
        () => canvas.drawLine(element.startPoint, element.endPoint, _paintFor(element, scale)));

void drawRectElement(Canvas canvas, RectElement element,
        [double scale = _defaultPixelsPerStaffSpace]) =>
    drawTranslated(
        canvas, element, () => canvas.drawRect(element.rect, _paintFor(element, scale)));

void drawGlyphElement(Canvas canvas, GlyphElement element,
        [double scale = _defaultPixelsPerStaffSpace]) {
  drawTranslated(canvas, element, () {
    final textPainter = TextPainter(
      text: TextSpan(
        text: glyphFontCodeMap[element.glyph],
        style: _textStyleFor(element, scale),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset.zero);
    textPainter.dispose();
  });
}

/// Draws [element] and its subtree. Leaves paint themselves; a container
/// (a [GroupElement] collection or a [CompositeElement]) translates by its own
/// origin and recurses into its [Element.elements] — so open collections and
/// fixed composites are walked uniformly.
void drawElement(Canvas canvas, Element element,
    [double scale = _defaultPixelsPerStaffSpace]) {
  switch (element) {
    case PathElement():
      drawPathElement(canvas, element, scale);
    case LineElement():
      drawLineElement(canvas, element, scale);
    case RectElement():
      drawRectElement(canvas, element, scale);
    case GlyphElement():
      drawGlyphElement(canvas, element, scale);
    case GroupElement():
    case CompositeElement():
      drawTranslated(canvas, element, () {
        for (final child in element.elements) {
          drawElement(canvas, child, scale);
        }
      });
  }
}
