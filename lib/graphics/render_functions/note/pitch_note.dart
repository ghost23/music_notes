import 'dart:ui';

import '../../../musicXML/data.dart';
import '../../generated/engraving_defaults.dart';
import '../../generated/glyph_advance_widths.dart';
import '../../generated/glyph_anchors.dart';
import '../../graphics_model/note.dart';
import '../../notes.dart';
import '../beam.dart';
import '../drawing_context.dart';
import '../glyph.dart';
import 'ledger.dart';
import 'note.dart';

NoteGeometry paintPitchNote(DrawingContext drawC, PitchNote note, {bool noAdvance = false}) {
  final notePosition = note.notePosition;
  final lS = drawC.lS;
  final tone = drawC.latestAttributes.key!.fifths;
  final staff = drawC.latestAttributes.clefs!.firstWhere((clef) => clef.staffNumber == note.staff).sign;
  int offset = calculateYOffsetForNote(staff, notePosition.positionalValue);
  bool drawNoteWithStem = note.beams.isEmpty;

  Rect boundingBox;

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

  final noteHeadGeom = paintGlyph(
    drawC,
    noteGlyph,
    yOffset: (lS / 2) * offset,
    noAdvance: true,
  );
  boundingBox = noteHeadGeom.boundingBox;

  if (note.beams.isNotEmpty) {
    final noteAnchor = glyphAnchors[noteGlyph];

    final currentBeamPointMapForThisId = drawC.currentBeamPointsPerID[note.beams.first.id] ?? {};
    drawC.currentBeamPointsPerID[note.beams.first.id] = currentBeamPointMapForThisId;

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
          drawC.localToGlobal(Offset(0, (lS / 2) * offset)),
          noteAnchor!,
          beamAbove,
        ),
      );
    }

    final openBeams = getOpenBeams(currentBeamPointMapForThisId);

    if (openBeams.isEmpty) {
      for (final beamPoints in currentBeamPointMapForThisId.entries) {
        final BeamPoint start = beamPoints.value.first;
        final BeamPoint end = beamPoints.value.last;

        final double stemLength =
            lS * 2 + beamPoints.key * (engravingDefaults.beamThickness * lS + engravingDefaults.beamSpacing * lS);

        Offset startOffset, endOffset;
        if (start.drawAbove) {
          startOffset = drawC.globalToLocal(Offset(
            start.notePosition.dx + start.noteAnchor.stemUpSE.dx * lS,
            start.notePosition.dy +
                (drawC.staffHeight / 2) -
                stemLength -
                (engravingDefaults.beamThickness * lS) +
                start.noteAnchor.stemUpSE.dy * lS,
          ));
          endOffset = drawC.globalToLocal(Offset(
            end.notePosition.dx + end.noteAnchor.stemUpSE.dx * lS,
            end.notePosition.dy +
                (drawC.staffHeight / 2) -
                stemLength -
                (engravingDefaults.beamThickness * lS) +
                end.noteAnchor.stemUpSE.dy * lS,
          ));
        } else {
          startOffset = drawC.globalToLocal(Offset(
            start.notePosition.dx + start.noteAnchor.stemDownNW.dx * lS,
            start.notePosition.dy + (drawC.staffHeight / 2) + stemLength + start.noteAnchor.stemDownNW.dy * lS,
          ));
          endOffset = drawC.globalToLocal(Offset(
            end.notePosition.dx + end.noteAnchor.stemDownNW.dx * lS,
            end.notePosition.dy + (drawC.staffHeight / 2) + stemLength + end.noteAnchor.stemDownNW.dy * lS,
          ));
        }

        paintBeam(drawC, startOffset, endOffset);

        for (final beamPoint in beamPoints.value) {
          Offset stemOffsetStart, stemOffsetEnd;
          if (beamPoint.drawAbove) {
            stemOffsetStart = drawC.globalToLocal(Offset(
              beamPoint.notePosition.dx + beamPoint.noteAnchor.stemUpSE.dx * lS,
              beamPoint.notePosition.dy + (drawC.staffHeight / 2) + beamPoint.noteAnchor.stemUpSE.dy * lS,
            ));

            final startOffsetGlobal = drawC.localToGlobal(startOffset);
            final endOffsetGlobal = drawC.localToGlobal(endOffset);

            double stemOffsetYEnd =
                ((beamPoint.notePosition.dx + beamPoint.noteAnchor.stemUpSE.dx * lS) - startOffsetGlobal.dx) *
                        ((endOffsetGlobal.dy - startOffsetGlobal.dy) / (endOffsetGlobal.dx - startOffsetGlobal.dx)) +
                    startOffsetGlobal.dy;

            stemOffsetEnd = drawC.globalToLocal(Offset(
              beamPoint.notePosition.dx + beamPoint.noteAnchor.stemUpSE.dx * lS,
              stemOffsetYEnd,
            ));
          } else {
            stemOffsetStart = drawC.globalToLocal(Offset(
              beamPoint.notePosition.dx + beamPoint.noteAnchor.stemDownNW.dx * lS,
              beamPoint.notePosition.dy + (drawC.staffHeight / 2) + beamPoint.noteAnchor.stemDownNW.dy * lS,
            ));

            final startOffsetGlobal = drawC.localToGlobal(startOffset);
            final endOffsetGlobal = drawC.localToGlobal(endOffset);

            double stemOffsetYEnd =
                ((beamPoint.notePosition.dx + beamPoint.noteAnchor.stemDownNW.dx * lS) - startOffsetGlobal.dx) *
                        ((endOffsetGlobal.dy - startOffsetGlobal.dy) / (endOffsetGlobal.dx - startOffsetGlobal.dx)) +
                    startOffsetGlobal.dy +
                    engravingDefaults.beamThickness * lS;

            stemOffsetEnd = drawC.globalToLocal(Offset(
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

  Rect? ledgerBB = paintLedgers(drawC, staff, tone, notePosition);
  if (ledgerBB != null) boundingBox = boundingBox.expandToInclude(ledgerBB);

  if (shouldPaintAccidental(drawC, staff, notePosition)) {
    final accidentalGlyph = accidentalGlyphMap[notePosition.accidental]!;

    drawC.canvas.translate(-glyphAdvanceWidths[accidentalGlyph]! * lS - engravingDefaults.barlineSeparation * lS, 0);

    boundingBox = boundingBox.expandToInclude(paintGlyph(
      drawC,
      accidentalGlyph,
      yOffset: (lS / 2) * calculateYOffsetForNote(staff, notePosition.positionalValue),
      noAdvance: true,
    ).boundingBox);
  }

  drawC.canvas.translate(
    0,
    -(drawC.staffHeight + drawC.staffsSpacing) * (note.staff - 1),
  );

  if (noAdvance) {
    drawC.canvas.restore();
  }

  drawC.debugDrawBB(boundingBox);

  return (boundingBox: boundingBox, noteHead: noteHeadGeom);
}
