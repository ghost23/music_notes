import 'package:flutter/material.dart';
import 'package:music_notes_2/notes/generated/engraving-defaults.dart';
import '../music-line.dart';

paintBeam(DrawingContext drawC, Offset start, Offset end) {
  final Paint paint = Paint();
  paint.color = Colors.black;
  paint.strokeWidth = 0;
  paint.style = PaintingStyle.fill;

  final Path path = Path();
  path.moveTo(start.dx, start.dy);
  path.lineTo(end.dx, end.dy);
  path.lineTo(end.dx, end.dy + drawC.lineSpacing*ENGRAVING_DEFAULTS.beamThickness);
  path.lineTo(start.dx, start.dy + drawC.lineSpacing*ENGRAVING_DEFAULTS.beamThickness);
  path.close();

  drawC.canvas.drawPath(path, paint);
}

paintStem(DrawingContext drawC, Offset start, Offset end) {
  final Paint paint = Paint();
  paint.color = Colors.black;
  paint.strokeWidth = ENGRAVING_DEFAULTS.stemThickness*drawC.lineSpacing;

  drawC.canvas.drawLine(start, end, paint);
}