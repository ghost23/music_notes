import 'dart:ui' show Rect;

typedef MeasureAttributesGeometry = ({Rect boundingBox});

typedef MeasureGeometry = ({
  Rect boundingBox,
  List<Rect> staveBoundingBoxes,
  MeasureAttributesGeometry? attributesGeometry
});
