
import 'dart:ui';

import 'package:music_notes_2/notes/notes.dart';

import '../notes/render-functions/staff.dart';

class Score {
  Score(this.parts);
  final Iterable<Part> parts;
}

class Part {
  Part(this.measures);
  final Iterable<Measure> measures;
}

class Measure {
  Measure(this.contents);
  final Iterable<MeasureContent> contents;
}

class MeasureContent {}

class Barline extends MeasureContent {
  Barline(this.barStyle);
  final BarLineTypes barStyle;
}

class Direction extends MeasureContent {
  Direction(this.type, this.staff, [this.placement]);
  final DirectionType type;
  final int staff;
  final PlacementValue? placement;
}

class DirectionType {}

class OctaveShift extends DirectionType {
  OctaveShift(this.number, this.type, [this.size]);
  final int number;
  final UpDownStopCont type;
  final int? size;
}

enum UpDownStopCont { up, down, stop, continued }

class Wedge extends DirectionType {
  Wedge(this.number, this.type);
  final int number;
  final WedgeType type;
}

enum WedgeType { crescendo, diminuendo, stop, continued }

class Words extends DirectionType {
  Words(this.content, {this.fontFamily, this.fontSize, this.fontStyle, this.fontWeight});
  final String content;
  final String? fontFamily;
  final double? fontSize;
  final FontStyle? fontStyle;
  final FontWeight? fontWeight;
}

enum Clefs { G, F }

/// The tones, that can be put on a stave without accidentals
enum BaseTones { C, D, E, F, G, A, B }

enum Accidentals { none, natural, sharp, flat }

enum NoteLength { whole, half, quarter, eighth, sixteenth, thirtysecond }

class Attributes extends MeasureContent {
  Attributes([this.divisions, this.key, this.staves, this.clefs = const [], this.time]);
  final int? divisions;
  final MusicalKey? key;
  final int? staves;
  final Iterable<Clef> clefs;
  final Time? time;
}

class Time {
  Time(this.beats, this.beatType);
  final int beats;
  final int beatType;
}

class Clef {
  Clef(this.staffNumber, this.sign);
  final int staffNumber;
  final Clefs sign;
}

enum KeyMode {
  none, major, minor, dorian, phrygian, lydian, mixolydian, aeolian, ionian, locrian
}

typedef Fifths = int;
enum CircleOfFifths {
  C_A, G_E, D_B, A_Fsharp, E_Csharp, B_Gsharp, Fsharp_Dsharp, Gflat_Eflat, Dflat_Bflat, Aflat_F, Eflat_C, Bflat_G, F_D
}
const Map<CircleOfFifths, Fifths> _fifthsToIntMap = {
  CircleOfFifths.C_A: 0,
  CircleOfFifths.G_E: 1,
  CircleOfFifths.D_B: 2,
  CircleOfFifths.A_Fsharp: 3,
  CircleOfFifths.E_Csharp: 4,
  CircleOfFifths.B_Gsharp: 5,
  CircleOfFifths.Fsharp_Dsharp: 6,
  CircleOfFifths.F_D: -1,
  CircleOfFifths.Bflat_G: -2,
  CircleOfFifths.Eflat_C: -3,
  CircleOfFifths.Aflat_F: -4,
  CircleOfFifths.Dflat_Bflat: -5,
  CircleOfFifths.Gflat_Eflat: -6,
};

extension CircleOfFifthsValues on CircleOfFifths {
  Fifths get v {
    return _fifthsToIntMap[this]!;
  }
}

class MusicalKey {
  MusicalKey(this.fifths, this.mode);
  final Fifths fifths;
  final KeyMode? mode;
}

class Note extends MeasureContent {
  Note(this.pitch, this.duration, this.voice, this.type, this.stem, this.staff, this.beams, this.notations, {this.dots=0, this.chord=false});
  final Pitch pitch;
  final int duration;
  final int voice;
  final NoteLength type;
  final StemValue stem;
  final int staff;
  final Iterable<Beam> beams;
  final Iterable<Notation> notations;
  final int dots;
  final bool chord;
}

abstract class Notation {
  Notation([PlacementValue? placementValue]): this.placement = placementValue ?? PlacementValue.below;
  final PlacementValue placement;
}

class Tied extends Notation {
  Tied(this.number, this.type, [ PlacementValue? placement ]): super(placement);
  final int number;
  final StCtStpValue type;
}

class Slur extends Notation {
  Slur(this.number, this.type, [ PlacementValue? placement ]): super(placement);
  final int number;
  final StCtStpValue type;
}

class Fingering extends Notation {
  Fingering(this.value, [ PlacementValue? placement ]): super(placement);
  final String value;
}

class Accent extends Notation {
  Accent([ PlacementValue? placement ]): super(placement);
}

class Staccato extends Notation {
  Staccato([ PlacementValue? placement ]): super(placement);
}

class Dynamics extends Notation {
  Dynamics(this.type, [ PlacementValue? placement ]): super(placement);
  final DynamicType type;
}

enum DynamicType { p, pp, ppp, pppp, ppppp, pppppp, f, ff, fff, ffff, fffff, ffffff, mp, mf, sf, sfp, sfpp, fp, rf, rfz, sfz, sffz, fz, n, pf, sfzp }

enum StCtStpValue { start, continued, stop }

enum StemValue { down, up, double, none }

enum BeamValue { backward, begin, continued, end, forward }

enum PlacementValue { above, below }

class Beam {
  Beam(this.number, this.value);
  final int number;
  final BeamValue value;
}

class Pitch {
  Pitch(this.step, this.octave, [this.alter]);
  final BaseTones step;
  final int octave;
  final int? alter;
}

class Backup extends MeasureContent {
  Backup(this.duration);
  final int duration;
}

class Forward extends MeasureContent {
  Forward(this.duration);
  final int duration;
}

/// A data representation of almost anything - but mostly notes - that can be put on staves,
/// like notes, accidentals, legers, articulation glyphs, etc.
/// It is more a positional info object. Maybe we should not actually call it Note?!
class PositionalElement {
  const PositionalElement(this.tone, this.octave, {this.length, this.accidental = Accidentals.none});

  final BaseTones tone;
  final Accidentals accidental;
  /// 0 = C, 1 = c, 2 = c', etc.
  final int octave;
  final NoteLength? length;

  PositionalElement.fromNumericValue(int value, this.length, bool preferSharp) :
        octave = (value / 12).floor(),
        tone = baseToneFromNumericValue(value, preferSharp),
        accidental = accidentalFromNumericValue(value, preferSharp);

  int diffToNote(PositionalElement other) {
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
    return other is PositionalElement &&
        numericValue() == other.numericValue();
  }

  bool operator >(Object other) {
    return other is PositionalElement &&
        numericValue() > other.numericValue();
  }

  bool operator >=(Object other) {
    return other is PositionalElement &&
        numericValue() >= other.numericValue();
  }

  bool operator <(Object other) {
    return other is PositionalElement &&
        numericValue() < other.numericValue();
  }

  bool operator <=(Object other) {
    return other is PositionalElement &&
        numericValue() <= other.numericValue();
  }

  @override
  String toString() {
    return 'PositionalElement(tone: $tone, accidental: $accidental, octave: $octave)';
  }

  @override
  int get hashCode => tone.hashCode ^ accidental.hashCode ^ octave.hashCode;

}