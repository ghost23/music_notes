import 'package:flutter/painting.dart';

import '../generated/glyph_definitions.dart';
import '/graphics/graphics_model/canvas_primitives.dart';
import '/graphics/graphics_model/styling.dart';
import 'render_scale.dart';

/// Render-phase tree-walker (WP1-S2 → WP2-S2/S3).
///
/// Walks the IR scene graph of [Element]s and draws it, doing **no**
/// measurement, positioning, or layout — every position, transform, anchor and
/// style comes from the tree. The renderer's only own numeric contribution is
/// the single render scaling measure [RenderScale] (pixels per staff space),
/// which converts the IR's staff-space units to pixels.
///
/// ## Unit-conversion strategy: scale-the-canvas-once
///
/// Each public entry point applies [RenderScale.pixelsPerStaffSpace] as a
/// single root `canvas.scale(...)` (via [_withScale]) and then walks the tree
/// in **staff-space units**: translations, leaf geometry and stroke widths are
/// all staff-space, and a glyph is drawn at the staff-space em font size
/// [RenderScale.staffSpacesPerEm] (`4`). The root scale turns them into pixels
/// in one place, so the walker itself is unit-agnostic. See [RenderScale] for
/// the rationale vs per-leaf conversion.
///
/// ## Styling ownership
///
/// The layout phase is the sole source of styling. This renderer has **no
/// styling defaults**: it draws exactly what the IR carries and **throws** if a
/// required scale-free property is missing (no stroke or fill color, or a
/// stroke without a staff-space [Styling.strokeWidth]). Fill-vs-stroke intent
/// is derived from color presence ([Styling.hasStroke] / [Styling.hasFill]).
///
/// The per-node `scale`/`rotation` of a [NodeTransform] and the
/// unresolved-node refusal (`isResolved == false` must not be drawn) are added
/// in S3.

/// Applies [renderScale] as a single root canvas scale around [command].
void _withScale(Canvas canvas, RenderScale renderScale, VoidCallback command) {
  canvas.save();
  canvas.scale(renderScale.pixelsPerStaffSpace);
  command();
  canvas.restore();
}

/// Translates by [element]'s staff-space [Element.pointOfOrigin], draws via
/// [command], then translates back. The root canvas scale (applied by the
/// public entry point) converts the staff-space translation to pixels.
void _drawTranslated(Canvas canvas, Element element, VoidCallback command) {
  final origin = element.pointOfOrigin;
  canvas.translate(origin.dx, origin.dy);
  command();
  canvas.translate(-origin.dx, -origin.dy);
}

/// Returns a staff-space [Styling.strokeWidth] or throws if the element is
/// stroked without a width. The renderer has no default thickness; the root
/// canvas scale converts the staff-space width to pixels.
double _strokeWidthOrThrow(Element element, Styling styling) {
  final strokeWidth = styling.strokeWidth;
  if (strokeWidth == null) {
    throw StateError(
      '${element.runtimeType} is stroked but carries no strokeWidth '
      '(staff-space). Styling must be resolved during layout; the renderer '
      'has no defaults.',
    );
  }
  return strokeWidth;
}

/// Builds a [Paint] from [element]'s resolved scale-free [Styling]. The model
/// never constructs a `Paint`; this is the boundary where scale-free intent
/// meets the canvas. Throws if the styling is unresolved or incomplete — see
/// the file doc.
Paint _paintFor(Element element) {
  final styling = element.styling;
  if (!styling.hasStroke && !styling.hasFill) {
    throw StateError(
      '${element.runtimeType} carries no stroke or fill color. Styling must '
      'be resolved during layout; the renderer has no defaults.',
    );
  }

  // Intent is derived from color presence (Styling.hasStroke / hasFill).
  // Flutter draws fill or stroke per call, not both; a real two-pass
  // stroke+fill is left to WP2. For now, when both are set, the renderer fills
  // (the more common case for music notation primitives like noteheads) and
  // configures the stroke width so a stroke pass could follow.
  if (styling.hasStroke && styling.hasFill) {
    return Paint()
      ..style = PaintingStyle.fill
      ..color = styling.fillColor!
      ..strokeWidth = _strokeWidthOrThrow(element, styling);
  }
  if (styling.hasStroke) {
    return Paint()
      ..style = PaintingStyle.stroke
      ..color = styling.strokeColor!
      ..strokeWidth = _strokeWidthOrThrow(element, styling);
  }
  // hasFill only.
  return Paint()
    ..style = PaintingStyle.fill
    ..color = styling.fillColor!;
}

/// Builds a [TextStyle] for a glyph from its resolved [Styling]. Glyphs are
/// filled, so a fill color is required and the renderer throws if it is
/// missing. The font size is the staff-space em [RenderScale.staffSpacesPerEm]
/// (`4`); the root canvas scale converts it to pixels (1 em = 4 staff spaces).
/// Font family is a render-phase resource binding, not IR state.
TextStyle _textStyleFor(GlyphElement element) {
  final color = element.styling.fillColor;
  if (color == null) {
    throw StateError(
      '${element.runtimeType} (glyph ${element.glyph}) carries no fill color. '
      'Styling must be resolved during layout; the renderer has no defaults.',
    );
  }
  return TextStyle(
    fontFamily: 'Bravura',
    fontSize: RenderScale.staffSpacesPerEm.toDouble(),
    height: 1,
    color: color,
  );
}

// --- Public entry points (apply the render scale once) ---------------------

void drawPathElement(
  Canvas canvas,
  PathElement element,
  RenderScale renderScale,
) =>
    _withScale(canvas, renderScale, () => _drawPath(canvas, element));

void drawLineElement(
  Canvas canvas,
  LineElement element,
  RenderScale renderScale,
) =>
    _withScale(canvas, renderScale, () => _drawLine(canvas, element));

void drawRectElement(
  Canvas canvas,
  RectElement element,
  RenderScale renderScale,
) =>
    _withScale(canvas, renderScale, () => _drawRect(canvas, element));

void drawGlyphElement(
  Canvas canvas,
  GlyphElement element,
  RenderScale renderScale,
) =>
    _withScale(canvas, renderScale, () => _drawGlyph(canvas, element));

/// Draws [element] and its subtree. Leaves paint themselves; a container
/// (a [GroupElement] collection or a [CompositeElement]) translates by its own
/// origin and recurses into its [Element.elements] — so open collections and
/// fixed composites are walked uniformly.
void drawElement(
  Canvas canvas,
  Element element,
  RenderScale renderScale,
) =>
    _withScale(canvas, renderScale, () => _drawElement(canvas, element));

// --- Internal staff-space walkers (canvas already scaled) ------------------

void _drawPath(Canvas canvas, PathElement element) => _drawTranslated(
    canvas, element, () => canvas.drawPath(element.path, _paintFor(element)));

void _drawLine(Canvas canvas, LineElement element) => _drawTranslated(canvas,
    element, () => canvas.drawLine(element.startPoint, element.endPoint, _paintFor(element)));

void _drawRect(Canvas canvas, RectElement element) => _drawTranslated(
    canvas, element, () => canvas.drawRect(element.rect, _paintFor(element)));

void _drawGlyph(Canvas canvas, GlyphElement element) {
  _drawTranslated(canvas, element, () {
    final textPainter = TextPainter(
      text: TextSpan(
        text: glyphFontCodeMap[element.glyph],
        style: _textStyleFor(element),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset.zero);
    textPainter.dispose();
  });
}

void _drawElement(Canvas canvas, Element element) {
  switch (element) {
    case PathElement():
      _drawPath(canvas, element);
    case LineElement():
      _drawLine(canvas, element);
    case RectElement():
      _drawRect(canvas, element);
    case GlyphElement():
      _drawGlyph(canvas, element);
    case GroupElement():
    case CompositeElement():
      _drawTranslated(canvas, element, () {
        for (final child in element.elements) {
          _drawElement(canvas, child);
        }
      });
  }
}
