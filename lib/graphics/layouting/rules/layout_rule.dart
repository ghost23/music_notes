import 'package:music_notes_2/graphics/layouting/layouting_context.dart';

import '../../../musicXML/data.dart';
import '../../graphics_model/canvas_primitives.dart';

abstract class LayoutRule {
  bool isApplicable(MusicDataElement element);

  /// Layouts full or part of the given MusicDataElement.
  ///
  /// In order to do that, it is given a graphical context and in
  /// case this element had already been touched by another rule
  /// and a respective layout element had already been created,
  /// the rule is also given that element.
  Element layout(LayoutingContext context, MusicDataElement element, Element? existingLayoutElement);
}
