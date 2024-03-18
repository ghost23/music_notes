import 'package:flutter/material.dart';
import 'package:music_notes_2/graphics/graphics_model/canvas_primitives.dart';
import 'package:music_notes_2/graphics/graphics_model/glyph.dart';

import '../generated/glyph_advance_widths.dart';
import '../generated/glyph_anchors.dart';
import '../generated/glyph_bboxes.dart';
import '../generated/glyph_definitions.dart';
import 'common.dart';
import 'drawing_context.dart';

/// Advances the width of the glyphes
GlyphGeometry paintGlyph(DrawingContext drawC, Glyph glyph, {double yOffset = 0, bool noAdvance = false}) {
  final lS = drawC.lS;
  final textPainter = TextPainter(
    text: TextSpan(
      text: glyphFontCodeMap[glyph],
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
  final Offset xyTranslation = drawC.getTranslation().translate(0, yOffset);
  final bbox = glyphBBoxes[glyph];
  final anchor = glyphAnchors[glyph];
  final GlyphGeometry geom = (
    boundingBox: Rect.fromLTRB(
        lS * bbox!.southWest.dx + xyTranslation.dx,
        lS * bbox.northEast.dy + xyTranslation.dy + lS * 2,
        lS * bbox.northEast.dx + xyTranslation.dx,
        lS * bbox.southWest.dy + xyTranslation.dy + lS * 2),
    anchorInfo: anchor
  );
  textPainter.dispose();

  if (!noAdvance) {
    drawC.canvas.translate(calculateGlyphWidth(drawC, glyph), 0);
  }

  return geom;
}

GlyphElement createGlyphElement(double staffHeight, Glyph glyph, Offset position) {
  return GlyphElement(
    position,
    getLineSpacing(staffHeight),
    TextStyle(
      fontFamily: 'Bravura',
      fontSize: staffHeight,
      height: 1,
      color: Colors.black,
    ),
    glyph,
  );
}

double calculateGlyphWidth(DrawingContext drawC, Glyph glyph) => glyphAdvanceWidths[glyph]! * drawC.lS;
