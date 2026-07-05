import '../../musicXML/data.dart';
import '../graphics_model/canvas_primitives.dart' show GroupElement;
import '../graphics_model/semantic/structural.dart'
    show ColumnElement, MeasureElement;
import '../graphics_model/transform.dart' show NodeTransform;
import 'layouting_context.dart';

GroupElement layoutScorePart(Part part, LayoutingContext context) {
  GroupElement partElement = GroupElement(NodeTransform(translation: context.drawPos), const []);

  for (Measure measure in part.measures) {
    context.currentMeasure = measure;
    buildMeasureElement(measure, partElement, context);
  }

  return partElement;
}

/// Builds a [MeasureElement] for [measure] under [partElement].
///
/// Skeleton (WP3 will drive real layout): constructs one [ColumnElement] per
/// division slot (plus an attributes group when the measure carries an
/// `Attributes` change), using only the structural taxonomy from WP1-S3.
MeasureElement buildMeasureElement(Measure measure, GroupElement partElement, LayoutingContext context) {
  final origin = NodeTransform(translation: partElement.pointOfOrigin);

  final columnNumber = calculateColumnNumber(measure, context);
  final columns = List<ColumnElement>.generate(
    columnNumber,
    (_) => ColumnElement(origin),
    growable: false,
  );

  final GroupElement? attributes =
      measure.attributes != null ? GroupElement(origin) : null;

  return MeasureElement(origin, columns, attributes);
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
