import '../../musicXML/data.dart';
import '../graphics_model/canvas_primitives.dart';
import 'layouting_context.dart';

GroupElement layoutScorePart(Part part, LayoutingContext context) {
  GroupElement partElement = GroupElement(context.drawPos, context.lS, []);

  for (Measure measure in part.measures) {}

  return partElement;
}
