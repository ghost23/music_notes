import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:music_notes_2/ExtendedCanvas.dart';
import 'package:music_notes_2/notes/generated/engraving-defaults.dart';
import 'package:music_notes_2/notes/generated/glyph-advance-widths.dart';
import 'package:music_notes_2/notes/notes.dart';

import 'generated/glyph-definitions.dart';

double getLineSpacing(double fontSize) => fontSize / 4;

/// Advances the width of the glyph
paintGlyph(XCanvas canvas, Size size, double staffHeight, Glyph glyph, {Offset offset = Offset.zero, bool noAdvance = false}) {
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

  if(!noAdvance) {
    canvas.translate(
        GLYPH_ADVANCE_WIDTHS[glyph] * getLineSpacing(staffHeight), 0);
  }
}

/// Advances to the end of the lines
paintStaffLines(XCanvas canvas, Size size, double lineSpacing, bool noAdvance) {

  final paint = Paint()..color = Colors.black;
  paint.strokeWidth = lineSpacing * ENGRAVING_DEFAULTS.staffLineThickness;

  final lineWidth = size.width - canvas.getTranslation().x;

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
paintBarLine(XCanvas canvas, Size size, double staffHeight, List<Clefs> clefs, double staffsSpacing, BarLineTypes barline, bool noAdvance) {

  final lS = getLineSpacing(staffHeight);
  final paint = Paint()..color = Colors.black;

  final startOffset = Offset(0, 0);
  final endOffset = Offset(0, clefs.length > 1 ? staffHeight*2+staffsSpacing:staffHeight);

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
    canvas.translate(lS*ENGRAVING_DEFAULTS.barlineSeparation + lS*ENGRAVING_DEFAULTS.thinBarlineThickness, 0);
    canvas.drawLine(startOffset, endOffset, paint);
    canvas.translate(lS*ENGRAVING_DEFAULTS.thinBarlineThickness, 0);
  } else if(barline == BarLineTypes.boldDouble) {
    paint.strokeWidth = lS*ENGRAVING_DEFAULTS.thinBarlineThickness;
    canvas.drawLine(startOffset, endOffset, paint);
    canvas.translate(lS*ENGRAVING_DEFAULTS.thinThickBarlineSeparation + lS*ENGRAVING_DEFAULTS.thinBarlineThickness, 0);
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

paintAccidentalsForTone(XCanvas canvas, Size size, double staffHeight, Clefs staff, MainTones tone, {bool noAdvance = false}) {
  if(noAdvance) {
    canvas.save();
  }

  double lineSpacing = getLineSpacing(staffHeight);
  final accidentals = staff == Clefs.f ? mainToneAccidentalsMapForFClef[tone] : mainToneAccidentalsMapForGClef[tone];
  accidentals.forEach((note) {
    if(note.accidental != Accidentals.none) {
      paintGlyph(
        canvas,
        size,
        staffHeight,
        accidentalGlyphMap[note.accidental],
        offset: Offset(
          0,
          ((lineSpacing/2) * calculateYOffsetForNote(staff, note)),
        ),
      );
    }
  });

  if(noAdvance) {
    canvas.restore();
  }
}

paintLedgers(XCanvas canvas, Size size, double staffHeight, Clefs staff, MainTones tone, Note note) {
  int numLedgersToDraw = 0;
  switch (staff) {
    case Clefs.g: {
      if(note.positionalValue() > topStaffLineNoteGClef.positionalValue() + 1) {
        numLedgersToDraw = ((note.positionalValue() - topStaffLineNoteGClef.positionalValue()) / 2).floor();
      } else if(note.positionalValue() < bottomStaffLineNoteGClef.positionalValue() - 1) {
        numLedgersToDraw = ((note.positionalValue() - bottomStaffLineNoteGClef.positionalValue()) / 2).floor();
      }
      break;
    }
    case Clefs.f: {
      if(note.positionalValue() > topStaffLineNoteFClef.positionalValue() + 1) {
        numLedgersToDraw = ((note.positionalValue() - topStaffLineNoteFClef.positionalValue()) / 2).floor();
      } else if(note.positionalValue() < bottomStaffLineNoteFClef.positionalValue() - 1) {
        numLedgersToDraw = ((note.positionalValue() - bottomStaffLineNoteFClef.positionalValue()) / 2).floor();
      }
    }
  }
  print('numLedgersToDraw: $numLedgersToDraw');
  double lineSpacing = getLineSpacing(staffHeight);
  final paint = Paint()..color = Colors.black;
  paint.strokeWidth = lineSpacing * ENGRAVING_DEFAULTS.staffLineThickness;
  double noteWidth = GLYPH_ADVANCE_WIDTHS[singleNoteHeadByLength[note.length]]*lineSpacing;
  double ledgerLength = noteWidth * 1.5;
  for(int i = numLedgersToDraw; i != 0;) {
    if(i < 0) {
      // one staff height because, the visible staff lines begin one staff height below the top y 0.
      // And then another staff height for actual visible staff.
      // TODO: We should not hardwire the space over the staff
      double pos = (-i*2)*(lineSpacing/2) + (staffHeight*2);
      canvas.drawLine(Offset(-((ledgerLength-noteWidth)/2), pos), Offset(-((ledgerLength-noteWidth)/2) + ledgerLength, pos), paint);
      i++;
    } else {
      // one staff height because, the visible staff lines begin one staff height below the top y 0.
      // And then another staff height for actual visible staff.
      // TODO: We should not hardwire the space over the staff
      double pos = staffHeight - (i*2)*(lineSpacing/2);
      canvas.drawLine(Offset(-((ledgerLength-noteWidth)/2), pos), Offset(-((ledgerLength-noteWidth)/2) + ledgerLength, pos), paint);
      i--;
    }
  }
}

paintSingleNote(XCanvas canvas, Size size, double staffHeight, Clefs staff, MainTones tone, Note note) {
  int staffIndex = Clefs.values.indexOf(staff);
  double lineSpacing = getLineSpacing(staffHeight);
  int offset = calculateYOffsetForNote(staff, note);
  paintGlyph(
    canvas,
    size,
    staffHeight,
    // TODO: We should probably draw the stem up or down ourselves
    offset < 8 ? singleNoteDownByLength[note.length] : singleNoteUpByLength[note.length],
    offset: Offset(
      0,
      ((lineSpacing/2) * offset),
    ),
    noAdvance: true,
  );

  paintLedgers(canvas, size, staffHeight, staff, tone, note);

  canvas.translate(GLYPH_ADVANCE_WIDTHS[singleNoteUpByLength[note.length]]*lineSpacing, 0);

  List<Note> alreadyAppliedAccidentals = staff == Clefs.g ? mainToneAccidentalsMapForGClef[tone] : mainToneAccidentalsMapForFClef[tone];
  final alreadyAppliedAccidentalExists = alreadyAppliedAccidentals.any(
    (accidental) =>
      accidental.tone == note.tone
      && (accidental.accidental == note.accidental || note.accidental == Accidentals.natural)
  );
  if(
          (!alreadyAppliedAccidentalExists && note.accidental != Accidentals.natural)
      ||  (alreadyAppliedAccidentalExists && note.accidental == Accidentals.natural)
  ) {
    canvas.translate(ENGRAVING_DEFAULTS.barlineSeparation*lineSpacing, 0);

    paintGlyph(
      canvas,
      size,
      staffHeight,
      accidentalGlyphMap[note.accidental],
      offset: Offset(
        0,
        ((lineSpacing/2) * calculateYOffsetForNote(staff, note)),
      ),
    );
  }
}

const stdNotePositionGClef = Note(tone: BaseTones.C, octave: 4);
const stdNotePositionFClef = Note(tone: BaseTones.E, octave: 2);

const Map<Clefs, Note> stdNotePosition = {
  Clefs.g: stdNotePositionGClef,
  Clefs.f: stdNotePositionFClef,
};

const topStaffLineNoteGClef = Note(tone: BaseTones.F, octave: 3);
const bottomStaffLineNoteGClef = Note(tone: BaseTones.E, octave: 2);

const topStaffLineNoteFClef = Note(tone: BaseTones.A, octave: 1);
const bottomStaffLineNoteFClef = Note(tone: BaseTones.G, octave: 0);

const Map<Clefs, Note> topStaffLineNote = {
  Clefs.g: topStaffLineNoteGClef,
  Clefs.f: topStaffLineNoteFClef,
};

const Map<Clefs, Note> bottomStaffLineNote = {
  Clefs.g: bottomStaffLineNoteGClef,
  Clefs.f: bottomStaffLineNoteFClef,
};

int calculateYOffsetForNote(Clefs clef, Note note) {
  int diff = 0;
  if(clef == Clefs.g) {
    diff = stdNotePositionGClef.positionalValue() - note.positionalValue();
  } else if(clef == Clefs.f) {
    diff = stdNotePositionFClef.positionalValue() - note.positionalValue();
  }
  return diff;
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
                painter: BackgroundPainter(widget.fontSize, widget.staffs, 100),
              ),
            ),
            Positioned(
              child: CustomPaint(
                size: Size(
                  newWidth,
                  newHeight
                ),
                painter: ForegroundPainter(widget.fontSize, widget.staffs, 100),
              ),
            ),
          ],
        );
      }
    );
  }
}

class BackgroundPainter extends CustomPainter {

  BackgroundPainter(this.staffHeight, this.staffs, this.staffsSpacing) : this.lineSpacing = getLineSpacing(staffHeight);

  final double staffHeight;
  final List<Clefs> staffs;
  final double staffsSpacing;
  final double lineSpacing;

  @override
  void paint(Canvas canvas, Size size) {

    final xCanvas = XCanvas(canvas);
    xCanvas.save();

    /// Clipping and offsetting staff, so that the top line is seen completely
    xCanvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height), doAntiAlias: false);

    xCanvas.translate(0, staffHeight);

    if(staffs.length > 1) {
      paintGlyph(xCanvas, size, staffHeight*2+staffsSpacing, Glyph.brace, offset: Offset(0, (staffHeight*2+staffsSpacing)/2));
      xCanvas.translate(lineSpacing*ENGRAVING_DEFAULTS.barlineSeparation, 0);
    }

    paintBarLine(xCanvas, size, staffHeight, staffs, staffsSpacing, BarLineTypes.thin, true);

    paintStaffLines(xCanvas, size, lineSpacing, true);

    if(staffs.length > 1) {
      xCanvas.translate(0, staffHeight+staffsSpacing);
      paintStaffLines(xCanvas, size, lineSpacing, false);
      xCanvas.translate(0, -staffHeight-staffsSpacing);
    }

    paintBarLine(xCanvas, size, staffHeight, staffs, staffsSpacing, BarLineTypes.boldDouble, false);

    xCanvas.restore();
  }

  @override
  bool shouldRepaint(BackgroundPainter oldDelegate) {
    return false;
  }
}

class ForegroundPainter extends CustomPainter {

  ForegroundPainter(this.staffHeight, this.staffs, this.staffsSpacing) : this.lineSpacing = getLineSpacing(staffHeight);

  final double staffHeight;
  final List<Clefs> staffs;
  final double staffsSpacing;
  final double lineSpacing;

  @override
  void paint(Canvas canvas, Size size) {
    final xCanvas = XCanvas(canvas);

    final paint = Paint()..color = Colors.blue;
    paint.strokeWidth = lineSpacing * ENGRAVING_DEFAULTS.staffLineThickness;

    if(staffs.length > 1) {
      // The brace in front of the whole music line takes up horizontal space. That
      // space is determined by the width of the brace, which in turn is determined by
      // heights of the staffs and the space between the staff.
      final staffsSpacingLineSpacing = getLineSpacing(staffsSpacing);
      xCanvas.translate(GLYPH_ADVANCE_WIDTHS[Glyph.brace] *
          (lineSpacing * 2 + staffsSpacingLineSpacing) +
          lineSpacing * ENGRAVING_DEFAULTS.barlineSeparation * 2, 0);
    }

    paintGlyph(xCanvas, size, staffHeight, Glyph.gClef, offset: Offset(0, lineSpacing*5), noAdvance: true);
    paintGlyph(xCanvas, size, staffHeight, Glyph.fClef, offset: Offset(0, staffHeight+staffsSpacing + lineSpacing*3));

    xCanvas.translate(lineSpacing*ENGRAVING_DEFAULTS.barlineSeparation*2, 0);

    paintGlyph(xCanvas, size, staffHeight, Glyph.timeSig4, offset: Offset(0, lineSpacing*3), noAdvance: true);
    paintGlyph(xCanvas, size, staffHeight, Glyph.timeSig4, offset: Offset(0, lineSpacing*5), noAdvance: true);
    paintGlyph(xCanvas, size, staffHeight, Glyph.timeSig4, offset: Offset(0, staffHeight+staffsSpacing + lineSpacing*3), noAdvance: true);
    paintGlyph(xCanvas, size, staffHeight, Glyph.timeSig4, offset: Offset(0, staffHeight+staffsSpacing + lineSpacing*5));

    xCanvas.translate(lineSpacing*ENGRAVING_DEFAULTS.barlineSeparation*2, 0);

    paintAccidentalsForTone(xCanvas, size, staffHeight, Clefs.g, MainTones.F_D, noAdvance: true);
    xCanvas.translate(0, staffHeight+staffsSpacing);
    paintAccidentalsForTone(xCanvas, size, staffHeight, Clefs.f, MainTones.F_D);
    xCanvas.translate(0, -staffHeight-staffsSpacing);

    xCanvas.translate(lineSpacing*ENGRAVING_DEFAULTS.barlineSeparation*4, 0);

    paintSingleNote(
      xCanvas,
      size,
      staffHeight,
      Clefs.g,
      MainTones.F_D,
      Note(
          tone: BaseTones.C,
          length: NoteLength.quarter,
          accidental: Accidentals.sharp,
          octave: 2,
      ),
    );
  }

  @override
  bool shouldRepaint(ForegroundPainter oldDelegate) {
    return staffHeight != oldDelegate.staffHeight;
  }
}