import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:music_notes_2/notes/generated/engraving-defaults.dart';
import 'package:music_notes_2/notes/generated/glyph-advance-widths.dart';
import 'package:music_notes_2/notes/notes.dart';

import 'generated/glyph-definitions.dart';

double getLineSpacing(double fontSize) => fontSize / 4;

/// Advances the width of the glyph
paintGlyph(Canvas canvas, Size size, double staffHeight, Glyph glyph, {Offset offset = Offset.zero}) {
  final textPainter = TextPainter(
    text: TextSpan(
      text: GLYPH_FONTCODE_MAP[glyph],
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
  canvas.translate(GLYPH_ADVANCE_WIDTHS[glyph]*getLineSpacing(staffHeight), 0);
}

/// Advances to the end of the lines
paintStaffLines(Canvas canvas, Size size, double lineSpacing, bool noAdvance) {

  final paint = Paint()..color = Colors.black;
  paint.strokeWidth = lineSpacing * ENGRAVING_DEFAULTS.staffLineThickness;

  final lineWidth = size.width - lineSpacing;

  canvas.drawLine(Offset(0, 0), Offset(lineWidth, 0), paint);
  canvas.drawLine(Offset(0, lineSpacing * 1), Offset(lineWidth, lineSpacing * 1), paint);
  canvas.drawLine(Offset(0, lineSpacing * 2), Offset(lineWidth, lineSpacing * 2), paint);
  canvas.drawLine(Offset(0, lineSpacing * 3), Offset(lineWidth, lineSpacing * 3), paint);
  canvas.drawLine(Offset(0, lineSpacing * 4), Offset(lineWidth, lineSpacing * 4), paint);

  if(!noAdvance) {
    canvas.translate(lineWidth, 0);
  }
}

enum BarLineTypes {
  thin, double, boldDouble, repeatRight, repeatLeft
}

/// Does translate to after its width
paintBarLine(Canvas canvas, Size size, double staffHeight, List<Clefs> clefs, BarLineTypes barline, bool noAdvance) {

  final lS = getLineSpacing(staffHeight);
  final paint = Paint()..color = Colors.orange;

  final startOffset = Offset(0, 0);
  final endOffset = Offset(0, clefs.length > 1 ? staffHeight*3:staffHeight);

  // first line always a thin one

  if(noAdvance) {
    canvas.save();
  }

  if(barline == BarLineTypes.thin) {
    paint.strokeWidth = lS*ENGRAVING_DEFAULTS.thinBarlineThickness;
    canvas.drawLine(startOffset, endOffset, paint);
    canvas.translate(lS*ENGRAVING_DEFAULTS.thinBarlineThickness, 0);
  } else if(barline == BarLineTypes.double) {
    paint.strokeWidth = lS*ENGRAVING_DEFAULTS.thinBarlineThickness;
    canvas.drawLine(startOffset, endOffset, paint);
    canvas.translate(lS*ENGRAVING_DEFAULTS.barlineSeparation, 0);
    canvas.drawLine(startOffset, endOffset, paint);
    canvas.translate(lS*ENGRAVING_DEFAULTS.thinBarlineThickness, 0);
  } else if(barline == BarLineTypes.boldDouble) {
    paint.strokeWidth = lS*ENGRAVING_DEFAULTS.thinBarlineThickness;
    canvas.drawLine(startOffset, endOffset, paint);
    canvas.translate(lS*ENGRAVING_DEFAULTS.thinThickBarlineSeparation, 0);
    paint.strokeWidth = lS*ENGRAVING_DEFAULTS.thickBarlineThickness;
    canvas.drawLine(startOffset, endOffset, paint);
    canvas.translate(lS*ENGRAVING_DEFAULTS.thickBarlineThickness, 0);
  } else if(barline == BarLineTypes.repeatRight) {
    paint.strokeWidth = lS*ENGRAVING_DEFAULTS.thickBarlineThickness;
    canvas.drawLine(startOffset, endOffset, paint);
    canvas.translate(lS*ENGRAVING_DEFAULTS.thinThickBarlineSeparation, 0);
    paint.strokeWidth = lS*ENGRAVING_DEFAULTS.thinBarlineThickness;
    canvas.drawLine(startOffset, endOffset, paint);
    canvas.translate(lS*ENGRAVING_DEFAULTS.repeatBarlineDotSeparation, 0);
    paintGlyph(canvas, size, staffHeight, Glyph.repeatDots);
    canvas.translate(lS*GLYPH_ADVANCE_WIDTHS[Glyph.repeatDots], 0);
  } else if(barline == BarLineTypes.repeatLeft) {
    paintGlyph(canvas, size, staffHeight, Glyph.repeatDots);
    canvas.translate(lS*GLYPH_ADVANCE_WIDTHS[Glyph.repeatDots] + lS*ENGRAVING_DEFAULTS.repeatBarlineDotSeparation, 0);
    paint.strokeWidth = lS*ENGRAVING_DEFAULTS.thinBarlineThickness;
    canvas.drawLine(startOffset, endOffset, paint);
    canvas.translate(lS*ENGRAVING_DEFAULTS.thinBarlineThickness + lS*ENGRAVING_DEFAULTS.thinThickBarlineSeparation, 0);
    paint.strokeWidth = lS*ENGRAVING_DEFAULTS.thickBarlineThickness;
    canvas.drawLine(startOffset, endOffset, paint);
    canvas.translate(lS*ENGRAVING_DEFAULTS.thickBarlineThickness, 0);
  }

  if(noAdvance) {
    canvas.restore();
  }
}

class MusicLine extends StatefulWidget {

  const MusicLine({Key key, @required this.fontSize, this.staffs = const []}) : super(key: key);

  final double fontSize;
  final List<Clefs> staffs;

  @override
  _MusicLineState createState() => _MusicLineState();
}

class _MusicLineState extends State<MusicLine> {

  @override
  Widget build(BuildContext context) {

    return LayoutBuilder(
      builder: (_, constraints) {
        final newWidth = constraints.widthConstraints().maxWidth;
        final newHeight = constraints.heightConstraints().maxHeight;
        return Stack (
          alignment: Alignment.topLeft,
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned(
              child: CustomPaint(
                size: Size(
                  newWidth,
                  newHeight
                ),
                painter: BackgroundPainter(widget.fontSize, widget.staffs),
              ),
            ),
            Positioned(
              child: CustomPaint(
                size: Size(
                  newWidth,
                  newHeight
                ),
                painter: ForegroundPainter(widget.fontSize),
              ),
            ),
          ],
        );
      }
    );
  }
}

class BackgroundPainter extends CustomPainter {

  BackgroundPainter(this.staffHeight, this.staffs) : this.lineSpacing = getLineSpacing(staffHeight);

  final double staffHeight;
  final List<Clefs> staffs;
  final double lineSpacing;

  @override
  void paint(Canvas canvas, Size size) {

    canvas.save();

    /// Clipping and offsetting staff, so that the top line is seen completely
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height), doAntiAlias: false);

    canvas.translate(0, staffHeight);

    if(staffs.length > 1) {
      paintGlyph(canvas, size, staffHeight*3, Glyph.brace, offset: Offset(0, (staffHeight*3)/2));
      canvas.translate(lineSpacing*ENGRAVING_DEFAULTS.barlineSeparation, 0);
    }

    paintBarLine(canvas, size, staffHeight, staffs, BarLineTypes.thin, true);

    paintStaffLines(canvas, size, lineSpacing, true);

    if(staffs.length > 1) {
      canvas.translate(0, staffHeight*2);
      paintStaffLines(canvas, size, lineSpacing, false);
      canvas.translate(-52, -staffHeight*2);
    }

    paintBarLine(canvas, size, staffHeight, staffs, BarLineTypes.boldDouble, false);

    canvas.restore();
  }

  @override
  bool shouldRepaint(BackgroundPainter oldDelegate) {
    return false;
  }
}

class ForegroundPainter extends CustomPainter {

  ForegroundPainter(this.staffHeight) : this.lineSpacing = getLineSpacing(staffHeight);

  final double staffHeight;
  final double lineSpacing;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.blue;
    paint.strokeWidth = lineSpacing * ENGRAVING_DEFAULTS.staffLineThickness;


  }

  @override
  bool shouldRepaint(ForegroundPainter oldDelegate) {
    return staffHeight != oldDelegate.staffHeight;
  }
}