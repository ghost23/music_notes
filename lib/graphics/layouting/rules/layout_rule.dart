import '../../../musicXML/data.dart';
import '../../graphics_model/canvas_primitives.dart';

typedef LayoutResult = ({Element layoutElement, bool layoutComplete, LayoutRule layoutRule});

abstract class LayoutRule {
  bool isApplicable(MusicDataElement element);

  LayoutResult layout(MusicDataElement element, Element? layoutElement);
}
