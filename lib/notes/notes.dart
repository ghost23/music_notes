import 'package:music_notes_2/notes/generated/glyph-definitions.dart';
import 'glyph-table.dart';

enum Clefs { g, f }
enum TimeSignatures { threeFour, fourFour }

/// The tones on the circle of fifths
enum MainTones { C_A, G_E, D_B, A_Fsharp, E_Csharp, B_Gsharp, Gflat_Eflat, Dflat_Bflat, Aflat_F, Eflat_C, Bflat_G, F_D }

/// The tones, that can be put on a stave without accidentals
enum BaseTones { C, D, E, F, G, A, B }

enum NoteLength { full, half, quarter, eigth, sixteenth, thirtysecond }

const Map<NoteLength, String> _singleNoteUpByLength = {
  NoteLength.full: noteWhole,
  NoteLength.half: noteHalfUp,
  NoteLength.quarter: noteQuarterUp,
  NoteLength.eigth: note8thUp,
  NoteLength.sixteenth: note16thUp,
  NoteLength.thirtysecond: note32ndUp,
};

const Map<NoteLength, Glyph> singleNoteUpByLength = {
  NoteLength.full: Glyph.noteWhole,
  NoteLength.half: Glyph.noteHalfUp,
  NoteLength.quarter: Glyph.noteQuarterUp,
  NoteLength.eigth: Glyph.note8thUp,
  NoteLength.sixteenth: Glyph.note16thUp,
  NoteLength.thirtysecond: Glyph.note32ndUp,
};

const Map<NoteLength, Glyph> singleNoteHeadByLength = {
  NoteLength.full: Glyph.noteheadWhole,
  NoteLength.half: Glyph.noteheadHalf,
  NoteLength.quarter: Glyph.noteheadBlack,
  NoteLength.eigth: Glyph.noteheadBlack,
  NoteLength.sixteenth: Glyph.noteheadBlack,
  NoteLength.thirtysecond: Glyph.noteheadBlack,
};

const Map<NoteLength, Glyph> singleNoteDownByLength = {
  NoteLength.full: Glyph.noteWhole,
  NoteLength.half: Glyph.noteHalfDown,
  NoteLength.quarter: Glyph.noteQuarterDown,
  NoteLength.eigth: Glyph.note8thDown,
  NoteLength.sixteenth: Glyph.note16thDown,
  NoteLength.thirtysecond: Glyph.note32ndDown,
};

const Map<BaseTones, int> _numericValueOfBaseTone = {
  BaseTones.C: 0,
  BaseTones.D: 2,
  BaseTones.E: 4,
  BaseTones.F: 5,
  BaseTones.G: 7,
  BaseTones.A: 9,
  BaseTones.B: 11,
};

enum Accidentals { none, natural, sharp, flat }

const Map<Accidentals, int> _numericValueOfAccidental = {
  Accidentals.sharp: 1,
  Accidentals.flat: -1,
  Accidentals.none: 0,
  Accidentals.natural: 0,
};


const Map<Accidentals, String> _accidentalStringMap = {
  Accidentals.none: '',
  Accidentals.natural: accidentalNatural,
  Accidentals.sharp: accidentalSharp,
  Accidentals.flat: accidentalFlat,
};

const Map<Accidentals, Glyph> accidentalGlyphMap = {
  Accidentals.none: null,
  Accidentals.natural: Glyph.accidentalNatural,
  Accidentals.sharp: Glyph.accidentalSharp,
  Accidentals.flat: Glyph.accidentalFlat,
};

///Whenever you see something with 'numericValue' in it, it is a representation
///of an absolute note position. The capital C is numericValue = 0, small c = 12, c' = 24, etc.
///you know, the octaves. So a D in the octave of capital C would be = 2, and so on.

BaseTones _baseToneFromNumericValue(int value, bool preferSharp) {
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

Accidentals _accidentalFromNumericValue(int value, bool preferSharp) {
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
class Note {
  const Note({this.tone, this.length, this.accidental = Accidentals.none, this.octave});

  final BaseTones tone;
  final Accidentals accidental;
  /// 0 = C, 1 = c, 2 = c', etc.
  final int octave;
  final NoteLength length;

  Note.fromNumericValue(int value, this.length, bool preferSharp) :
      octave = (value / 12).floor(),
      tone = _baseToneFromNumericValue(value, preferSharp),
      accidental = _accidentalFromNumericValue(value, preferSharp);

  int diffToNote(Note other) {
    return numericValue() - other.numericValue();
  }

  int numericValue() {
    return octave * 12 + (_numericValueOfBaseTone[tone] + _numericValueOfAccidental[accidental]);
  }

  /// positional value is a value to determine where on a stave a note should be put.
  /// So here we only care about the "white keys"-notes, which I called BaseNotes up above.
  /// That's why an octave here has only 7 notes in it.
  int positionalValue() {
    return octave * 7 + BaseTones.values.indexOf(tone);
  }

  @override
  bool operator ==(Object other) {
    return other is Note &&
      numericValue() == other.numericValue();
  }

  bool operator >(Object other) {
    return other is Note &&
    numericValue() > other.numericValue();
  }

  bool operator >=(Object other) {
    return other is Note &&
        numericValue() >= other.numericValue();
  }

  bool operator <(Object other) {
    return other is Note &&
        numericValue() < other.numericValue();
  }

  bool operator <=(Object other) {
    return other is Note &&
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
const Map<MainTones, List<Note>> mainToneAccidentalsMapForGClef = {
  MainTones.G_E: [
    Note(tone: BaseTones.F, octave: 3, accidental: Accidentals.sharp),
  ],
  MainTones.D_B: [
    Note(tone: BaseTones.F, octave: 3, accidental: Accidentals.sharp),
    Note(tone: BaseTones.C, octave: 3, accidental: Accidentals.sharp),
  ],
  MainTones.A_Fsharp: [
    Note(tone: BaseTones.F, octave: 3, accidental: Accidentals.sharp),
    Note(tone: BaseTones.C, octave: 3, accidental: Accidentals.sharp),
    Note(tone: BaseTones.G, octave: 3, accidental: Accidentals.sharp),
  ],
  MainTones.E_Csharp: [
    Note(tone: BaseTones.F, octave: 3, accidental: Accidentals.sharp),
    Note(tone: BaseTones.C, octave: 3, accidental: Accidentals.sharp),
    Note(tone: BaseTones.G, octave: 3, accidental: Accidentals.sharp),
    Note(tone: BaseTones.D, octave: 3, accidental: Accidentals.sharp),
  ],
  MainTones.B_Gsharp: [
    Note(tone: BaseTones.F, octave: 3, accidental: Accidentals.sharp),
    Note(tone: BaseTones.C, octave: 3, accidental: Accidentals.sharp),
    Note(tone: BaseTones.G, octave: 3, accidental: Accidentals.sharp),
    Note(tone: BaseTones.D, octave: 3, accidental: Accidentals.sharp),
    Note(tone: BaseTones.A, octave: 2, accidental: Accidentals.sharp),
  ],
  MainTones.F_D: [
    Note(tone: BaseTones.B, octave: 2, accidental: Accidentals.flat),
  ],
  MainTones.Bflat_G: [
    Note(tone: BaseTones.B, octave: 2, accidental: Accidentals.flat),
    Note(tone: BaseTones.E, octave: 3, accidental: Accidentals.flat),
  ],
  MainTones.Eflat_C: [
    Note(tone: BaseTones.B, octave: 2, accidental: Accidentals.flat),
    Note(tone: BaseTones.E, octave: 3, accidental: Accidentals.flat),
    Note(tone: BaseTones.A, octave: 2, accidental: Accidentals.flat),
  ],
  MainTones.Aflat_F: [
    Note(tone: BaseTones.B, octave: 2, accidental: Accidentals.flat),
    Note(tone: BaseTones.E, octave: 3, accidental: Accidentals.flat),
    Note(tone: BaseTones.A, octave: 2, accidental: Accidentals.flat),
    Note(tone: BaseTones.D, octave: 3, accidental: Accidentals.flat),
  ],
  MainTones.Dflat_Bflat: [
    Note(tone: BaseTones.B, octave: 2, accidental: Accidentals.flat),
    Note(tone: BaseTones.E, octave: 3, accidental: Accidentals.flat),
    Note(tone: BaseTones.A, octave: 2, accidental: Accidentals.flat),
    Note(tone: BaseTones.D, octave: 3, accidental: Accidentals.flat),
    Note(tone: BaseTones.G, octave: 2, accidental: Accidentals.flat),
  ],
  MainTones.Gflat_Eflat: [
    Note(tone: BaseTones.B, octave: 2, accidental: Accidentals.flat),
    Note(tone: BaseTones.E, octave: 3, accidental: Accidentals.flat),
    Note(tone: BaseTones.A, octave: 2, accidental: Accidentals.flat),
    Note(tone: BaseTones.D, octave: 3, accidental: Accidentals.flat),
    Note(tone: BaseTones.G, octave: 2, accidental: Accidentals.flat),
    Note(tone: BaseTones.C, octave: 3, accidental: Accidentals.flat),
  ],
};

const Map<MainTones, List<Note>> mainToneAccidentalsMapForFClef = {
  MainTones.G_E: [
    Note(tone: BaseTones.F, octave: 1, accidental: Accidentals.sharp),
  ],
  MainTones.D_B: [
    Note(tone: BaseTones.F, octave: 1, accidental: Accidentals.sharp),
    Note(tone: BaseTones.C, octave: 1, accidental: Accidentals.sharp),
  ],
  MainTones.A_Fsharp: [
    Note(tone: BaseTones.F, octave: 1, accidental: Accidentals.sharp),
    Note(tone: BaseTones.C, octave: 1, accidental: Accidentals.sharp),
    Note(tone: BaseTones.G, octave: 1, accidental: Accidentals.sharp),
  ],
  MainTones.E_Csharp: [
    Note(tone: BaseTones.F, octave: 1, accidental: Accidentals.sharp),
    Note(tone: BaseTones.C, octave: 1, accidental: Accidentals.sharp),
    Note(tone: BaseTones.G, octave: 1, accidental: Accidentals.sharp),
    Note(tone: BaseTones.D, octave: 1, accidental: Accidentals.sharp),
  ],
  MainTones.B_Gsharp: [
    Note(tone: BaseTones.F, octave: 1, accidental: Accidentals.sharp),
    Note(tone: BaseTones.C, octave: 1, accidental: Accidentals.sharp),
    Note(tone: BaseTones.G, octave: 1, accidental: Accidentals.sharp),
    Note(tone: BaseTones.D, octave: 1, accidental: Accidentals.sharp),
    Note(tone: BaseTones.A, octave: 0, accidental: Accidentals.sharp),
  ],
  MainTones.F_D: [
    Note(tone: BaseTones.B, octave: 0, accidental: Accidentals.flat),
  ],
  MainTones.Bflat_G: [
    Note(tone: BaseTones.B, octave: 0, accidental: Accidentals.flat),
    Note(tone: BaseTones.E, octave: 1, accidental: Accidentals.flat),
  ],
  MainTones.Eflat_C: [
    Note(tone: BaseTones.B, octave: 0, accidental: Accidentals.flat),
    Note(tone: BaseTones.E, octave: 1, accidental: Accidentals.flat),
    Note(tone: BaseTones.A, octave: 0, accidental: Accidentals.flat),
  ],
  MainTones.Aflat_F: [
    Note(tone: BaseTones.B, octave: 0, accidental: Accidentals.flat),
    Note(tone: BaseTones.E, octave: 1, accidental: Accidentals.flat),
    Note(tone: BaseTones.A, octave: 0, accidental: Accidentals.flat),
    Note(tone: BaseTones.D, octave: 1, accidental: Accidentals.flat),
  ],
  MainTones.Dflat_Bflat: [
    Note(tone: BaseTones.B, octave: 0, accidental: Accidentals.flat),
    Note(tone: BaseTones.E, octave: 1, accidental: Accidentals.flat),
    Note(tone: BaseTones.A, octave: 0, accidental: Accidentals.flat),
    Note(tone: BaseTones.D, octave: 1, accidental: Accidentals.flat),
    Note(tone: BaseTones.G, octave: 0, accidental: Accidentals.flat),
  ],
  MainTones.Gflat_Eflat: [
    Note(tone: BaseTones.B, octave: 0, accidental: Accidentals.flat),
    Note(tone: BaseTones.E, octave: 1, accidental: Accidentals.flat),
    Note(tone: BaseTones.A, octave: 0, accidental: Accidentals.flat),
    Note(tone: BaseTones.D, octave: 1, accidental: Accidentals.flat),
    Note(tone: BaseTones.G, octave: 0, accidental: Accidentals.flat),
    Note(tone: BaseTones.C, octave: 1, accidental: Accidentals.flat),
  ],
};