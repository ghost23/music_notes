import 'package:flutter/material.dart';

import '../generated/glyph_bboxes.dart';
import '../generated/glyph_definitions.dart';
import '/graphics/generated/glyph_anchors.dart';

sealed class Element {
  Element(this.pointOfOrigin, this.lS, this.paint);

  Offset pointOfOrigin;
  double lS;
  Paint paint;

  Rect get boundingBox;
}

class GroupElement extends Element {
  GroupElement(pointOfOrigin, lS, this.elements) : super(pointOfOrigin, lS, Paint());

  List<Element> elements;

  @override
  Rect get boundingBox => elements.fold(Rect.zero, (value, element) => value.expandToInclude(element.boundingBox));
}

class PathElement extends Element {
  PathElement(super.pointOfOrigin, super.lS, super.paint, this.path);

  Path path;

  @override
  Rect get boundingBox => path.getBounds();
}

class LineElement extends Element {
  LineElement(super.pointOfOrigin, super.lS, super.paint, this.startPoint, this.endPoint);

  Offset startPoint;
  Offset endPoint;

  @override
  Rect get boundingBox => Rect.fromPoints(startPoint, endPoint);
}

class RectElement extends Element {
  RectElement(super.pointOfOrigin, super.lS, super.paint, this.rect);

  Rect rect;

  @override
  Rect get boundingBox => rect;
}

class GlyphElement extends Element {
  GlyphElement(pointOfOrigin, lS, this.style, this.glyph) : super(pointOfOrigin, lS, Paint());

  TextStyle style;
  Glyph glyph;

  GlyphAnchor get anchor => glyphAnchors[glyph] ?? const GlyphAnchor();

  @override
  Rect get boundingBox {
    final bbox = glyphBBoxes[glyph];
    Rect result = Rect.fromLTRB(lS * bbox!.southWest.dx, lS * bbox.northEast.dy + lS * 2, lS * bbox.northEast.dx,
        lS * bbox.southWest.dy + lS * 2);
    return result;
  }
}
