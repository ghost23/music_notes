import 'package:flutter/material.dart';
import 'package:music_notes_2/graphics/layouting/rules/layout_rule.dart';

import '../generated/glyph_bboxes.dart';
import '../generated/glyph_definitions.dart';
import '/graphics/generated/glyph_anchors.dart';

sealed class Element {
  Element(this.pointOfOrigin, this.paint);

  Offset pointOfOrigin;
  Paint paint;
  List<LayoutRule> influencers = [];

  Rect get boundingBox;
}

class GroupElement extends Element {
  GroupElement(pointOfOrigin, [this.elements = const []]) : super(pointOfOrigin, Paint());

  List<Element> elements;

  @override
  Rect get boundingBox => elements.fold(Rect.zero, (value, element) => value.expandToInclude(element.boundingBox));
}

class PathElement extends Element {
  PathElement(super.pointOfOrigin, super.paint, this.path);

  Path path;

  @override
  Rect get boundingBox => path.getBounds();
}

class LineElement extends Element {
  LineElement(super.pointOfOrigin, super.paint, this.startPoint, this.endPoint);

  Offset startPoint;
  Offset endPoint;

  @override
  Rect get boundingBox => Rect.fromPoints(startPoint, endPoint);
}

class RectElement extends Element {
  RectElement(super.pointOfOrigin, super.paint, this.rect);

  Rect rect;

  @override
  Rect get boundingBox => rect;
}

class GlyphElement extends Element {
  GlyphElement(pointOfOrigin, this.style, this.glyph) : super(pointOfOrigin, Paint());

  TextStyle style;
  Glyph glyph;

  GlyphAnchor get anchor => glyphAnchors[glyph] ?? const GlyphAnchor();

  @override
  Rect get boundingBox {
    final bbox = glyphBBoxes[glyph];
    Rect result = Rect.fromLTRB(bbox!.southWest.dx, bbox.northEast.dy + 2, bbox.northEast.dx, bbox.southWest.dy + 2);
    return result;
  }
}
