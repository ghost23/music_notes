import 'package:flutter/foundation.dart';
import 'package:music_notes_2/notes/generated/glyph-definitions.dart';

import 'glyph-table.dart';

enum Clefs { g, f }
enum TimeSignatures { threeFour, fourFour }

const Map<TimeSignatures, String> _timeSignatureMap = {
  TimeSignatures.threeFour: threeFourTime,
  TimeSignatures.fourFour: fourFourTime,
};

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

const Map<NoteLength, String> _singleNoteDownByLength = {
  NoteLength.full: noteWhole,
  NoteLength.half: noteHalfDown,
  NoteLength.quarter: noteQuarterDown,
  NoteLength.eigth: note8thDown,
  NoteLength.sixteenth: note16thDown,
  NoteLength.thirtysecond: note32ndDown,
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

/// This is the main API, which consumers should use. This idea behind this
/// is a 'fluent interface'. So each public facing method is always returning
/// the next MusicContext, with which you can continue to put stuff on the
/// stave.
/// You can start by instantiating MusicContext yourself or you use the nifty
/// start factory method, which will directly setup the desired clef with time
/// signature and the desired general accidentals.
/// MusicContext has a nice toString() method, which will always print whatever
/// you have come up with so far.
class MusicContext {
  MusicContext({
    @required this.clef,
    @required this.mainTone,
    this.currentLine = '',
  });

  final Clefs clef;
  final MainTones mainTone;
  final String currentLine;

  MusicContext.start({this.clef, this.mainTone, TimeSignatures timeSignature}) : currentLine = '${clef == Clefs.g ? gClefStart : fClefStart}${_mainAccidentals(clef, mainTone)}${_timeSignatureMap[timeSignature]}$staff5Lines=';

  static String _mainAccidentals(Clefs clef, MainTones mainTone) {
    if(mainTone == MainTones.C_A) return '';

    List<Note> accidentals = clef == Clefs.g ? mainToneAccidentalsMapForGClef[mainTone] : mainToneAccidentalsMapForFClef[mainTone];
    return accidentals.fold('', (result, note) => result + '$staff5LinesNarrow${_notePrefix(clef, note)}${_accidentalStringMap[note.accidental]}${__conditionalSpace(clef, note, '-')}');
  }

  /// Internal: This is a workaround for a bug in the BravuraText.otf font, version 1.39
  /// https://github.com/steinbergmedia/bravura/issues/31
  /// If a note or an accidental or a leger line is placed in its default position,
  /// it unexpectedly brings its own space.
  static String __conditionalSpace(Clefs clef, Note note, String space) {
    final prefix = _notePrefix(clef, note);
    return prefix == '' ? '' : space;
  }

  /// Internal: This is a workaround for a bug in the BravuraText.otf font, version 1.39
  /// https://github.com/steinbergmedia/bravura/issues/31
  /// If a note or an accidental or a leger line is placed in its default position,
  /// it unexpectedly brings its own space.
  String _conditionalSpace(Note note, String space) => __conditionalSpace(clef, note, space);

  /// Exactly, what it says. Put a single note on the stave.
  /// Note: If you have set your general tone in a way, that you have an general accidental on the note
  /// you are about to insert and that note also wants to put an accidental on the stave, the code
  /// will ignore that. Example:
  /// You have set you music to be in F major, so you general accidental is a "flat" on B.
  /// So if you now would insert a note B with an accidental "flat", we would ignore that, because
  /// we would see, that the general accidentals already has that one.
  /// On the other hand you can of course put a "natural" accidental to your note B, which will then
  /// display correctly.
  /// This means, that you cannot have notes with double accidentals.
  MusicContext insertSingleNote(Note note, NoteLength length) {
    final staff = length.index > NoteLength.quarter.index ? staff5LinesWide : staff5Lines;
    final space = length.index > NoteLength.quarter.index ? _conditionalSpace(note, '=-') : _conditionalSpace(note, '=');

    // < 15 or > 25
    String ledgers = '';
    if(note.positionalValue() < 15) {
      ledgers = '${_notePrefix(clef, Note(tone: BaseTones.C, octave: 2))}$legerLine';
    } else if(note.positionalValue() > 25) {
      ledgers = '${_notePrefix(clef, Note(tone: BaseTones.A, octave: 3))}$legerLine';
    }
    if(note.positionalValue() < 13) {
      ledgers += '${_notePrefix(clef, Note(tone: BaseTones.A, octave: 1))}$legerLine';
    } else if(note.positionalValue() > 27) {
      ledgers += '${_notePrefix(clef, Note(tone: BaseTones.C, octave: 4))}$legerLine';
    }

    String localAccidental = '';
    List<Note> alreadyAppliedAccidentals = clef == Clefs.g ? mainToneAccidentalsMapForGClef[mainTone] : mainToneAccidentalsMapForFClef[mainTone];
    final alreadyAppliedAccidentalExists = alreadyAppliedAccidentals.any((accidental) => accidental.tone == note.tone && (accidental.accidental == note.accidental || note.accidental == Accidentals.natural));
    if((!alreadyAppliedAccidentalExists && note.accidental != Accidentals.natural) || (alreadyAppliedAccidentalExists && note.accidental == Accidentals.natural)) {
      localAccidental = '$staff5LinesNarrow${_notePrefix(clef, note)}${_accidentalStringMap[note.accidental]}${_conditionalSpace(note, '-')}';
    }

    return _attachLine('$localAccidental$staff$ledgers${_notePrefix(clef, note)}${clef == Clefs.g ? _singleNoteUpByLength[length] : _singleNoteDownByLength[length]}$space');
  }

  /// Little utility, probably you don't need it, we use it internally
  MusicContext copyEmpty() => MusicContext(clef: clef, mainTone: mainTone, currentLine: '');

  /// You want to put stuff between repeat bars? Look no further! Pass a function that returns
  /// a string representing whatever you want to put between the repeat bars. Of course you
  /// have the MusicContext to help you too. We pass it down to your function as a parameter with the
  /// current clef and mainTone all set.
  MusicContext repeatSection(String section(MusicContext context)) {
    return _attachLine('$staff5Lines$repeatLeft ${section(copyEmpty())}$staff5Lines $repeatRight');
  }

  /// When your music is done, finish you peace with a final bar. This is the only method that
  /// directly returns a String instead of a MusicContext, because we assume the journey has ended here.
  String end() {
    return currentLine + '$staff5LinesNarrow$barlineFinal';
  }

  MusicContext _attachLine(String currentLine) =>
    MusicContext(clef: clef, mainTone: mainTone, currentLine: this.currentLine + currentLine);

  /// Because of this you can just throw your MusicContext in any String. I love it.
  @override
  String toString() {
    return currentLine;
  }
}

const threeFourTime = '$staff5LinesNarrow-$staff5LinesWide$timeSigCombNumerator$timeSig3$timeSigCombDenominator$timeSig4-=';
const fourFourTime = '$staff5LinesNarrow-$staff5LinesWide$timeSigCombNumerator$timeSig4$timeSigCombDenominator$timeSig4-=';

const gClefStart = '$staff5LinesWide$gClef';
const fClefStart = '$staff5LinesWide$fClef';

const stdNotePositionGClef = Note(tone: BaseTones.B, octave: 2);
const stdNotePositionFClef = Note(tone: BaseTones.D, octave: 1);

const raiseNoteFromStd = [
  staffPosRaise1,
  staffPosRaise2,
  staffPosRaise3,
  staffPosRaise4,
  staffPosRaise5,
  staffPosRaise6,
  staffPosRaise7,
  staffPosRaise8,
];

const lowerNoteFromStd = [
  staffPosLower1,
  staffPosLower2,
  staffPosLower3,
  staffPosLower4,
  staffPosLower5,
  staffPosLower6,
  staffPosLower7,
  staffPosLower8,
];

/// potential accidental of note will be ignored, none will be used instead
String _notePrefix(Clefs clef, Note note) {
  if(note.accidental != Accidentals.none) {
    note = Note(tone: note.tone, octave: note.octave);
  }
  int diff = 0;
  if(clef == Clefs.g) {
    /// For g clef we allow notes between small a and small c''' inclusively
    assert(note.octave > 1 || (note.octave == 1 && (note.tone == BaseTones.A || note.tone == BaseTones.B)));
    assert(note.octave < 4 || (note.octave == 4 && note.tone == BaseTones.C));
    diff = note.positionalValue() - stdNotePositionGClef.positionalValue();
  } else if(clef == Clefs.f) {
    /// For f clef we allow notes between capital C and small e' inclusively
    assert(note.octave >= 0);
    assert(note.octave < 2 || (note.octave == 2 && (note.tone == BaseTones.C || note.tone == BaseTones.D || note.tone == BaseTones.E)));
    diff = note.positionalValue() - stdNotePositionFClef.positionalValue();
  }
  if(diff < 0) {
    return lowerNoteFromStd[diff.abs()-1];
  } else if(diff > 0) {
    return raiseNoteFromStd[diff-1];
  } else {
    return '';
  }
}