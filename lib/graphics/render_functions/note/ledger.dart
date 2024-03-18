import 'package:flutter/material.dart';

import '../../../musicXML/data.dart';
import '../../generated/engraving_defaults.dart';
import '../../generated/glyph_advance_widths.dart';
import '../../notes.dart';
import '../drawing_context.dart';

const topStaffLineNoteGClef = NotePosition(tone: BaseTones.F, octave: 3, length: NoteLength.quarter);
const bottomStaffLineNoteGClef = NotePosition(tone: BaseTones.E, octave: 2, length: NoteLength.quarter);

const topStaffLineNoteFClef = NotePosition(tone: BaseTones.A, octave: 1, length: NoteLength.quarter);
const bottomStaffLineNoteFClef = NotePosition(tone: BaseTones.G, octave: 0, length: NoteLength.quarter);

Rect? paintLedgers(DrawingContext drawC, Clefs staff, Fifths tone, NotePosition note) {
  int numLedgersToDraw = 0;
  switch (staff) {
    case Clefs.G:
      {
        if (note.positionalValue > topStaffLineNoteGClef.positionalValue + 1) {
          numLedgersToDraw = ((note.positionalValue - topStaffLineNoteGClef.positionalValue) / 2).floor();
        } else if (note.positionalValue < bottomStaffLineNoteGClef.positionalValue - 1) {
          numLedgersToDraw = ((note.positionalValue - bottomStaffLineNoteGClef.positionalValue) / 2).ceil();
        }
        break;
      }
    case Clefs.F:
      {
        if (note.positionalValue > topStaffLineNoteFClef.positionalValue + 1) {
          numLedgersToDraw = ((note.positionalValue - topStaffLineNoteFClef.positionalValue) / 2).floor();
        } else if (note.positionalValue < bottomStaffLineNoteFClef.positionalValue - 1) {
          numLedgersToDraw = ((note.positionalValue - bottomStaffLineNoteFClef.positionalValue) / 2).ceil();
        }
      }
  }

  double lS = drawC.lS;
  final paint = Paint()..color = Colors.black;
  paint.strokeWidth = lS * engravingDefaults.staffLineThickness;
  double noteWidth = glyphAdvanceWidths[singleNoteHeadByLength[note.length]!]! * lS;
  double ledgerLength = noteWidth * 1.5;

  Rect? rect;

  for (int i = numLedgersToDraw; i != 0;) {
    double pos;
    if (i < 0) {
      pos = (-i * 2) * (lS / 2) + drawC.staffHeight;
      i++;
    } else {
      pos = -(i * 2) * (lS / 2);
      i--;
    }
    Offset start = Offset(-((ledgerLength - noteWidth) / 2), pos);
    Offset end = Offset(-((ledgerLength - noteWidth) / 2) + ledgerLength, pos);
    drawC.canvas.drawLine(start, end, paint);
    Rect bB = Rect.fromPoints(drawC.localToGlobal(start), drawC.localToGlobal(end));
    rect = rect == null ? bB : rect.expandToInclude(bB);
  }

  return rect;
}
