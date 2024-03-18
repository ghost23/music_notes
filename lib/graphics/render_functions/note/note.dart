import 'package:flutter/material.dart';

import '../../../musicXML/data.dart';
import '../../generated/engraving_defaults.dart';
import '../../generated/glyph_advance_widths.dart';
import '../../generated/glyph_anchors.dart';
import '../../generated/glyph_bboxes.dart';
import '../../notes.dart';
import '../drawing_context.dart';

class PitchNoteRenderMeasurements {
  PitchNoteRenderMeasurements(this.boundingBox, this.noteAnchors);

  final Rect boundingBox;
  final GlyphAnchor? noteAnchors;
}

bool shouldPaintAccidental(DrawingContext drawC, Clefs staff, NotePosition note) {
  if (note.accidental == Accidentals.none) return false;

  final tone = drawC.latestAttributes.key!.fifths;
  List<NotePosition> alreadyAppliedAccidentals =
      staff == Clefs.G ? mainToneAccidentalsMapForGClef[tone]! : mainToneAccidentalsMapForFClef[tone]!;
  final alreadyAppliedAccidentalExists = alreadyAppliedAccidentals.any((accidental) =>
      accidental.tone == note.tone &&
      (accidental.accidental == note.accidental || note.accidental == Accidentals.natural));
  return (!alreadyAppliedAccidentalExists && note.accidental != Accidentals.natural) ||
      (alreadyAppliedAccidentalExists && note.accidental == Accidentals.natural);
}

PitchNoteRenderMeasurements calculateNoteWidth(DrawingContext drawC, PitchNote note) {
  final notePosition = note.notePosition;
  final lineSpacing = drawC.lS;
  final staff = drawC.latestAttributes.clefs!.firstWhere((clef) => clef.staffNumber == note.staff).sign;
  int offset = calculateYOffsetForNote(staff, notePosition.positionalValue);
  bool drawBeamedNote = note.beams.isEmpty;

  final noteGlyph = drawBeamedNote
      ? (note.stem == StemValue.up
          ? singleNoteUpByLength[notePosition.length]!
          : singleNoteDownByLength[notePosition.length]!)
      : singleNoteHeadByLength[notePosition.length]!;

  double leftBorder = 0;
  double rightBorder = glyphAdvanceWidths[noteGlyph]! * lineSpacing;
  double topBorder = (lineSpacing / 2) * offset + glyphBBoxes[noteGlyph]!.northEast.dy;
  double bottomBorder = (lineSpacing / 2) * offset + glyphBBoxes[noteGlyph]!.northEast.dy;

  if (shouldPaintAccidental(drawC, staff, notePosition)) {
    final accidentalGlyph = accidentalGlyphMap[notePosition.accidental]!;
    leftBorder =
        -glyphAdvanceWidths[accidentalGlyph]! * lineSpacing - engravingDefaults.barlineSeparation * lineSpacing;

    final potTopBorder = (lineSpacing / 2) * calculateYOffsetForNote(staff, notePosition.positionalValue) +
        glyphBBoxes[accidentalGlyph]!.northEast.dy;

    final potBottomBorder = (lineSpacing / 2) * calculateYOffsetForNote(staff, notePosition.positionalValue) +
        glyphBBoxes[accidentalGlyph]!.southWest.dy;

    topBorder = potTopBorder < topBorder ? potTopBorder : topBorder;
    bottomBorder = potBottomBorder < bottomBorder ? potBottomBorder : bottomBorder;
  }

  return PitchNoteRenderMeasurements(
    Rect.fromLTRB(leftBorder, topBorder, rightBorder, bottomBorder),
    !drawBeamedNote ? glyphAnchors[noteGlyph]!.translate(Offset(0, (lineSpacing / 2) * offset)) : null,
  );
}

const stdNotePositionGClef = NotePosition(tone: BaseTones.B, octave: 2, length: NoteLength.quarter);
const stdNotePositionFClef = NotePosition(tone: BaseTones.D, octave: 1, length: NoteLength.quarter);

int calculateYOffsetForNote(Clefs clef, int positionalValue) {
  int diff = 0;
  if (clef == Clefs.G) {
    diff = stdNotePositionGClef.positionalValue - positionalValue;
  } else if (clef == Clefs.F) {
    diff = stdNotePositionFClef.positionalValue - positionalValue;
  }
  return diff;
}
