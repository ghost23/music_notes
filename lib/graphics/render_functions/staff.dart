import 'package:flutter/material.dart';
import 'package:music_notes_2/graphics/generated/glyph_range_definitions.dart';

import '../../musicXML/data.dart';
import '../generated/engraving_defaults.dart';
import '../generated/glyph_advance_widths.dart';
import '../generated/glyph_definitions.dart';
import '../notes.dart';
import 'drawing_context.dart';
import 'glyph.dart';
import 'note/note.dart';

/// Advances to the end of the lines
paintStaffLines(DrawingContext drawC, bool noAdvance) {
  final lS = drawC.lS;
  final paint = Paint()..color = Colors.black;
  paint.strokeWidth = lS * engravingDefaults.staffLineThickness;

  final lineWidth = drawC.size.width - drawC.getTranslation().dx;

  drawC.canvas.drawLine(const Offset(0, 0), Offset(lineWidth, 0), paint);
  drawC.canvas.drawLine(Offset(0, lS * 1), Offset(lineWidth, lS * 1), paint);
  drawC.canvas.drawLine(Offset(0, lS * 2), Offset(lineWidth, lS * 2), paint);
  drawC.canvas.drawLine(Offset(0, lS * 3), Offset(lineWidth, lS * 3), paint);
  drawC.canvas.drawLine(Offset(0, lS * 4), Offset(lineWidth, lS * 4), paint);

  if (!noAdvance) {
    drawC.canvas.translate(lineWidth, 0);
  }
}

enum BarLineTypes { regular, lightLight, heavyHeavy, heavyLight, lightHeavy, heavy, dashed, repeatRight, repeatLeft }

/// Does translate to after its width
paintBarLine(DrawingContext drawC, Barline barline, bool noAdvance) {
  final lS = drawC.lS;
  final thinBarlineWidh = lS * engravingDefaults.thinBarlineThickness;
  final paint = Paint()..color = Colors.black;
  final staves = drawC.latestAttributes.staves!;

  const startOffset = Offset(0, 0);
  final endOffset = Offset(0, staves > 1 ? drawC.staffHeight * 2 + drawC.staffsSpacing : drawC.staffHeight);

  if (noAdvance) {
    drawC.canvas.save();
  }

  if (barline.barStyle == BarLineTypes.regular) {
    paint.strokeWidth = thinBarlineWidh;
    drawC.canvas.drawLine(startOffset, endOffset, paint);
    drawC.canvas.translate(thinBarlineWidh, 0);
  } else if (barline.barStyle == BarLineTypes.lightLight) {
    paint.strokeWidth = thinBarlineWidh;
    drawC.canvas.drawLine(startOffset, endOffset, paint);
    drawC.canvas.translate(lS * engravingDefaults.barlineSeparation + thinBarlineWidh, 0);
    drawC.canvas.drawLine(startOffset, endOffset, paint);
    drawC.canvas.translate(thinBarlineWidh, 0);
  } else if (barline.barStyle == BarLineTypes.lightHeavy) {
    paint.strokeWidth = thinBarlineWidh;
    drawC.canvas.drawLine(startOffset, endOffset, paint);
    drawC.canvas.translate(lS * engravingDefaults.barlineSeparation + thinBarlineWidh, 0);
    paint.strokeWidth = lS * engravingDefaults.thickBarlineThickness;
    drawC.canvas.drawLine(startOffset, endOffset, paint);
    drawC.canvas.translate(lS * engravingDefaults.thickBarlineThickness, 0);
  } else if (barline.barStyle == BarLineTypes.repeatRight) {
    paint.strokeWidth = lS * engravingDefaults.thickBarlineThickness;
    drawC.canvas.drawLine(startOffset, endOffset, paint);
    drawC.canvas.translate(lS * engravingDefaults.barlineSeparation, 0);
    paint.strokeWidth = thinBarlineWidh;
    drawC.canvas.drawLine(startOffset, endOffset, paint);
    drawC.canvas.translate(lS * engravingDefaults.repeatBarlineDotSeparation, 0);
    paintGlyph(drawC, Glyph.repeatDots);
    drawC.canvas.translate(lS * glyphAdvanceWidths[Glyph.repeatDots]!, 0);
  } else if (barline.barStyle == BarLineTypes.repeatLeft) {
    paintGlyph(drawC, Glyph.repeatDots);
    drawC.canvas
        .translate(lS * glyphAdvanceWidths[Glyph.repeatDots]! + lS * engravingDefaults.repeatBarlineDotSeparation, 0);
    paint.strokeWidth = thinBarlineWidh;
    drawC.canvas.drawLine(startOffset, endOffset, paint);
    drawC.canvas.translate(thinBarlineWidh + lS * engravingDefaults.barlineSeparation, 0);
    paint.strokeWidth = lS * engravingDefaults.thickBarlineThickness;
    drawC.canvas.drawLine(startOffset, endOffset, paint);
    drawC.canvas.translate(lS * engravingDefaults.thickBarlineThickness, 0);
  }

  if (noAdvance) {
    drawC.canvas.restore();
  }
}

calculateBarlineWidth(DrawingContext drawC, Barline barline) {
  final lS = drawC.lS;
  final thinBarlineWidh = lS * engravingDefaults.thinBarlineThickness;
  double width = 0;

  if (barline.barStyle == BarLineTypes.regular) {
    width = thinBarlineWidh;
  } else if (barline.barStyle == BarLineTypes.lightLight) {
    width = lS * engravingDefaults.barlineSeparation + thinBarlineWidh + thinBarlineWidh;
  } else if (barline.barStyle == BarLineTypes.heavyHeavy) {
    width = lS * engravingDefaults.thinThickBarlineSeparation +
        thinBarlineWidh +
        lS * engravingDefaults.thickBarlineThickness;
  } else if (barline.barStyle == BarLineTypes.repeatRight) {
    width = lS * engravingDefaults.thickBarlineThickness +
        lS * engravingDefaults.thinThickBarlineSeparation +
        thinBarlineWidh +
        lS * engravingDefaults.repeatBarlineDotSeparation +
        lS * glyphAdvanceWidths[Glyph.repeatDots]!;
  } else if (barline.barStyle == BarLineTypes.repeatLeft) {
    width = lS * glyphAdvanceWidths[Glyph.repeatDots]! +
        lS * engravingDefaults.repeatBarlineDotSeparation +
        thinBarlineWidh +
        lS * engravingDefaults.thinThickBarlineSeparation +
        lS * engravingDefaults.thickBarlineThickness;
  }

  return width;
}

/// Returns true if something was actually drawn
Rect? paintAccidentalsForTone(DrawingContext drawC, Clefs staff, Fifths tone, {bool noAdvance = false}) {
  if (noAdvance) {
    drawC.canvas.save();
  }

  Rect? boundingBox;

  double lineSpacing = drawC.lS;
  final accidentals = staff == Clefs.F ? mainToneAccidentalsMapForFClef[tone]! : mainToneAccidentalsMapForGClef[tone]!;
  for (var note in accidentals) {
    if (note.accidental != Accidentals.none) {
      final glyphBB = paintGlyph(
        drawC,
        accidentalGlyphMap[note.accidental]!,
        yOffset: (lineSpacing / 2) * calculateYOffsetForNote(staff, note.positionalValue),
      );
      if (boundingBox == null) {
        boundingBox = glyphBB.boundingBox;
      } else {
        boundingBox = boundingBox.expandToInclude(glyphBB.boundingBox);
      }
    }
  }

  if (noAdvance) {
    drawC.canvas.restore();
  }

  return boundingBox;
}

double calculateAccidentalsForToneWidth(DrawingContext drawC, Fifths tone) {
  double width = 0;
  final accidentals = mainToneAccidentalsMapForFClef[tone]!;
  for (var note in accidentals) {
    if (note.accidental != Accidentals.none) {
      width += calculateGlyphWidth(drawC, accidentalGlyphMap[note.accidental]!);
    }
  }
  return width;
}

Rect paintTimeSignature(DrawingContext drawC, Attributes attributes, {bool noAdvance = false}) {
  Rect timeBB = paintGlyph(drawC, glyphRangeMap[GlyphRange.timeSignatures]!.glyphs[attributes.time!.beats],
          yOffset: -drawC.lS, noAdvance: true)
      .boundingBox;
  timeBB = timeBB.expandToInclude(paintGlyph(
          drawC, glyphRangeMap[GlyphRange.timeSignatures]!.glyphs[attributes.time!.beatType],
          yOffset: drawC.lS, noAdvance: noAdvance)
      .boundingBox);
  return timeBB;
}

calculateTimeSignatureWidth(DrawingContext drawC, Attributes attributes) {
  return calculateGlyphWidth(drawC, glyphRangeMap[GlyphRange.timeSignatures]!.glyphs[attributes.time!.beatType]);
}
