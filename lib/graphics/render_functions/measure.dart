import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../musicXML/data.dart';
import '../generated/engraving_defaults.dart';
import '../generated/glyph_advance_widths.dart';
import '../generated/glyph_definitions.dart';
import '../graphics_model/measure.dart';
import '../notes.dart';
import 'common.dart';
import 'drawing_context.dart';
import 'glyph.dart';
import 'note/note.dart';
import 'note/pitch_note.dart';
import 'note/rest_note.dart';
import 'staff.dart';

paintMeasure(Measure measure, DrawingContext drawC) {
  final (grid, positioned) = createGridForMeasure(measure, drawC);
  double leftEnd = 0;
  if (measure.attributes == null) {
    leftEnd = drawC.getTranslation().dx;
  }

  MeasureAttributesGeometry? attributesGeom;

  grid.forEachIndexed((columnIndex, column) {
    final measurements = column.whereType<PitchNote>().map((element) => calculateNoteWidth(drawC, element));
    final alignmentOffset = calculateColumnAlignment(drawC, measurements);
    drawC.canvas.translate(alignmentOffset.left.abs(), 0);
    column.forEachIndexed((index, measureContent) {
      bool isLastElement = index == column.length - 1;
      switch (measureContent.runtimeType) {
        case Barline _:
          break;
        case Attributes _:
          attributesGeom = paintMeasureAttributes(measureContent as Attributes, drawC);
          leftEnd = drawC.getTranslation().dx;
        case Direction _:
          paintDirection(measureContent as Direction, drawC);
        case PitchNote _:
          paintPitchNote(drawC, measureContent as PitchNote, noAdvance: true);
        case RestNote _:
          paintRestNote(drawC, measureContent as RestNote, noAdvance: !isLastElement);
        default:
          throw FormatException('${measureContent.runtimeType} is an invalid MeasureContent type');
      }
    });

    drawC.canvas.translate(alignmentOffset.right, 0);

    // TODO: Spacing between columns, currently static, probably needs to be dynamic
    // to justify measures for the whole line
    if (column.isNotEmpty && columnIndex < grid.length - 1) {
      drawC.canvas.translate(drawC.lS * 1, 0);
    }
  });

  final rightEnd = drawC.getTranslation().dx;
  final measureWidth = rightEnd - leftEnd;

  for (var xPosElement in positioned) {
    drawC.canvas.save();
    drawC.canvas.translate(-measureWidth * xPosElement.xPosition, 0);
    switch (xPosElement.measureContent.runtimeType) {
      case PitchNote _:
        paintPitchNote(drawC, xPosElement.measureContent as PitchNote, noAdvance: true);
      case RestNote _:
        drawC.canvas.translate(-glyphAdvanceWidths[Glyph.restHalf]! / 2, 0);
        paintRestNote(drawC, xPosElement.measureContent as RestNote, noAdvance: true);
      default:
        throw FormatException('${xPosElement.measureContent.runtimeType} is an invalid MeasureContent type');
    }
    drawC.canvas.restore();
  }

  final xyTranslation = drawC.getTranslation();
  final List<Rect> stavesBounds = [];
  for (var i = 0; i < drawC.latestAttributes.staves!; i++) {
    stavesBounds.add(Rect.fromLTRB(leftEnd, xyTranslation.dy + (drawC.staffHeight * i) + (drawC.staffsSpacing * i),
        rightEnd, xyTranslation.dy + drawC.staffHeight * (i + 1) + drawC.staffsSpacing * i));
  }
  final measureRectLT = Offset(leftEnd, xyTranslation.dy);
  final measureRectRB = Offset(
      rightEnd,
      xyTranslation.dy +
          (drawC.staffHeight * drawC.latestAttributes.staves!) +
          (drawC.staffsSpacing * (drawC.latestAttributes.staves! - 1)));

  final measureRect = Rect.fromPoints(measureRectLT, measureRectRB);
  final MeasureGeometry measureGeom =
      (boundingBox: measureRect, staveBoundingBoxes: stavesBounds, attributesGeometry: attributesGeom);
  if (attributesGeom != null) {
    //drawC.debugDrawBB(attributesGeom!.boundingBox);
  }
  drawC.measuresPerPart[drawC.currentPart].add(measureGeom);
}

Rect calculateColumnAlignment(DrawingContext drawC, Iterable<PitchNoteRenderMeasurements> measurements) {
  final leftOffset = measurements.fold<double>(0, (value, element) => min(value, element.boundingBox.left));
  final rightOffset = measurements.fold<double>(0, (value, element) => max(value, element.boundingBox.right));

  return Rect.fromLTRB(leftOffset, 0, rightOffset, 0);
}

(List<List<MeasureContent>> grid, List<XPositionedMeasureContent> positioned) createGridForMeasure(
    Measure measure, DrawingContext drawC) {
  final columnsOnFourFour = drawC.latestAttributes.divisions! * 4;
  final currentTimeFactor = drawC.latestAttributes.time!.beats / drawC.latestAttributes.time!.beatType;
  final columnsOnCurrentTime = columnsOnFourFour * currentTimeFactor;
  if (columnsOnCurrentTime % 1 != 0) {
    // Not a whole number. Means, the divisions number does not work for the Time. This is an error!
    throw FormatException(
        'Found divisions of ${drawC.latestAttributes.divisions} on a Time of ${drawC.latestAttributes.time!.beats}/${drawC.latestAttributes.time!.beatType}, which does not work.');
  }
  final measureHasAttributes = measure.attributes != null;
  final List<List<MeasureContent>> grid =
      List.generate(columnsOnCurrentTime.toInt() + (measureHasAttributes ? 1 : 0), (i) => []);
  final List<XPositionedMeasureContent> positioned = [];
  int currentColumnPointer = 0;
  int? chordDuration;
  List<MeasureContent> currentColumn = grid[currentColumnPointer];
  measure.contents.forEachIndexed((index, element) {
    if (currentColumnPointer >= grid.length && element.runtimeType != Backup && element.runtimeType != Barline) {
      throw FormatException(
          'currentColumnPointer can only point beyond end of grid length, if next element is Backup or Barline. But was: ${element.runtimeType.toString()}');
    } else if (currentColumnPointer < grid.length) {
      currentColumn = grid[currentColumnPointer];
    }
    switch (element.runtimeType) {
      case Barline _:
        currentColumn.add(element);
        break;
      case Attributes _:
        {
          currentColumn.add(element);
          currentColumnPointer++;
          break;
        }
      case Direction _:
        {
          currentColumn.add(element);
          break;
        }
      case RestNote _:
      case PitchNote _:
        {
          if (element is PitchNote) {
            currentColumn.add(element);
            if (index < measure.contents.length - 1) {
              final nextElement = measure.contents.elementAt(index + 1);
              if (nextElement is PitchNote) {
                element.beams.toList(); // This makes the lazy xml parser actually traverse all beams
                if (!element.chord) {
                  if (nextElement.chord) {
                    // next element is chord note, so we save the current
                    chordDuration = element.duration;
                  } else {
                    currentColumnPointer += element.duration;
                  }
                } else {
                  if (!nextElement.chord) {
                    // next element is not a chord note anymore, so apply saved chordDuration
                    if (chordDuration == null) {
                      throw const FormatException('End of a chord reached, should have chordDuration, but is null.');
                    }
                    currentColumnPointer += chordDuration!;
                    chordDuration = null;
                  }
                }
              } else {
                currentColumnPointer += element.duration;
              }
            } else {
              currentColumnPointer += element.duration;
            }
          } else if (element is RestNote) {
            if (columnsOnCurrentTime / element.duration == 1) {
              positioned.add(XPositionedMeasureContent(xPosition: 0.5, measureContent: element));
            } else {
              currentColumn.add(element);
            }
            currentColumnPointer += element.duration;
          }
          break;
        }
      case Forward _:
        {
          if (element is Forward) {
            currentColumnPointer += element.duration;
          }
          break;
        }
      case Backup _:
        {
          if (element is Backup) {
            currentColumnPointer -= element.duration;
          }
          break;
        }
      default:
        {
          throw FormatException('${element.runtimeType} is an unknown MeasureContent type');
        }
    }
  });
  return (grid, positioned);
}

MeasureAttributesGeometry? paintMeasureAttributes(Attributes attributes, DrawingContext drawC) {
  final fifths = attributes.key?.fifths;
  final Attributes(:staves, :clefs) = attributes;
  final lS = drawC.lS;

  if (staves != null && clefs != null) {
    final sortedClefs = clefs.sorted((a, b) => a.staffNumber - b.staffNumber);

    Rect? boundingBox;

    if (fifths != null) {
      Rect? clefBB;

      sortedClefs.forEachIndexed((index, clef) {
        final glyphBB = paintGlyph(drawC, clefToGlyphMap[clef.sign]!,
            yOffset: staffYPos(drawC, clef.staffNumber) + (lS * clefToPositionOffsetMap[clef.sign]!),
            noAdvance: index < (clefs.length - 1));
        if (clefBB == null) {
          clefBB = glyphBB.boundingBox;
        } else {
          clefBB = clefBB!.expandToInclude(glyphBB.boundingBox);
        }
      });
      boundingBox = clefBB;
      drawC.canvas.translate(drawC.lS * 1, 0);

      Rect? accidentalBB;
      sortedClefs.forEachIndexed((index, clef) {
        drawC.canvas.translate(0, staffYPos(drawC, clef.staffNumber));
        final glyphBB = paintAccidentalsForTone(drawC, clef.sign, fifths, noAdvance: index < (clefs.length - 1));
        drawC.canvas.translate(0, -staffYPos(drawC, clef.staffNumber));
        if (glyphBB != null) {
          if (accidentalBB == null) {
            accidentalBB = glyphBB;
          } else {
            accidentalBB = accidentalBB!.expandToInclude(glyphBB);
          }
        }
      });
      if (accidentalBB != null && !accidentalBB!.isEmpty) {
        boundingBox = boundingBox!.expandToInclude(accidentalBB!);
        drawC.canvas.translate(drawC.lS * 1, 0);
      }
    }

    if (attributes.time != null) {
      Rect? timesBB;
      sortedClefs.forEachIndexed((index, clef) {
        drawC.canvas.translate(0, staffYPos(drawC, clef.staffNumber));
        final glyphBB = paintTimeSignature(drawC, attributes, noAdvance: index < (clefs.length - 1));
        drawC.canvas.translate(0, -staffYPos(drawC, clef.staffNumber));
        if (timesBB == null) {
          timesBB = glyphBB;
        } else {
          timesBB = timesBB!.expandToInclude(glyphBB);
        }
      });

      if (timesBB != null) {
        boundingBox = boundingBox!.expandToInclude(timesBB!);
      }
      drawC.canvas.translate(drawC.lS * 1, 0);
    }

    if (boundingBox != null) {
      final MeasureAttributesGeometry measureAttrGeom = (boundingBox: boundingBox);
      return measureAttrGeom;
    } else {
      return null;
    }
  }

  return null;
}

calculateMeasureAttributesWidth(Attributes attributes, DrawingContext drawC) {
  return (attributes.key != null ? calculateAccidentalsForToneWidth(drawC, attributes.key!.fifths) : 0) +
      (attributes.key != null && attributes.time != null ? drawC.lS * engravingDefaults.barlineSeparation * 2 : 0) +
      (attributes.time != null ? calculateTimeSignatureWidth(drawC, attributes) : 0);
}

paintDirection(Direction direction, DrawingContext drawC) {}
