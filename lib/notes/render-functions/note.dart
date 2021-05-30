import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:music_notes_2/notes/generated/glyph-range-definitions.dart';
import '../music-line.dart';
import 'glyph.dart';
import '../notes.dart';
import '../generated/engraving-defaults.dart';
import '../generated/glyph-advance-widths.dart';
import '../../musicXML/data.dart';

paintLedgers(DrawingContext drawC, Clefs staff, Fifths tone, NotePosition note) {
  int numLedgersToDraw = 0;
  switch (staff) {
    case Clefs.G: {
      if(note.positionalValue() > topStaffLineNoteGClef.positionalValue() + 1) {
        numLedgersToDraw = ((note.positionalValue() - topStaffLineNoteGClef.positionalValue()) / 2).floor();
      } else if(note.positionalValue() < bottomStaffLineNoteGClef.positionalValue() - 1) {
        numLedgersToDraw = ((note.positionalValue() - bottomStaffLineNoteGClef.positionalValue()) / 2).floor();
      }
      break;
    }
    case Clefs.F: {
      if(note.positionalValue() > topStaffLineNoteFClef.positionalValue() + 1) {
        numLedgersToDraw = ((note.positionalValue() - topStaffLineNoteFClef.positionalValue()) / 2).floor();
      } else if(note.positionalValue() < bottomStaffLineNoteFClef.positionalValue() - 1) {
        numLedgersToDraw = ((note.positionalValue() - bottomStaffLineNoteFClef.positionalValue()) / 2).floor();
      }
    }
  }

  double lineSpacing = drawC.lineSpacing;
  final paint = Paint()..color = Colors.black;
  paint.strokeWidth = lineSpacing * ENGRAVING_DEFAULTS.staffLineThickness;
  double noteWidth = GLYPH_ADVANCE_WIDTHS[singleNoteHeadByLength[note.length]!]!*lineSpacing;
  double ledgerLength = noteWidth * 1.5;
  for(int i = numLedgersToDraw; i != 0;) {
    if(i < 0) {
      double pos = (-i*2)*(lineSpacing/2) + drawC.staffHeight;
      drawC.canvas.drawLine(Offset(-((ledgerLength-noteWidth)/2), pos), Offset(-((ledgerLength-noteWidth)/2) + ledgerLength, pos), paint);
      i++;
    } else {
      double pos = -(i*2)*(lineSpacing/2);
      drawC.canvas.drawLine(Offset(-((ledgerLength-noteWidth)/2), pos), Offset(-((ledgerLength-noteWidth)/2) + ledgerLength, pos), paint);
      i--;
    }
  }
}

paintPitchNote(DrawingContext drawC, PitchNote note, {bool? stemUp, bool noAdvance=false}) {
  final notePosition = note.notePosition;
  final lineSpacing = drawC.lineSpacing;
  final tone = drawC.latestAttributes.key!.fifths;
  final staff = drawC.latestAttributes.clefs!.firstWhere((clef) => clef.staffNumber == note.staff).sign;
  int offset = calculateYOffsetForNote(staff, notePosition.positionalValue());
  bool decideStemUp = stemUp != null ? stemUp : offset < 8;

  if(noAdvance) {
    drawC.canvas.save();
  }

  drawC.canvas.translate(0, (drawC.staffHeight + drawC.staffsSpacing)*(note.staff-1));

  paintGlyph(
    drawC,
    // TODO: We should probably draw the stem up or down ourselves
    decideStemUp ? singleNoteUpByLength[notePosition.length]! : singleNoteDownByLength[notePosition.length]!,
    yOffset: (lineSpacing/2) * offset,
    noAdvance: true,
  );

  paintLedgers(drawC, staff, tone, notePosition);

  drawC.canvas.translate(GLYPH_ADVANCE_WIDTHS[singleNoteUpByLength[notePosition.length]!]!*lineSpacing, 0);


  if(shouldPaintAccidental(drawC, staff, notePosition)) {
    drawC.canvas.translate(ENGRAVING_DEFAULTS.barlineSeparation*lineSpacing, 0);

    paintGlyph(
      drawC,
      accidentalGlyphMap[notePosition.accidental]!,
      yOffset: (lineSpacing/2) * calculateYOffsetForNote(staff, notePosition.positionalValue()),
    );
  }

  drawC.canvas.translate(0, -(drawC.staffHeight + drawC.staffsSpacing)*(note.staff-1));

  if(noAdvance) {
    drawC.canvas.restore();
  }
}

double durationToRestLengthIndex(DrawingContext drawC, int duration) {
  return ((drawC.latestAttributes.divisions! * 4) / duration) / 2;
}

paintRestNote(DrawingContext drawC, RestNote note, {bool noAdvance=false}) {
  drawC.canvas.translate(0, (drawC.staffHeight + drawC.staffsSpacing)*(note.staff-1));

  var restGlyph = GLYPHRANGE_MAP[GlyphRange.rests]!.glyphs[durationToRestLengthIndex(drawC, note.duration).round()+3]; // whole rest begins at index 3

  paintGlyph(drawC, restGlyph, noAdvance: noAdvance);

  drawC.canvas.translate(0, -(drawC.staffHeight + drawC.staffsSpacing)*(note.staff-1));
}

bool shouldPaintAccidental(DrawingContext drawC, Clefs staff, NotePosition note) {
  if(note.accidental == Accidentals.none) return false;

  final tone = drawC.latestAttributes.key!.fifths;
  List<NotePosition> alreadyAppliedAccidentals = staff == Clefs.G ? mainToneAccidentalsMapForGClef[tone]! : mainToneAccidentalsMapForFClef[tone]!;
  final alreadyAppliedAccidentalExists = alreadyAppliedAccidentals.any(
          (accidental) =>
      accidental.tone == note.tone
          && (accidental.accidental == note.accidental || note.accidental == Accidentals.natural)
  );
  return
    (!alreadyAppliedAccidentalExists && note.accidental != Accidentals.natural) ||
        (alreadyAppliedAccidentalExists && note.accidental == Accidentals.natural);
}

double calculateNoteWidth(DrawingContext drawC, Clefs staff, NotePosition note) {
  double lineSpacing = drawC.lineSpacing;
  return
    calculateGlyphWidth(drawC, singleNoteUpByLength[note.length]!)
      + (shouldPaintAccidental(drawC, staff, note)
        ? ENGRAVING_DEFAULTS.barlineSeparation*lineSpacing + calculateGlyphWidth(drawC, accidentalGlyphMap[note.accidental]!)
        : 0
    );
}

const stdNotePositionGClef = NotePosition(tone: BaseTones.B, octave: 2, length: NoteLength.quarter);
const stdNotePositionFClef = NotePosition(tone: BaseTones.D, octave: 1, length: NoteLength.quarter);

const Map<Clefs, NotePosition> stdNotePosition = {
  Clefs.G: stdNotePositionGClef,
  Clefs.F: stdNotePositionFClef,
};

const topStaffLineNoteGClef = NotePosition(tone: BaseTones.F, octave: 3, length: NoteLength.quarter);
const bottomStaffLineNoteGClef = NotePosition(tone: BaseTones.E, octave: 2, length: NoteLength.quarter);

const topStaffLineNoteFClef = NotePosition(tone: BaseTones.A, octave: 1, length: NoteLength.quarter);
const bottomStaffLineNoteFClef = NotePosition(tone: BaseTones.G, octave: 0, length: NoteLength.quarter);

const Map<Clefs, NotePosition> topStaffLineNote = {
  Clefs.G: topStaffLineNoteGClef,
  Clefs.F: topStaffLineNoteFClef,
};

const Map<Clefs, NotePosition> bottomStaffLineNote = {
  Clefs.G: bottomStaffLineNoteGClef,
  Clefs.F: bottomStaffLineNoteFClef,
};

int calculateYOffsetForNote(Clefs clef, int positionalValue) {
  int diff = 0;
  if(clef == Clefs.G) {
    diff = stdNotePositionGClef.positionalValue() - positionalValue;
  } else if(clef == Clefs.F) {
    diff = stdNotePositionFClef.positionalValue() - positionalValue;
  }
  return diff;
}