import 'package:flutter/material.dart';
import '../../musicXML/data.dart';
import '../generated/engraving-defaults.dart';
import '../generated/glyph-advance-widths.dart';
import '../generated/glyph-anchors.dart';
import '../generated/glyph-bboxes.dart';
import '../generated/glyph-range-definitions.dart';
import '../notes.dart';
import 'DrawingContext.dart';
import 'beam.dart';
import 'glyph.dart';

paintLedgers(
    DrawingContext drawC, Clefs staff, Fifths tone, NotePosition note) {
  int numLedgersToDraw = 0;
  switch (staff) {
    case Clefs.G:
      {
        if (note.positionalValue >
            topStaffLineNoteGClef.positionalValue + 1) {
          numLedgersToDraw = ((note.positionalValue -
                      topStaffLineNoteGClef.positionalValue) /
                  2)
              .floor();
        } else if (note.positionalValue <
            bottomStaffLineNoteGClef.positionalValue - 1) {
          numLedgersToDraw = ((note.positionalValue -
                      bottomStaffLineNoteGClef.positionalValue) /
                  2)
              .ceil();
        }
        break;
      }
    case Clefs.F:
      {
        if (note.positionalValue >
            topStaffLineNoteFClef.positionalValue + 1) {
          numLedgersToDraw = ((note.positionalValue -
                      topStaffLineNoteFClef.positionalValue) /
                  2)
              .floor();
        } else if (note.positionalValue <
            bottomStaffLineNoteFClef.positionalValue - 1) {
          numLedgersToDraw = ((note.positionalValue -
                      bottomStaffLineNoteFClef.positionalValue) /
                  2)
              .ceil();
        }
      }
  }

  double lineSpacing = drawC.lS;
  final paint = Paint()..color = Colors.black;
  paint.strokeWidth = lineSpacing * ENGRAVING_DEFAULTS.staffLineThickness;
  double noteWidth =
      GLYPH_ADVANCE_WIDTHS[singleNoteHeadByLength[note.length]!]! * lineSpacing;
  double ledgerLength = noteWidth * 1.5;
  for (int i = numLedgersToDraw; i != 0;) {
    if (i < 0) {
      double pos = (-i * 2) * (lineSpacing / 2) + drawC.staffHeight;
      drawC.canvas.drawLine(Offset(-((ledgerLength - noteWidth) / 2), pos),
          Offset(-((ledgerLength - noteWidth) / 2) + ledgerLength, pos), paint);
      i++;
    } else {
      double pos = -(i * 2) * (lineSpacing / 2);
      drawC.canvas.drawLine(Offset(-((ledgerLength - noteWidth) / 2), pos),
          Offset(-((ledgerLength - noteWidth) / 2) + ledgerLength, pos), paint);
      i--;
    }
  }
}

class PitchNoteRenderMeasurements {
  PitchNoteRenderMeasurements(this.boundingBox, this.noteAnchors);

  final Rect boundingBox;
  final GlyphAnchor ?noteAnchors;
}

paintPitchNote(DrawingContext drawC, PitchNote note, {bool noAdvance = false}) {
  final notePosition = note.notePosition;
  final lS = drawC.lS;
  final tone = drawC.latestAttributes.key!.fifths;
  final staff = drawC.latestAttributes.clefs!
      .firstWhere((clef) => clef.staffNumber == note.staff)
      .sign;
  int offset = calculateYOffsetForNote(staff, notePosition.positionalValue);
  bool drawNoteWithStem = note.beams.isEmpty;

  if (noAdvance) {
    drawC.canvas.save();
  }

  drawC.canvas.translate(
    0,
    (drawC.staffHeight + drawC.staffsSpacing) * (note.staff - 1),
  );

  final noteGlyph = drawNoteWithStem
      ? (note.stem == StemValue.up
          ? singleNoteUpByLength[notePosition.length]!
          : singleNoteDownByLength[notePosition.length]!)
      : singleNoteHeadByLength[notePosition.length]!;

  paintGlyph(
    drawC,
    noteGlyph,
    yOffset: (lS / 2) * offset,
    noAdvance: true,
  );

  if (note.beams.isNotEmpty) {
    final noteAnchor = GLYPH_ANCHORS[noteGlyph];

    final currentBeamPointMapForThisId =
        drawC.currentBeamPointsPerID[note.beams.first.id] ?? {};
    drawC.currentBeamPointsPerID[note.beams.first.id] =
        currentBeamPointMapForThisId;

    final beamAbove = currentBeamPointMapForThisId.isNotEmpty
        ? currentBeamPointMapForThisId[1]!.first.drawAbove
        : note.stem == StemValue.up;
    for (final elmt in note.beams) {
      if (currentBeamPointMapForThisId[elmt.number] == null) {
        currentBeamPointMapForThisId[elmt.number] = [];
      }
      currentBeamPointMapForThisId[elmt.number]!.add(
        BeamPoint(
          elmt,
          drawC.canvas.localToGlobal(Offset(0, (lS / 2) * offset)),
          noteAnchor!,
          beamAbove,
        ),
      );
    }

    final openBeams = getOpenBeams(currentBeamPointMapForThisId);

    if (openBeams.isEmpty) {
      for(final beamPoints in currentBeamPointMapForThisId.entries) {
        final BeamPoint start = beamPoints.value.first;
        final BeamPoint end = beamPoints.value.last;

        final double stemLength = lS*2 + beamPoints.key * (ENGRAVING_DEFAULTS.beamThickness*lS + ENGRAVING_DEFAULTS.beamSpacing*lS);

        Offset startOffset, endOffset;
        if (start.drawAbove) {
          startOffset = drawC.canvas.globalToLocal(Offset(
            start.notePosition.dx + start.noteAnchor.stemUpSE.dx * lS,
            start.notePosition.dy +
                (drawC.staffHeight/2) -
                stemLength - (ENGRAVING_DEFAULTS.beamThickness*lS) +
                start.noteAnchor.stemUpSE.dy * lS,
          ));
          endOffset = drawC.canvas.globalToLocal(Offset(
            end.notePosition.dx + end.noteAnchor.stemUpSE.dx * lS,
            end.notePosition.dy +
                (drawC.staffHeight/2) -
                stemLength - (ENGRAVING_DEFAULTS.beamThickness*lS) +
                end.noteAnchor.stemUpSE.dy * lS,
          ));
        } else {
          startOffset = drawC.canvas.globalToLocal(Offset(
            start.notePosition.dx + start.noteAnchor.stemDownNW.dx * lS,
            start.notePosition.dy +
                (drawC.staffHeight/2) +
                stemLength +
                start.noteAnchor.stemDownNW.dy * lS,
          ));
          endOffset = drawC.canvas.globalToLocal(Offset(
            end.notePosition.dx + end.noteAnchor.stemDownNW.dx * lS,
            end.notePosition.dy +
                (drawC.staffHeight/2) +
                stemLength +
                end.noteAnchor.stemDownNW.dy * lS,
          ));
        }

        paintBeam(drawC, startOffset, endOffset);

        for(final beamPoint in beamPoints.value) {
          Offset stemOffsetStart, stemOffsetEnd;
          if(beamPoint.drawAbove) {
            stemOffsetStart = drawC.canvas.globalToLocal(Offset(
              beamPoint.notePosition.dx + beamPoint.noteAnchor.stemUpSE.dx * lS,
              beamPoint.notePosition.dy +
                  (drawC.staffHeight/2) +
                  beamPoint.noteAnchor.stemUpSE.dy * lS,
            ));

            final startOffsetGlobal = drawC.canvas.localToGlobal(startOffset);
            final endOffsetGlobal = drawC.canvas.localToGlobal(endOffset);

            double stemOffsetYEnd = ((beamPoint.notePosition.dx + beamPoint.noteAnchor.stemUpSE.dx * lS) - startOffsetGlobal.dx) *
                ((endOffsetGlobal.dy - startOffsetGlobal.dy) / (endOffsetGlobal.dx - startOffsetGlobal.dx)) + startOffsetGlobal.dy;

            stemOffsetEnd = drawC.canvas.globalToLocal(Offset(
              beamPoint.notePosition.dx + beamPoint.noteAnchor.stemUpSE.dx * lS,
              stemOffsetYEnd,
            ));
          } else {
            stemOffsetStart = drawC.canvas.globalToLocal(Offset(
              beamPoint.notePosition.dx + beamPoint.noteAnchor.stemDownNW.dx * lS,
              beamPoint.notePosition.dy +
                  (drawC.staffHeight/2) +
                  beamPoint.noteAnchor.stemDownNW.dy * lS,
            ));

            final startOffsetGlobal = drawC.canvas.localToGlobal(startOffset);
            final endOffsetGlobal = drawC.canvas.localToGlobal(endOffset);

            double stemOffsetYEnd = ((beamPoint.notePosition.dx + beamPoint.noteAnchor.stemDownNW.dx * lS) - startOffsetGlobal.dx) *
                ((endOffsetGlobal.dy - startOffsetGlobal.dy) / (endOffsetGlobal.dx - startOffsetGlobal.dx)) +
                startOffsetGlobal.dy +
                ENGRAVING_DEFAULTS.beamThickness*lS;

            stemOffsetEnd = drawC.canvas.globalToLocal(Offset(
              beamPoint.notePosition.dx + beamPoint.noteAnchor.stemDownNW.dx * lS,
              stemOffsetYEnd,
            ));
          }

          paintStem(drawC, stemOffsetStart, stemOffsetEnd);
        }
      }

      // Everything has been drawn, now it is time to reset the
      // beam context list, so that it is ready for the next
      // beam group that might come.
      drawC.currentBeamPointsPerID.remove(note.beams.first.id);
    }
  }

  paintLedgers(drawC, staff, tone, notePosition);

  if (shouldPaintAccidental(drawC, staff, notePosition)) {
    final accidentalGlyph = accidentalGlyphMap[notePosition.accidental]!;

    drawC.canvas.translate(
        -GLYPH_ADVANCE_WIDTHS[accidentalGlyph]! * lS -
            ENGRAVING_DEFAULTS.barlineSeparation * lS,
        0);

    paintGlyph(
      drawC,
      accidentalGlyph,
      yOffset: (lS / 2) *
          calculateYOffsetForNote(staff, notePosition.positionalValue),
      noAdvance: true,
    );
  }

  drawC.canvas.translate(
    0,
    -(drawC.staffHeight + drawC.staffsSpacing) * (note.staff - 1),
  );

  if (noAdvance) {
    drawC.canvas.restore();
  }
}

double durationToRestLengthIndex(DrawingContext drawC, int duration) {
  return ((drawC.latestAttributes.divisions! * 4) / duration) / 2;
}

paintRestNote(DrawingContext drawC, RestNote note, {bool noAdvance = false}) {
  drawC.canvas.translate(
      0, (drawC.staffHeight + drawC.staffsSpacing) * (note.staff - 1));

  var restGlyph = GLYPHRANGE_MAP[GlyphRange.rests]!.glyphs[
      durationToRestLengthIndex(drawC, note.duration).round() +
          3]; // whole rest begins at index 3

  paintGlyph(drawC, restGlyph, noAdvance: noAdvance);

  drawC.canvas.translate(
      0, -(drawC.staffHeight + drawC.staffsSpacing) * (note.staff - 1));
}

bool shouldPaintAccidental(
    DrawingContext drawC, Clefs staff, NotePosition note) {
  if (note.accidental == Accidentals.none) return false;

  final tone = drawC.latestAttributes.key!.fifths;
  List<NotePosition> alreadyAppliedAccidentals = staff == Clefs.G
      ? mainToneAccidentalsMapForGClef[tone]!
      : mainToneAccidentalsMapForFClef[tone]!;
  final alreadyAppliedAccidentalExists = alreadyAppliedAccidentals.any(
      (accidental) =>
          accidental.tone == note.tone &&
          (accidental.accidental == note.accidental ||
              note.accidental == Accidentals.natural));
  return (!alreadyAppliedAccidentalExists &&
          note.accidental != Accidentals.natural) ||
      (alreadyAppliedAccidentalExists &&
          note.accidental == Accidentals.natural);
}

PitchNoteRenderMeasurements calculateNoteWidth(
    DrawingContext drawC, PitchNote note) {
  final notePosition = note.notePosition;
  final lineSpacing = drawC.lS;
  final staff = drawC.latestAttributes.clefs!
      .firstWhere((clef) => clef.staffNumber == note.staff)
      .sign;
  int offset = calculateYOffsetForNote(staff, notePosition.positionalValue);
  bool drawBeamedNote = note.beams.isEmpty;

  final noteGlyph = drawBeamedNote
      ? (note.stem == StemValue.up
          ? singleNoteUpByLength[notePosition.length]!
          : singleNoteDownByLength[notePosition.length]!)
      : singleNoteHeadByLength[notePosition.length]!;

  double leftBorder = 0;
  double rightBorder = GLYPH_ADVANCE_WIDTHS[noteGlyph]! * lineSpacing;
  double topBorder =
      (lineSpacing / 2) * offset + GLYPH_BBOXES[noteGlyph]!.northEast.dy;
  double bottomBorder =
      (lineSpacing / 2) * offset + GLYPH_BBOXES[noteGlyph]!.northEast.dy;

  if (shouldPaintAccidental(drawC, staff, notePosition)) {
    final accidentalGlyph = accidentalGlyphMap[notePosition.accidental]!;
    leftBorder = -GLYPH_ADVANCE_WIDTHS[accidentalGlyph]! * lineSpacing -
        ENGRAVING_DEFAULTS.barlineSeparation * lineSpacing;

    final potTopBorder = (lineSpacing / 2) *
            calculateYOffsetForNote(staff, notePosition.positionalValue) +
        GLYPH_BBOXES[accidentalGlyph]!.northEast.dy;

    final potBottomBorder = (lineSpacing / 2) *
            calculateYOffsetForNote(staff, notePosition.positionalValue) +
        GLYPH_BBOXES[accidentalGlyph]!.southWest.dy;

    topBorder = potTopBorder < topBorder ? potTopBorder : topBorder;
    bottomBorder =
        potBottomBorder < bottomBorder ? potBottomBorder : bottomBorder;
  }

  return PitchNoteRenderMeasurements(
    Rect.fromLTRB(leftBorder, topBorder, rightBorder, bottomBorder),
    !drawBeamedNote ? GLYPH_ANCHORS[noteGlyph]!.translate(Offset(0, (lineSpacing / 2) * offset)) : null,
  );
}

const stdNotePositionGClef =
    NotePosition(tone: BaseTones.B, octave: 2, length: NoteLength.quarter);
const stdNotePositionFClef =
    NotePosition(tone: BaseTones.D, octave: 1, length: NoteLength.quarter);

const Map<Clefs, NotePosition> stdNotePosition = {
  Clefs.G: stdNotePositionGClef,
  Clefs.F: stdNotePositionFClef,
};

const topStaffLineNoteGClef =
    NotePosition(tone: BaseTones.F, octave: 3, length: NoteLength.quarter);
const bottomStaffLineNoteGClef =
    NotePosition(tone: BaseTones.E, octave: 2, length: NoteLength.quarter);

const topStaffLineNoteFClef =
    NotePosition(tone: BaseTones.A, octave: 1, length: NoteLength.quarter);
const bottomStaffLineNoteFClef =
    NotePosition(tone: BaseTones.G, octave: 0, length: NoteLength.quarter);

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
  if (clef == Clefs.G) {
    diff = stdNotePositionGClef.positionalValue - positionalValue;
  } else if (clef == Clefs.F) {
    diff = stdNotePositionFClef.positionalValue - positionalValue;
  }
  return diff;
}
