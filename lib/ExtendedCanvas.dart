import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

/// We use this Extended version of the Canvas as long
/// as the original one gives us no access to the current
/// translation: https://github.com/flutter/flutter/issues/38721
class XCanvas implements Canvas {
  Point _currentTranslation;
  Canvas _canvas;
  XCanvas(Canvas canvas) {
    _currentTranslation = Point(0,0);
    _canvas = canvas;
  }

  @override
  void translate(double dx, double dy) {
    _canvas.translate(dx, dy);
    _currentTranslation += Point(dx, dy);
  }

  Point getTranslation() {
    return _currentTranslation;
  }

  @override
  void clipPath(Path path, {bool doAntiAlias = true}) {
    _canvas.clipPath(path, doAntiAlias: doAntiAlias);
  }

  @override
  void clipRRect(RRect rrect, {bool doAntiAlias = true}) {
    _canvas.clipRRect(rrect, doAntiAlias: doAntiAlias);
  }

  @override
  void clipRect(Rect rect, {ClipOp clipOp = ClipOp.intersect, bool doAntiAlias = true}) {
    _canvas.clipRect(rect, clipOp: clipOp, doAntiAlias: doAntiAlias);
  }

  @override
  void drawArc(Rect rect, double startAngle, double sweepAngle, bool useCenter, Paint paint) {
    _canvas.drawArc(rect, startAngle, sweepAngle, useCenter, paint);
  }

  @override
  void drawAtlas(Image atlas, List<RSTransform> transforms, List<Rect> rects, List<Color> colors, BlendMode blendMode, Rect cullRect, Paint paint) {
    _canvas.drawAtlas(atlas, transforms, rects, colors, blendMode, cullRect, paint);
  }

  @override
  void drawCircle(Offset c, double radius, Paint paint) {
    _canvas.drawCircle(c, radius, paint);
  }

  @override
  void drawColor(Color color, BlendMode blendMode) {
    _canvas.drawColor(color, blendMode);
  }

  @override
  void drawDRRect(RRect outer, RRect inner, Paint paint) {
    _canvas.drawDRRect(outer, inner, paint);
  }

  @override
  void drawImage(Image image, Offset offset, Paint paint) {
    _canvas.drawImage(image, offset, paint);
  }

  @override
  void drawImageNine(Image image, Rect center, Rect dst, Paint paint) {
    _canvas.drawImageNine(image, center, dst, paint);
  }

  @override
  void drawImageRect(Image image, Rect src, Rect dst, Paint paint) {
    _canvas.drawImageRect(image, src, dst, paint);
  }

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {
    _canvas.drawLine(p1, p2, paint);
  }

  @override
  void drawOval(Rect rect, Paint paint) {
    _canvas.drawOval(rect, paint);
  }

  @override
  void drawPaint(Paint paint) {
    _canvas.drawPaint(paint);
  }

  @override
  void drawParagraph(Paragraph paragraph, Offset offset) {
    _canvas.drawParagraph(paragraph, offset);
  }

  @override
  void drawPath(Path path, Paint paint) {
    _canvas.drawPath(path, paint);
  }

  @override
  void drawPicture(Picture picture) {
    _canvas.drawPicture(picture);
  }

  @override
  void drawPoints(PointMode pointMode, List<Offset> points, Paint paint) {
    _canvas.drawPoints(pointMode, points, paint);
  }

  @override
  void drawRRect(RRect rrect, Paint paint) {
    _canvas.drawRRect(rrect, paint);
  }

  @override
  void drawRawAtlas(Image atlas, Float32List rstTransforms, Float32List rects, Int32List colors, BlendMode blendMode, Rect cullRect, Paint paint) {
    _canvas.drawRawAtlas(atlas, rstTransforms, rects, colors, blendMode, cullRect, paint);
  }

  @override
  void drawRawPoints(PointMode pointMode, Float32List points, Paint paint) {
    _canvas.drawRawPoints(pointMode, points, paint);
  }

  @override
  void drawRect(Rect rect, Paint paint) {
    _canvas.drawRect(rect, paint);
  }

  @override
  void drawShadow(Path path, Color color, double elevation, bool transparentOccluder) {
    _canvas.drawShadow(path, color, elevation, transparentOccluder);
  }

  @override
  void drawVertices(Vertices vertices, BlendMode blendMode, Paint paint) {
    _canvas.drawVertices(vertices, blendMode, paint);
  }

  @override
  int getSaveCount() {
    return _canvas.getSaveCount();
  }

  @override
  void restore() {
    _canvas.restore();
  }

  @override
  void rotate(double radians) {
    _canvas.rotate(radians);
  }

  @override
  void save() {
    _canvas.save();
  }

  @override
  void saveLayer(Rect bounds, Paint paint) {
    _canvas.saveLayer(bounds, paint);
  }

  @override
  void scale(double sx, [double sy]) {
    _canvas.scale(sx, sy);
  }

  @override
  void skew(double sx, double sy) {
    _canvas.skew(sx, sy);
  }

  @override
  void transform(Float64List matrix4) {
    _canvas.transform(matrix4);
  }
}