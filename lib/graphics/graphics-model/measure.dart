import 'dart:ui';

class MeasureGeometry {
  MeasureGeometry(this.boundingBox, this.staveBoundingBoxes);
  Rect boundingBox;
  List<Rect> staveBoundingBoxes;
  MeasureAttributesGeometry? attributesGeometry;
}

class MeasureAttributesGeometry {
  MeasureAttributesGeometry(this.boundingBox);
  Rect boundingBox;
}