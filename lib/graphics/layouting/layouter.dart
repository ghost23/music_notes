import 'dart:ui';

import '../../musicXML/data.dart';
import '../graphics_model/canvas_primitives.dart';
import 'layouting_context.dart';

GroupElement layoutScorePart(Part part, LayoutingContext context) {
  GroupElement partElement = GroupElement(Offset.zero, context.lS, []);

  for (Measure measure in part.measures) {}

  return partElement;
}
