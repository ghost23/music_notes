import 'dart:ui' show Offset, Rect;
import './canvas_primitives.dart' show GroupElement, Element;

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
  MeasureGrid(Offset super.pointOfOrigin, [List<GroupElement> super.columns = const []]);

  List<GroupElement> get columns => elements.whereType<GroupElement>().toList();
  set columns(List<GroupElement> newList) => elements = newList;
}
