import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../musicXML/data.dart';
import 'generated/engraving_defaults.dart';
import 'generated/glyph_advance_widths.dart';
import 'generated/glyph_definitions.dart';
import 'render_functions/common.dart';
import 'render_functions/drawing_context.dart';
import 'render_functions/glyph.dart';
import 'render_functions/measure.dart';
import 'render_functions/staff.dart';

class MusicLineOptions {
  MusicLineOptions(this.score, this.staffHeight, double topMarginFactor) : topMargin = staffHeight * topMarginFactor;

  final Score score;
  final double staffHeight;
  final double topMargin;

  @override
  bool operator ==(Object other) {
    return other is MusicLineOptions && other.topMargin == topMargin && other.staffHeight == staffHeight;
  }

  @override
  int get hashCode => staffHeight.hashCode ^ topMargin.hashCode;
}

class MusicLine extends StatefulWidget {
  const MusicLine({super.key, required this.options});

  final MusicLineOptions options;

  @override
  MusicLineState createState() => MusicLineState();
}

class MusicLineState extends State<MusicLine> {
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
              painter: BackgroundPainter(widget.options, staffsSpacing),
            ),
          ),
          Positioned(
            child: CustomPaint(
              size: Size(newWidth, newHeight),
              painter: ForegroundPainter(widget.options, staffsSpacing),
            ),
          ),
        ],
      );
    });
  }
}

class BackgroundPainter extends CustomPainter {
  BackgroundPainter(this.options, this.staffsSpacing) : lineSpacing = getLineSpacing(options.staffHeight);

  final MusicLineOptions options;
  final double staffsSpacing;
  final double lineSpacing;

  @override
  void paint(Canvas canvas, Size size) {
    // The initial offset of the Canvas is not (0, 0) for some reason. This is a workaround.
    final transform = canvas.getTransform();
    canvas.translate(-transform[12], -transform[13]);

    /// Clipping and offsetting staff, so that the top line is seen completely
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height), doAntiAlias: false);

    canvas.translate(0, options.topMargin);

    final drawC = DrawingContext(options.score, options.staffHeight, options.topMargin, canvas, size, staffsSpacing);

    if ((drawC.latestAttributes.staves ?? 1) > 1) {
      paintGlyph(drawC.copyWith(staffHeight: options.staffHeight * 2 + staffsSpacing), Glyph.brace,
          yOffset: (options.staffHeight * 2 + staffsSpacing) / 2);
      canvas.translate(lineSpacing * engravingDefaults.barlineSeparation, 0);
    }

    paintBarLine(drawC, Barline(BarLineTypes.regular), true);

    paintStaffLines(drawC, true);

    if ((drawC.latestAttributes.staves ?? 1) > 1) {
      canvas.translate(0, options.staffHeight + staffsSpacing);
      paintStaffLines(drawC, false);
      canvas.translate(0, -options.staffHeight - staffsSpacing);
    }
  }

  @override
  bool shouldRepaint(BackgroundPainter oldDelegate) {
    return options != oldDelegate.options || staffsSpacing != oldDelegate.staffsSpacing;
  }
}

class ForegroundPainter extends CustomPainter {
  ForegroundPainter(this.options, this.staffsSpacing) : lineSpacing = getLineSpacing(options.staffHeight);

  final MusicLineOptions options;
  final double staffsSpacing;
  final double lineSpacing;

  @override
  void paint(Canvas canvas, Size size) {
    // The initial offset of the Canvas is not (0, 0) for some reason. This is a workaround.
    final transform = canvas.getTransform();
    canvas.translate(-transform[12], -transform[13]);

    canvas.translate(0, options.topMargin);

    final paint = Paint()..color = Colors.blue;
    paint.strokeWidth = lineSpacing * engravingDefaults.staffLineThickness;

    final drawC = DrawingContext(options.score, options.staffHeight, options.topMargin, canvas, size, staffsSpacing);

    if ((drawC.latestAttributes.staves ?? 1) > 1) {
      // The brace in front of the whole music line takes up horizontal space. That
      // space is determined by the width of the brace, which in turn is determined by
      // heights of the staffs and the space between the staff.
      final staffsSpacingLineSpacing = getLineSpacing(staffsSpacing);
      canvas.translate(
          glyphAdvanceWidths[Glyph.brace]! * (lineSpacing * 2 + staffsSpacingLineSpacing) +
              lineSpacing * engravingDefaults.barlineSeparation * 2,
          0);
    }
    final measures = options.score.parts.first.measures.toList();
    measures.forEachIndexed((index, measure) {
      drawC.currentMeasure = index;
      if (index > 0) {
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
