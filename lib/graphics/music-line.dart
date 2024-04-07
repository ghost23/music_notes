import 'package:flutter/material.dart';
import 'render-functions/measure.dart';
import 'render-functions/DrawingContext.dart';
import 'render-functions/common.dart';
import 'render-functions/staff.dart';
import 'render-functions/glyph.dart';
import 'generated/glyph-definitions.dart';
import 'generated/engraving-defaults.dart';
import 'generated/glyph-advance-widths.dart';
import '../musicXML/data.dart';
import '../../ExtendedCanvas.dart';
import 'package:collection/collection.dart';

class MusicLineOptions {
  MusicLineOptions(this.score, this.staffHeight, double topMarginFactor): topMargin = staffHeight * topMarginFactor;

  final Score score;
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
  const MusicLine({super.key, required this.options});

  final MusicLineOptions options;

  @override
  _MusicLineState createState() => _MusicLineState();
}

class _MusicLineState extends State<MusicLine> {
  double staffsSpacing = 0;

  @override
  void initState() {
    super.initState();
    staffsSpacing = widget.options.staffHeight * 2;
  }

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
                  widget.options, staffsSpacing),
            ),
          ),
          Positioned(
            child: CustomPaint(
              size: Size(newWidth, newHeight),
              painter: ForegroundPainter(
                  widget.options, staffsSpacing),
            ),
          ),
        ],
      );
    });
  }
}

class BackgroundPainter extends CustomPainter {
  BackgroundPainter(this.options, this.staffsSpacing)
      : lineSpacing = getLineSpacing(options.staffHeight);

  final MusicLineOptions options;
  final double staffsSpacing;
  final double lineSpacing;

  @override
  void paint(Canvas canvas, Size size) {
    final xCanvas = XCanvas(canvas);
    xCanvas.save();

    /// Clipping and offsetting staff, so that the top line is seen completely
    xCanvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height),
        doAntiAlias: false);

    xCanvas.translate(0, options.topMargin);

    final drawC = DrawingContext(options.score, options.staffHeight, options.topMargin, xCanvas, size, staffsSpacing);

    if ((drawC.latestAttributes.staves ?? 1) > 1) {
      paintGlyph(
        drawC.copyWith(staffHeight: options.staffHeight * 2 + staffsSpacing),
        Glyph.brace, yOffset: (options.staffHeight * 2 + staffsSpacing) / 2
      );
      xCanvas.translate(lineSpacing * ENGRAVING_DEFAULTS.barlineSeparation, 0);
    }

    paintBarLine(drawC, Barline(BarLineTypes.regular), true);

    paintStaffLines(drawC, true);

    if ((drawC.latestAttributes.staves ?? 1) > 1) {
      xCanvas.translate(0, options.staffHeight + staffsSpacing);
      paintStaffLines(drawC, false);
      xCanvas.translate(0, -options.staffHeight - staffsSpacing);
    }

    xCanvas.restore();
  }

  @override
  bool shouldRepaint(BackgroundPainter oldDelegate) {
    return options != oldDelegate.options || staffsSpacing != oldDelegate.staffsSpacing;
  }
}

class ForegroundPainter extends CustomPainter {
  ForegroundPainter(this.options, this.staffsSpacing)
      : lineSpacing = getLineSpacing(options.staffHeight);

  final MusicLineOptions options;
  final double staffsSpacing;
  final double lineSpacing;

  @override
  void paint(Canvas canvas, Size size) {
    final xCanvas = XCanvas(canvas);
    xCanvas.translate(0, options.topMargin);

    final paint = Paint()..color = Colors.blue;
    paint.strokeWidth = lineSpacing * ENGRAVING_DEFAULTS.staffLineThickness;

    final drawC = DrawingContext(options.score, options.staffHeight, options.topMargin, xCanvas, size, staffsSpacing);

    if ((drawC.latestAttributes.staves ?? 1) > 1) {
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
    final measures = options.score.parts.first.measures.toList();
    measures.forEachIndexed((index, measure) {
      drawC.currentMeasure = index;
      if(index > 0) {
        drawC.canvas.translate(drawC.lS * 1, 0);
      }
      paintMeasure(measure, drawC);

      drawC.canvas.translate(drawC.lS * 1, 0);

      paintBarLine(drawC, measure.barline, false);
    });
  }

  @override
  bool shouldRepaint(ForegroundPainter oldDelegate) {
    return options != oldDelegate.options || staffsSpacing != oldDelegate.staffsSpacing;
  }
}
