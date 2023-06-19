import 'dart:ui';

import 'DrawingContext.dart';

double getLineSpacing(double fontSize) => fontSize / 4;

/// Get the y position for a staff system. The given staffNumber should be a number starting at 1.
double staffYPos(DrawingContext drawC, int staffNumber) => (drawC.staffHeight + drawC.staffsSpacing)*(staffNumber-1);

Paint debugPaint(Color color) {
  Paint debugPaint = Paint()..color = color;
  debugPaint.style = PaintingStyle.stroke;
  debugPaint.strokeWidth = 2;
  return debugPaint;
}