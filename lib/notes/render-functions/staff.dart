import 'dart:ui';
import 'package:flutter/material.dart';
import 'common.dart';
import 'glyph.dart';
import 'note.dart';
import '../notes.dart';
import '../../ExtendedCanvas.dart';
import '../generated/glyph-advance-widths.dart';
import '../generated/glyph-definitions.dart';
import '../generated/engraving-defaults.dart';

/// Advances to the end of the lines
paintStaffLines(XCanvas canvas, Size size, double lineSpacing, bool noAdvance) {

  final paint = Paint()..color = Colors.black;
  paint.strokeWidth = lineSpacing * ENGRAVING_DEFAULTS.staffLineThickness;

  final lineWidth = size.width - canvas.getTranslation().x;

  canvas.drawLine(Offset(0, 0), Offset(lineWidth, 0), paint);
  canvas.drawLine(Offset(0, lineSpacing * 1), Offset(lineWidth, lineSpacing * 1), paint);
  canvas.drawLine(Offset(0, lineSpacing * 2), Offset(lineWidth, lineSpacing * 2), paint);
  canvas.drawLine(Offset(0, lineSpacing * 3), Offset(lineWidth, lineSpacing * 3), paint);
  canvas.drawLine(Offset(0, lineSpacing * 4), Offset(lineWidth, lineSpacing * 4), paint);

  if(!noAdvance) {
    canvas.translate(lineWidth, 0);
  }
}

enum BarLineTypes {
  thin, double, boldDouble, repeatRight, repeatLeft
}

/// Does translate to after its width
paintBarLine(XCanvas canvas, Size size, double staffHeight, List<Clefs> clefs, double staffsSpacing, BarLineTypes barline, bool noAdvance) {

  final lS = getLineSpacing(staffHeight);
  final paint = Paint()..color = Colors.black;

  final startOffset = Offset(0, 0);
  final endOffset = Offset(0, clefs.length > 1 ? staffHeight*2+staffsSpacing:staffHeight);

  // first line always a thin one

  if(noAdvance) {
    canvas.save();
  }

  if(barline == BarLineTypes.thin) {
    paint.strokeWidth = lS*ENGRAVING_DEFAULTS.thinBarlineThickness;
    canvas.drawLine(startOffset, endOffset, paint);
    canvas.translate(lS*ENGRAVING_DEFAULTS.thinBarlineThickness, 0);
  } else if(barline == BarLineTypes.double) {
    paint.strokeWidth = lS*ENGRAVING_DEFAULTS.thinBarlineThickness;
    canvas.drawLine(startOffset, endOffset, paint);
    canvas.translate(lS*ENGRAVING_DEFAULTS.barlineSeparation + lS*ENGRAVING_DEFAULTS.thinBarlineThickness, 0);
    canvas.drawLine(startOffset, endOffset, paint);
    canvas.translate(lS*ENGRAVING_DEFAULTS.thinBarlineThickness, 0);
  } else if(barline == BarLineTypes.boldDouble) {
    paint.strokeWidth = lS*ENGRAVING_DEFAULTS.thinBarlineThickness;
    canvas.drawLine(startOffset, endOffset, paint);
    canvas.translate(lS*ENGRAVING_DEFAULTS.thinThickBarlineSeparation + lS*ENGRAVING_DEFAULTS.thinBarlineThickness, 0);
    paint.strokeWidth = lS*ENGRAVING_DEFAULTS.thickBarlineThickness;
    canvas.drawLine(startOffset, endOffset, paint);
    canvas.translate(lS*ENGRAVING_DEFAULTS.thickBarlineThickness, 0);
  } else if(barline == BarLineTypes.repeatRight) {
    paint.strokeWidth = lS*ENGRAVING_DEFAULTS.thickBarlineThickness;
    canvas.drawLine(startOffset, endOffset, paint);
    canvas.translate(lS*ENGRAVING_DEFAULTS.thinThickBarlineSeparation, 0);
    paint.strokeWidth = lS*ENGRAVING_DEFAULTS.thinBarlineThickness;
    canvas.drawLine(startOffset, endOffset, paint);
    canvas.translate(lS*ENGRAVING_DEFAULTS.repeatBarlineDotSeparation, 0);
    paintGlyph(canvas, size, staffHeight, Glyph.repeatDots);
    canvas.translate(lS*GLYPH_ADVANCE_WIDTHS[Glyph.repeatDots]!, 0);
  } else if(barline == BarLineTypes.repeatLeft) {
    paintGlyph(canvas, size, staffHeight, Glyph.repeatDots);
    canvas.translate(lS*GLYPH_ADVANCE_WIDTHS[Glyph.repeatDots]! + lS*ENGRAVING_DEFAULTS.repeatBarlineDotSeparation, 0);
    paint.strokeWidth = lS*ENGRAVING_DEFAULTS.thinBarlineThickness;
    canvas.drawLine(startOffset, endOffset, paint);
    canvas.translate(lS*ENGRAVING_DEFAULTS.thinBarlineThickness + lS*ENGRAVING_DEFAULTS.thinThickBarlineSeparation, 0);
    paint.strokeWidth = lS*ENGRAVING_DEFAULTS.thickBarlineThickness;
    canvas.drawLine(startOffset, endOffset, paint);
    canvas.translate(lS*ENGRAVING_DEFAULTS.thickBarlineThickness, 0);
  }

  if(noAdvance) {
    canvas.restore();
  }
}

paintAccidentalsForTone(XCanvas canvas, Size size, double staffHeight, Clefs staff, MainTones tone, {bool noAdvance = false}) {
  if(noAdvance) {
    canvas.save();
  }

  double lineSpacing = getLineSpacing(staffHeight);
  final accidentals = staff == Clefs.f ? mainToneAccidentalsMapForFClef[tone]! : mainToneAccidentalsMapForGClef[tone]!;
  accidentals.forEach((note) {
    if(note.accidental != Accidentals.none) {
      paintGlyph(
        canvas,
        size,
        staffHeight,
        accidentalGlyphMap[note.accidental],
        offset: Offset(
          0,
          ((lineSpacing/2) * calculateYOffsetForNote(staff, note)),
        ),
      );
    }
  });

  if(noAdvance) {
    canvas.restore();
  }
}