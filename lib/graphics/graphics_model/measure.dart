import 'dart:ui' show Rect;

import 'package:music_notes_2/graphics/graphics_model/canvas_primitives.dart';

typedef MeasureAttributesGeometry = ({Rect boundingBox});

typedef MeasureGeometry = ({
  Rect boundingBox,
  List<Rect> staveBoundingBoxes,
  MeasureAttributesGeometry? attributesGeometry
});

class MeasureElement extends GroupElement {
  MeasureElement(super.pointOfOrigin, [super.elements]) : noteGrid = MeasureGrid(pointOfOrigin);

  MeasureGrid noteGrid;
  GroupElement? attributesColumn;

  @override
  List<Element> get elements {
    final aC = attributesColumn;
    return [noteGrid, if (aC != null) aC];
  }
}

class MeasureGrid extends GroupElement {
  MeasureGrid(super.pointOfOrigin, [super.elements]) : columns = GroupElement(pointOfOrigin);

  GroupElement columns;
}
