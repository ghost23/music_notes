import 'package:music_notes_2/graphics/graphics_model/measure.dart';

import '../../musicXML/data.dart';
import '../graphics_model/canvas_primitives.dart';
import 'layouting_context.dart';

GroupElement layoutScorePart(Part part, LayoutingContext context) {
  GroupElement partElement = GroupElement(context.drawPos, const []);

  for (Measure measure in part.measures) {
    context.currentMeasure = measure;
    final measureElement = buildMeasureElement(measure, partElement, context);
  }

  return partElement;
}

MeasureElement buildMeasureElement(Measure measure, GroupElement partElement, LayoutingContext context) {
  MeasureElement measureElement = MeasureElement(partElement.pointOfOrigin);
  if (measure.attributes != null) {
    measureElement.attributesColumn = GroupElement(measureElement.pointOfOrigin);
  }
  final columnNumber = calculateColumnNumber(measure, context);
  measureElement.noteGrid = MeasureGrid(
      measureElement.pointOfOrigin,
      List.generate(
          columnNumber,
              (index) => GroupElement(measureElement.pointOfOrigin), growable: false
      )
  );
  return measureElement;
}



int calculateColumnNumber(Measure measure, LayoutingContext context) {
  final columnsOnFourFour = context.latestAttributes.divisions! * 4;
  final currentTimeFactor = context.latestAttributes.time!.beats / context.latestAttributes.time!.beatType;
  final columnsOnCurrentTime = columnsOnFourFour * currentTimeFactor;
  if (columnsOnCurrentTime % 1 != 0) {
    // Not a whole number. Means, the divisions number does not work for the Time. This is an error!
    throw FormatException(
        'Found divisions of ${context.latestAttributes.divisions} on a Time of ${context.latestAttributes.time!.beats}/${context.latestAttributes.time!.beatType}, which does not work.');
  }
  return columnsOnCurrentTime.toInt();
}
