import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'notes.dart';
import 'render-functions/common.dart';
import 'render-functions/note.dart';
import 'render-functions/staff.dart';
import 'render-functions/glyph.dart';
import 'generated/glyph-definitions.dart';
import 'generated/engraving-defaults.dart';
import 'generated/glyph-advance-widths.dart';
import '../musicXML/data.dart';
import '../../ExtendedCanvas.dart';

class MusicLineOptions {
  MusicLineOptions(this.staffHeight, this.topMargin);

  final double staffHeight;
  final double topMargin;

  @override
  bool operator ==(Object other) {
    return other is MusicLineOptions &&
        other.topMargin == topMargin &&
        other.staffHeight == staffHeight;
  }

  @override
  int get hashCode => staffHeight.hashCode ^ topMargin.hashCode;
}

class MusicLine extends StatefulWidget {
  const MusicLine({Key? key, required this.options, this.staffs = const []})
      : super(key: key);

  final MusicLineOptions options;
  final List<Clefs> staffs;

  @override
  _MusicLineState createState() => _MusicLineState();
}

class _MusicLineState extends State<MusicLine> {
  double staffsSpacing = 100;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      final newWidth = constraints.widthConstraints().maxWidth;
      final newHeight = constraints.heightConstraints().maxHeight;
      return Stack(
        alignment: Alignment.topLeft,
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            child: CustomPaint(
              size: Size(newWidth, newHeight),
              painter: BackgroundPainter(
                  widget.options, widget.staffs, staffsSpacing),
            ),
          ),
          Positioned(
            child: CustomPaint(
              size: Size(newWidth, newHeight),
              painter: ForegroundPainter(
                  widget.options, widget.staffs, staffsSpacing),
            ),
          ),
        ],
      );
    });
  }
}

class BackgroundPainter extends CustomPainter {
  BackgroundPainter(this.options, this.staffs, this.staffsSpacing)
      : this.lineSpacing = getLineSpacing(options.staffHeight);

  final MusicLineOptions options;
  final List<Clefs> staffs;
  final double staffsSpacing;
  final double lineSpacing;

  @override
  void paint(Canvas canvas, Size size) {
    final xCanvas = XCanvas(canvas);
    xCanvas.save();

    /// Clipping and offsetting staff, so that the top line is seen completely
    xCanvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height),
        doAntiAlias: false);

    xCanvas.translate(0, options.staffHeight);

    if (staffs.length > 1) {
      paintGlyph(
          xCanvas, size, options.staffHeight * 2 + staffsSpacing, Glyph.brace,
          offset: Offset(0, (options.staffHeight * 2 + staffsSpacing) / 2));
      xCanvas.translate(lineSpacing * ENGRAVING_DEFAULTS.barlineSeparation, 0);
    }

    paintBarLine(xCanvas, size, options.staffHeight, staffs, staffsSpacing,
        BarLineTypes.regular, true);

    paintStaffLines(xCanvas, size, lineSpacing, true);

    if (staffs.length > 1) {
      xCanvas.translate(0, options.staffHeight + staffsSpacing);
      paintStaffLines(xCanvas, size, lineSpacing, false);
      xCanvas.translate(0, -options.staffHeight - staffsSpacing);
    }

    xCanvas.restore();
  }

  @override
  bool shouldRepaint(BackgroundPainter oldDelegate) {
    return options != oldDelegate.options;
  }
}

class ForegroundPainter extends CustomPainter {
  ForegroundPainter(this.options, this.staffs, this.staffsSpacing)
      : this.lineSpacing = getLineSpacing(options.staffHeight);

  final MusicLineOptions options;
  final List<Clefs> staffs;
  final double staffsSpacing;
  final double lineSpacing;

  @override
  void paint(Canvas canvas, Size size) {
    final xCanvas = XCanvas(canvas);
    final staffHeight = options.staffHeight;

    final paint = Paint()..color = Colors.blue;
    paint.strokeWidth = lineSpacing * ENGRAVING_DEFAULTS.staffLineThickness;

    if (staffs.length > 1) {
      // The brace in front of the whole music line takes up horizontal space. That
      // space is determined by the width of the brace, which in turn is determined by
      // heights of the staffs and the space between the staff.
      final staffsSpacingLineSpacing = getLineSpacing(staffsSpacing);
      xCanvas.translate(
          GLYPH_ADVANCE_WIDTHS[Glyph.brace]! *
                  (lineSpacing * 2 + staffsSpacingLineSpacing) +
              lineSpacing * ENGRAVING_DEFAULTS.barlineSeparation * 2,
          0);
    }

    paintGlyph(xCanvas, size, staffHeight, Glyph.gClef,
        offset: Offset(0, lineSpacing * 5), noAdvance: true);
    paintGlyph(xCanvas, size, staffHeight, Glyph.fClef,
        offset: Offset(0, staffHeight + staffsSpacing + lineSpacing * 3));

    xCanvas.translate(
        lineSpacing * ENGRAVING_DEFAULTS.barlineSeparation * 2, 0);

    paintGlyph(xCanvas, size, staffHeight, Glyph.timeSig4,
        offset: Offset(0, lineSpacing * 3), noAdvance: true);
    paintGlyph(xCanvas, size, staffHeight, Glyph.timeSig4,
        offset: Offset(0, lineSpacing * 5), noAdvance: true);
    paintGlyph(xCanvas, size, staffHeight, Glyph.timeSig4,
        offset: Offset(0, staffHeight + staffsSpacing + lineSpacing * 3),
        noAdvance: true);
    paintGlyph(xCanvas, size, staffHeight, Glyph.timeSig4,
        offset: Offset(0, staffHeight + staffsSpacing + lineSpacing * 5));

    xCanvas.translate(
        lineSpacing * ENGRAVING_DEFAULTS.barlineSeparation * 2, 0);

    paintAccidentalsForTone(xCanvas, size, staffHeight, Clefs.G, CircleOfFifths.F_D.v,
        noAdvance: true);
    xCanvas.translate(0, staffHeight + staffsSpacing);
    paintAccidentalsForTone(xCanvas, size, staffHeight, Clefs.F, CircleOfFifths.F_D.v);
    xCanvas.translate(0, -staffHeight - staffsSpacing);

    xCanvas.translate(
        lineSpacing * ENGRAVING_DEFAULTS.barlineSeparation * 4, 0);

    paintSingleNote(
      xCanvas,
      size,
      staffHeight,
      Clefs.G,
      CircleOfFifths.F_D.v,
      NotePosition(
        tone: BaseTones.C,
        length: NoteLength.quarter,
        accidental: Accidentals.sharp,
        octave: 2,
      ),
    );
  }

  @override
  bool shouldRepaint(ForegroundPainter oldDelegate) {
    return options != oldDelegate.options;
  }
}
