import 'package:flutter/painting.dart';

import '../generated/glyph_definitions.dart';
import '/graphics/graphics_model/canvas_primitives.dart';

void drawTranslated(Canvas canvas, Element element, VoidCallback command) {
  canvas.translate(element.pointOfOrigin.dx, element.pointOfOrigin.dy);
  command();
  canvas.translate(-element.pointOfOrigin.dx, -element.pointOfOrigin.dy);
}

void drawPathElement(Canvas canvas, PathElement element) {
  drawTranslated(canvas, element, () => canvas.drawPath(element.path, element.paint));
}

void drawLineElement(Canvas canvas, LineElement element) {
  drawTranslated(canvas, element, () => canvas.drawLine(element.startPoint, element.endPoint, element.paint));
}

void drawRectElement(Canvas canvas, RectElement element) {
  drawTranslated(canvas, element, () => canvas.drawRect(element.rect, element.paint));
}

void drawGlyphElement(Canvas canvas, GlyphElement element) {
  drawTranslated(canvas, element, () {
    final textPainter = TextPainter(
      text: TextSpan(
        text: glyphFontCodeMap[element.glyph],
        style: element.style,
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset.zero);
    textPainter.dispose();
  });
}

void drawGroupElement(Canvas canvas, GroupElement element) {
  for (Element child in element.elements) {
    switch (child) {
      case PathElement():
        drawTranslated(canvas, element, () => drawPathElement(canvas, child));
      case GroupElement():
        drawTranslated(canvas, element, () => drawGroupElement(canvas, child));
      case LineElement():
        drawTranslated(canvas, element, () => drawLineElement(canvas, child));
      case RectElement():
        drawTranslated(canvas, element, () => drawRectElement(canvas, child));
      case GlyphElement():
        drawTranslated(canvas, element, () => drawGlyphElement(canvas, child));
    }
  }
}
