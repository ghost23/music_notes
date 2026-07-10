import 'package:flutter/painting.dart';

import '../generated/glyph_definitions.dart';
import '/graphics/graphics_model/canvas_primitives.dart';
import '/graphics/graphics_model/styling.dart';
import 'render_scale.dart';

/// Render-phase tree-walker (WP2).
///
/// Walks the IR scene graph of [Element]s and draws it, doing **no**
/// measurement, positioning, or layout — every position, transform, anchor and
/// style comes from the tree. The renderer's only own numeric contribution is
/// the single render scaling measure [RenderScale] (pixels per staff space),
/// which converts the IR's staff-space units to pixels.
///
/// ## The single public entry point
///
/// [drawElement] is the sole entry point. It applies the render scale once,
/// then walks the tree. There are no per-type public draw functions: the sealed
/// `Element` switch inside [_drawNode] dispatches every leaf and container
/// uniformly, so a per-type wrapper would only duplicate the scale/transform
/// scaffolding this walker already applies.
///
/// ## Unit-conversion strategy: scale-the-canvas-once
///
/// [drawElement] applies [RenderScale.pixelsPerStaffSpace] as a single root
/// `canvas.scale(...)` and then walks the tree in **staff-space units**:
/// per-node transforms, leaf geometry and stroke widths are all staff-space,
/// and a glyph is drawn at the staff-space em font size
/// [RenderScale.staffSpacesPerEm] (`4`). The root scale turns them into pixels
/// in one place, so the walker itself is unit-agnostic. See [RenderScale] for
/// the rationale vs per-leaf conversion.
///
/// ## Full per-node transform
///
/// Each node's complete [NodeTransform] — translation **+ per-axis scale +
/// rotation** — is applied via [NodeTransform.toMatrix4] (already encoded in
/// SRT order: scale → rotate → translate) fed to `canvas.transform`. A
/// container's transform therefore applies to its whole subtree through canvas
/// state. The renderer never derives translate/rotate/scale by hand; it feeds
/// the IR's matrix to the canvas so the render convention is identical to the
/// IR convention by construction.
///
/// ## Unresolved-node refusal (WP1-S5 render boundary)
///
/// A node whose geometry is not finalised (`isResolved == false`) must never
/// reach the canvas. [_drawNode] **throws** the moment it reaches such a node,
/// before applying its transform or drawing anything. This is the **sole
/// enforcement point** of the S5 flag: the IR model getters stay inspectable
/// while unresolved (they return tentative values, never throw) so layout
/// passes can assess them — only this render boundary turns the flag into a
/// hard gate. Resolution itself (turning an unresolved slur/beam into
/// primitives) is WP6; here the renderer only refuses.
///
/// ## Styling ownership
///
/// The layout phase is the sole source of styling. This renderer has **no
/// styling defaults**: it draws exactly what the IR carries and **throws** if a
/// required scale-free property is missing (no stroke or fill color, or a
/// stroke without a staff-space [Styling.strokeWidth]). Fill-vs-stroke intent
/// is derived from color presence ([Styling.hasStroke] / [Styling.hasFill]).
/// When both fill and stroke are set, the leaf is drawn in **two passes** —
/// fill then stroke — so the outline sits on top of the fill.

/// Draws [element] and its subtree.
///
/// The sole public render entry point: applies the [renderScale] as a single
/// root canvas scale, then walks the tree in staff-space units. Leaves paint
/// from their own IR geometry + resolved [Styling]; containers apply their
/// full transform and recurse into [Element.elements] in draw order.
void drawElement(Canvas canvas, Element element, RenderScale renderScale) {
  canvas.save();
  canvas.scale(renderScale.pixelsPerStaffSpace);
  try {
    _drawNode(canvas, element);
  } finally {
    canvas.restore();
  }
}

/// Walks one node in staff-space (the root canvas scale is already applied).
///
/// Applies the node's full [NodeTransform] via [NodeTransform.toMatrix4],
/// dispatches on the sealed [Element] type (leaves paint; containers recurse),
/// and refuses an unresolved node up front (WP1-S5). Save/restore is balanced
/// even if a leaf draw throws.
void _drawNode(Canvas canvas, Element element) {
  if (!element.isResolved) {
    throw StateError(
      '${element.runtimeType} is unresolved (isResolved == false). Unresolved '
      'geometry must never reach the render boundary; resolve it during layout '
      '(see WP1-S5).',
    );
  }

  final transform = element.transform.toMatrix4();
  canvas.save();
  canvas.transform(transform.storage);
  try {
    switch (element) {
      case PathElement():
        _drawPainted(
          canvas,
          element,
          (Paint paint) => canvas.drawPath(element.path, paint),
        );
      case LineElement():
        _drawPainted(
          canvas,
          element,
          (Paint paint) =>
              canvas.drawLine(element.startPoint, element.endPoint, paint),
        );
      case RectElement():
        _drawPainted(canvas, element, (Paint paint) => canvas.drawRect(element.rect, paint));
      case GlyphElement():
        _drawGlyph(canvas, element);
      case GroupElement():
      case CompositeElement():
        for (final child in element.elements) {
          _drawNode(canvas, child);
        }
    }
  } finally {
    canvas.restore();
  }
}

/// Draws a stroked/filled primitive's geometry in the passes its [Styling]
/// requests — fill then stroke — via [drawGeometry]. Throws if the styling is
/// unresolved or incomplete (see the file doc).
void _drawPainted(
  Canvas canvas,
  Element element,
  void Function(Paint paint) drawGeometry,
) {
  for (final paint in _paintPasses(element)) {
    drawGeometry(paint);
  }
}

/// Returns the [Paint] passes [element]'s resolved scale-free [Styling]
/// requests: a fill pass when [Styling.hasFill], then a stroke pass when
/// [Styling.hasStroke]. The model never constructs a `Paint`; this is the
/// boundary where scale-free intent meets the canvas. Throws if no color is
/// set, or if a stroke lacks a staff-space [Styling.strokeWidth] — the
/// renderer has no defaults.
List<Paint> _paintPasses(Element element) {
  final styling = element.styling;
  if (!styling.hasStroke && !styling.hasFill) {
    throw StateError(
      '${element.runtimeType} carries no stroke or fill color. Styling must '
      'be resolved during layout; the renderer has no defaults.',
    );
  }

  final passes = <Paint>[];
  if (styling.hasFill) {
    passes.add(Paint()
      ..style = PaintingStyle.fill
      ..color = styling.fillColor!);
  }
  if (styling.hasStroke) {
    passes.add(Paint()
      ..style = PaintingStyle.stroke
      ..color = styling.strokeColor!
      ..strokeWidth = _strokeWidthOrThrow(element, styling));
  }
  return passes;
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

/// Draws a glyph via [TextPainter] from its resolved [Styling]. Glyphs are
/// filled, so a fill color is required and the renderer throws if it is
/// missing. The font size is the staff-space em [RenderScale.staffSpacesPerEm]
/// (`4`); the root canvas scale converts it to pixels (1 em = 4 staff spaces).
/// Font family is a render-phase resource binding, not IR state.
///
/// ## Baseline registration (the SMUFL ↔ IR coordinate seam)
///
/// A SMUFL glyph is registered to the **font baseline**: its origin (`x = 0`,
/// `y = 0` in the glyph's own space) is the point that must land on the node's
/// staff-space origin — e.g. a notehead's baseline runs through its vertical
/// centre, a gClef's through the G line. But [TextPainter.paint] places the
/// text box's **top-left** at the given offset, not the baseline; painting at
/// `Offset.zero` would drop every glyph down by the font ascent. We shift up by
/// the measured box-top→baseline distance so the glyph's SMUFL origin coincides
/// with the node origin (staff-space `y = 0`), independent of the font's line
/// metrics.
///
/// This is the render side of the single coordinate seam between SMUFL's native
/// **y-up** metrics and the IR's **y-down** space: the data generator
/// (`convertJsonToDart.mjs`) negates y so every glyph bbox/anchor is y-down in
/// the IR, and the renderer here aligns the baseline. Nothing in between deals
/// in SMUFL's y-up convention.
void _drawGlyph(Canvas canvas, GlyphElement element) {
  final textPainter = TextPainter(
    text: TextSpan(
      text: glyphFontCodeMap[element.glyph],
      style: _textStyleFor(element),
    ),
    textDirection: TextDirection.ltr,
  );
  textPainter.layout();
  // Distance (staff-space units) from the text box top to the alphabetic
  // baseline; the root canvas scale converts to pixels. Painting at -baseline
  // puts the glyph's SMUFL origin on the node origin.
  final baseline =
      textPainter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  textPainter.paint(canvas, Offset(0, -baseline));
  textPainter.dispose();
}

/// Builds a [TextStyle] for a glyph from its resolved [Styling]. Throws if the
/// glyph carries no fill color — see [_drawGlyph].
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
