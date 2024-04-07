import 'package:music_notes_2/graphics/graphics_model/measure.dart';

import '../../../musicXML/data.dart';
import '../../graphics_model/canvas_primitives.dart';
import '../layouting_context.dart';
import 'layout_rule.dart';

class MeasureBasic extends LayoutRule {
  @override
  bool isApplicable(MusicDataElement element) {
    return element is Measure;
  }

  @override
  Element layout(LayoutingContext context, MusicDataElement element, Element? existingLayoutElement) {
    MeasureElement result = MeasureElement(context.drawPos);

    final columnsOnFourFour = drawC.latestAttributes.divisions! * 4;
    final currentTimeFactor = drawC.latestAttributes.time!.beats / drawC.latestAttributes.time!.beatType;
    final columnsOnCurrentTime = columnsOnFourFour * currentTimeFactor;
    if (columnsOnCurrentTime % 1 != 0) {
      // Not a whole number. Means, the divisions number does not work for the Time. This is an error!
      throw FormatException(
          'Found divisions of ${drawC.latestAttributes.divisions} on a Time of ${drawC.latestAttributes.time!.beats}/${drawC.latestAttributes.time!.beatType}, which does not work.');
    }
    final measureHasAttributes = measure.attributes != null;

    return result;
  }
}
