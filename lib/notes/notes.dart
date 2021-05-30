import 'dart:collection';
import '../musicXML/data.dart';
import 'generated/glyph-definitions.dart';

const Map<Clefs, Glyph> clefToGlyphMap = {
  Clefs.G: Glyph.gClef,
  Clefs.F: Glyph.fClef,
};

const Map<Clefs, int> clefToPositionOffsetMap = {
  Clefs.G: 1,
  Clefs.F: -1,
};

const Map<NoteLength, Glyph> singleNoteUpByLength = {
  NoteLength.whole: Glyph.noteWhole,
  NoteLength.half: Glyph.noteHalfUp,
  NoteLength.quarter: Glyph.noteQuarterUp,
  NoteLength.eighth: Glyph.note8thUp,
  NoteLength.sixteenth: Glyph.note16thUp,
  NoteLength.thirtysecond: Glyph.note32ndUp,
};

const Map<NoteLength, Glyph> singleNoteHeadByLength = {
  NoteLength.whole: Glyph.noteheadWhole,
  NoteLength.half: Glyph.noteheadHalf,
  NoteLength.quarter: Glyph.noteheadBlack,
  NoteLength.eighth: Glyph.noteheadBlack,
  NoteLength.sixteenth: Glyph.noteheadBlack,
  NoteLength.thirtysecond: Glyph.noteheadBlack,
};

const Map<NoteLength, Glyph> singleNoteDownByLength = {
  NoteLength.whole: Glyph.noteWhole,
  NoteLength.half: Glyph.noteHalfDown,
  NoteLength.quarter: Glyph.noteQuarterDown,
  NoteLength.eighth: Glyph.note8thDown,
  NoteLength.sixteenth: Glyph.note16thDown,
  NoteLength.thirtysecond: Glyph.note32ndDown,
};

final UnmodifiableMapView<BaseTones, int> numericValueOfBaseTone = UnmodifiableMapView({
  BaseTones.C: 0,
  BaseTones.D: 2,
  BaseTones.E: 4,
  BaseTones.F: 5,
  BaseTones.G: 7,
  BaseTones.A: 9,
  BaseTones.B: 11,
});

const Map<Accidentals, int> numericValueOfAccidental = {
  Accidentals.sharp: 1,
  Accidentals.flat: -1,
  Accidentals.none: 0,
  Accidentals.natural: 0,
};

const Map<Accidentals, Glyph?> accidentalGlyphMap = {
  Accidentals.none: null,
  Accidentals.natural: Glyph.accidentalNatural,
  Accidentals.sharp: Glyph.accidentalSharp,
  Accidentals.flat: Glyph.accidentalFlat,
};

///Whenever you see something with 'numericValue' in it, it is a representation
///of an absolute note position. The capital C is numericValue = 0, small c = 12, c' = 24, etc.
///you know, the octaves. So a D in the octave of capital C would be = 2, and so on.

BaseTones baseToneFromNumericValue(int value, bool preferSharp) {
  final valueWithinOctave = value % 12;
  switch(valueWithinOctave) {
    case 0: return BaseTones.C;
    case 1: return preferSharp ? BaseTones.C : BaseTones.D;
    case 2: return BaseTones.D;
    case 3: return preferSharp ? BaseTones.D : BaseTones.E;
    case 4: return BaseTones.E;
    case 5: return BaseTones.F;
    case 6: return preferSharp ? BaseTones.F : BaseTones.G;
    case 7: return BaseTones.G;
    case 8: return preferSharp ? BaseTones.G : BaseTones.A;
    case 9: return BaseTones.A;
    case 10: return preferSharp ? BaseTones.A : BaseTones.B;
    case 11: return BaseTones.B;
    default: return BaseTones.C;
  }
}

Accidentals accidentalFromNumericValue(int value, bool preferSharp) {
  final valueWithinOctave = value % 12;
  switch(valueWithinOctave) {
    case 1:
    case 3:
    case 6:
    case 8:
    case 10: return preferSharp ? Accidentals.sharp : Accidentals.flat;
    default: return Accidentals.none;
  }
}

/// A data representation of almost anything - but mostly notes - that can be put on staves,
/// like notes, accidentals, legers, articulation glyphs, etc.
/// It is more a positional info object. Maybe we should not actually call it Note?!
class NotePosition {
  const NotePosition({required this.tone, required this.length, this.accidental = Accidentals.none, required this.octave});

  final BaseTones tone;
  final Accidentals accidental;
  /// 0 = C, 1 = c, 2 = c', etc.
  final int octave;
  final NoteLength length;

  NotePosition.fromNumericValue(int value, this.length, bool preferSharp) :
      octave = (value / 12).floor(),
      tone = baseToneFromNumericValue(value, preferSharp),
      accidental = accidentalFromNumericValue(value, preferSharp);

  int diffToNote(NotePosition other) {
    return numericValue() - other.numericValue();
  }

  int numericValue() {
    return octave * 12 + (numericValueOfBaseTone[tone]! + numericValueOfAccidental[accidental]!);
  }

  /// positional value is a value to determine where on a stave a note should be put.
  /// So here we only care about the "white keys"-notes, which I called BaseNotes up above.
  /// That's why an octave here has only 7 notes in it.
  int positionalValue() {
    return octave * 7 + BaseTones.values.indexOf(tone);
  }

  @override
  bool operator ==(Object other) {
    return other is NotePosition &&
      numericValue() == other.numericValue();
  }

  bool operator >(Object other) {
    return other is NotePosition &&
    numericValue() > other.numericValue();
  }

  bool operator >=(Object other) {
    return other is NotePosition &&
        numericValue() >= other.numericValue();
  }

  bool operator <(Object other) {
    return other is NotePosition &&
        numericValue() < other.numericValue();
  }

  bool operator <=(Object other) {
    return other is NotePosition &&
        numericValue() <= other.numericValue();
  }

  @override
  String toString() {
    return 'Note(tone: $tone, accidental: $accidental, octave: $octave)';
  }

  @override
  int get hashCode => tone.hashCode ^ accidental.hashCode ^ octave.hashCode;

}

/// We use the following two maps to specify the general accidentals for
/// all major and minor tone scales for the g clef and the f clef.
const Map<Fifths, List<NotePosition>> mainToneAccidentalsMapForGClef = {
  0: [],
  1: [
    NotePosition(tone: BaseTones.F, octave: 3, accidental: Accidentals.sharp, length: NoteLength.quarter),
  ],
  2: [
    NotePosition(tone: BaseTones.F, octave: 3, accidental: Accidentals.sharp, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.C, octave: 3, accidental: Accidentals.sharp, length: NoteLength.quarter),
  ],
  3: [
    NotePosition(tone: BaseTones.F, octave: 3, accidental: Accidentals.sharp, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.C, octave: 3, accidental: Accidentals.sharp, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.G, octave: 3, accidental: Accidentals.sharp, length: NoteLength.quarter),
  ],
  4: [
    NotePosition(tone: BaseTones.F, octave: 3, accidental: Accidentals.sharp, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.C, octave: 3, accidental: Accidentals.sharp, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.G, octave: 3, accidental: Accidentals.sharp, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.D, octave: 3, accidental: Accidentals.sharp, length: NoteLength.quarter),
  ],
  5: [
    NotePosition(tone: BaseTones.F, octave: 3, accidental: Accidentals.sharp, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.C, octave: 3, accidental: Accidentals.sharp, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.G, octave: 3, accidental: Accidentals.sharp, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.D, octave: 3, accidental: Accidentals.sharp, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.A, octave: 2, accidental: Accidentals.sharp, length: NoteLength.quarter),
  ],
  6: [
    NotePosition(tone: BaseTones.F, octave: 3, accidental: Accidentals.sharp, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.C, octave: 3, accidental: Accidentals.sharp, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.G, octave: 3, accidental: Accidentals.sharp, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.D, octave: 3, accidental: Accidentals.sharp, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.A, octave: 2, accidental: Accidentals.sharp, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.E, octave: 3, accidental: Accidentals.sharp, length: NoteLength.quarter),
  ],
  -1: [
    NotePosition(tone: BaseTones.B, octave: 2, accidental: Accidentals.flat, length: NoteLength.quarter),
  ],
  -2: [
    NotePosition(tone: BaseTones.B, octave: 2, accidental: Accidentals.flat, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.E, octave: 3, accidental: Accidentals.flat, length: NoteLength.quarter),
  ],
  -3: [
    NotePosition(tone: BaseTones.B, octave: 2, accidental: Accidentals.flat, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.E, octave: 3, accidental: Accidentals.flat, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.A, octave: 2, accidental: Accidentals.flat, length: NoteLength.quarter),
  ],
  -4: [
    NotePosition(tone: BaseTones.B, octave: 2, accidental: Accidentals.flat, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.E, octave: 3, accidental: Accidentals.flat, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.A, octave: 2, accidental: Accidentals.flat, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.D, octave: 3, accidental: Accidentals.flat, length: NoteLength.quarter),
  ],
  -5: [
    NotePosition(tone: BaseTones.B, octave: 2, accidental: Accidentals.flat, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.E, octave: 3, accidental: Accidentals.flat, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.A, octave: 2, accidental: Accidentals.flat, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.D, octave: 3, accidental: Accidentals.flat, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.G, octave: 2, accidental: Accidentals.flat, length: NoteLength.quarter),
  ],
  -6: [
    NotePosition(tone: BaseTones.B, octave: 2, accidental: Accidentals.flat, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.E, octave: 3, accidental: Accidentals.flat, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.A, octave: 2, accidental: Accidentals.flat, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.D, octave: 3, accidental: Accidentals.flat, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.G, octave: 2, accidental: Accidentals.flat, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.C, octave: 3, accidental: Accidentals.flat, length: NoteLength.quarter),
  ],
};

const Map<Fifths, List<NotePosition>> mainToneAccidentalsMapForFClef = {
  0: [],
  1: [
    NotePosition(tone: BaseTones.F, octave: 1, accidental: Accidentals.sharp, length: NoteLength.quarter),
  ],
  2: [
    NotePosition(tone: BaseTones.F, octave: 1, accidental: Accidentals.sharp, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.C, octave: 1, accidental: Accidentals.sharp, length: NoteLength.quarter),
  ],
  3: [
    NotePosition(tone: BaseTones.F, octave: 1, accidental: Accidentals.sharp, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.C, octave: 1, accidental: Accidentals.sharp, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.G, octave: 1, accidental: Accidentals.sharp, length: NoteLength.quarter),
  ],
  4: [
    NotePosition(tone: BaseTones.F, octave: 1, accidental: Accidentals.sharp, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.C, octave: 1, accidental: Accidentals.sharp, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.G, octave: 1, accidental: Accidentals.sharp, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.D, octave: 1, accidental: Accidentals.sharp, length: NoteLength.quarter),
  ],
  5: [
    NotePosition(tone: BaseTones.F, octave: 1, accidental: Accidentals.sharp, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.C, octave: 1, accidental: Accidentals.sharp, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.G, octave: 1, accidental: Accidentals.sharp, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.D, octave: 1, accidental: Accidentals.sharp, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.A, octave: 0, accidental: Accidentals.sharp, length: NoteLength.quarter),
  ],
  6: [
    NotePosition(tone: BaseTones.F, octave: 1, accidental: Accidentals.sharp, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.C, octave: 1, accidental: Accidentals.sharp, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.G, octave: 1, accidental: Accidentals.sharp, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.D, octave: 1, accidental: Accidentals.sharp, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.A, octave: 0, accidental: Accidentals.sharp, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.E, octave: 1, accidental: Accidentals.sharp, length: NoteLength.quarter),
  ],
  -1: [
    NotePosition(tone: BaseTones.B, octave: 0, accidental: Accidentals.flat, length: NoteLength.quarter),
  ],
  -2: [
    NotePosition(tone: BaseTones.B, octave: 0, accidental: Accidentals.flat, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.E, octave: 1, accidental: Accidentals.flat, length: NoteLength.quarter),
  ],
  -3: [
    NotePosition(tone: BaseTones.B, octave: 0, accidental: Accidentals.flat, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.E, octave: 1, accidental: Accidentals.flat, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.A, octave: 0, accidental: Accidentals.flat, length: NoteLength.quarter),
  ],
  -4: [
    NotePosition(tone: BaseTones.B, octave: 0, accidental: Accidentals.flat, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.E, octave: 1, accidental: Accidentals.flat, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.A, octave: 0, accidental: Accidentals.flat, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.D, octave: 1, accidental: Accidentals.flat, length: NoteLength.quarter),
  ],
  -5: [
    NotePosition(tone: BaseTones.B, octave: 0, accidental: Accidentals.flat, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.E, octave: 1, accidental: Accidentals.flat, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.A, octave: 0, accidental: Accidentals.flat, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.D, octave: 1, accidental: Accidentals.flat, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.G, octave: 0, accidental: Accidentals.flat, length: NoteLength.quarter),
  ],
  -6: [
    NotePosition(tone: BaseTones.B, octave: 0, accidental: Accidentals.flat, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.E, octave: 1, accidental: Accidentals.flat, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.A, octave: 0, accidental: Accidentals.flat, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.D, octave: 1, accidental: Accidentals.flat, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.G, octave: 0, accidental: Accidentals.flat, length: NoteLength.quarter),
    NotePosition(tone: BaseTones.C, octave: 1, accidental: Accidentals.flat, length: NoteLength.quarter),
  ],
};