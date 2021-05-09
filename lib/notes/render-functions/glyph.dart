import 'dart:ui';
import 'package:flutter/material.dart';
import 'common.dart';
import '../../ExtendedCanvas.dart';
import '../generated/glyph-advance-widths.dart';
import '../generated/glyph-definitions.dart';

/// Advances the width of the glyph
paintGlyph(XCanvas canvas, Size size, double staffHeight, Glyph? glyph, {Offset offset = Offset.zero, bool noAdvance = false}) {
  final textPainter = TextPainter(
    text: TextSpan(
      text: GLYPH_FONTCODE_MAP[glyph!],
      style: TextStyle(
        fontFamily: 'Bravura',
        fontSize: staffHeight,
        height: 1,
        color: Colors.black,
      ),
    ),
    textDirection: TextDirection.ltr,
  );
  textPainter.layout();
  textPainter.paint(canvas, offset);

  if(!noAdvance) {
    canvas.translate(
        GLYPH_ADVANCE_WIDTHS[glyph]! * getLineSpacing(staffHeight), 0);
  }
}