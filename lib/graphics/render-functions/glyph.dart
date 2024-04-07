import 'package:flutter/material.dart';
import '../graphics-model/glyph.dart';
import '../generated/glyph-advance-widths.dart';
import '../generated/glyph-bboxes.dart';
import '../generated/glyph-definitions.dart';
import 'DrawingContext.dart';

/// Advances the width of the glyph
GlyphGeometry paintGlyph(DrawingContext drawC, Glyph glyph, {double yOffset = 0, bool noAdvance = false}) {
  final lS = drawC.lS;
  final textPainter = TextPainter(
    text: TextSpan(
      text: GLYPH_FONTCODE_MAP[glyph],
      style: TextStyle(
        fontFamily: 'Bravura',
        fontSize: drawC.staffHeight,
        height: 1,
        color: Colors.black,
      ),
    ),
    textDirection: TextDirection.ltr,
  );
  textPainter.layout();
  textPainter.paint(drawC.canvas, Offset(0, yOffset));
  final Offset xyTranslation = drawC.canvas.getTranslation().translate(0, yOffset);
  final bbox = GLYPH_BBOXES[glyph];
  final GlyphGeometry geom = GlyphGeometry(
      Rect.fromLTRB(
          lS * bbox!.southWest.dx + xyTranslation.dx,
          lS * bbox.northEast.dy + xyTranslation.dy + lS*2,
          lS * bbox.northEast.dx + xyTranslation.dx,
          lS * bbox.southWest.dy + xyTranslation.dy + lS*2
      )
  );
  textPainter.dispose();

  if(!noAdvance) {
    drawC.canvas.translate(calculateGlyphWidth(drawC, glyph), 0);
  }

  return geom;
}

double calculateGlyphWidth(DrawingContext drawC, Glyph glyph) =>
    GLYPH_ADVANCE_WIDTHS[glyph]! * drawC.lS;