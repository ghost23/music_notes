import 'dart:ui';
import 'package:music_notes_2/notes/notes.dart';

import '../notes/render-functions/staff.dart';

class Score {
  Score(this.parts);
  final List<Part> parts;
  get isEmpty => parts.isEmpty || parts.first.isEmpty;
}

class Part {
  Part(this.measures);
  final List<Measure> measures;
  get isEmpty => measures.isEmpty;
}

class Measure {
  Measure(this.contents);
  final List<MeasureContent> contents;
  Attributes? get attributes {
    final attributes = contents.whereType<Attributes>();
    return attributes.isNotEmpty ? attributes.first : null;
  }
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
  Words(this.content,
      {this.fontFamily, this.fontSize, this.fontStyle, this.fontWeight});
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
  Attributes([this.divisions, this.key, this.staves, this.clefs, this.time]);
  final int? divisions;
  final MusicalKey? key;
  final int? staves;
  final List<Clef>? clefs;
  final Time? time;

  bool get isValidForFirstMeasure =>
      divisions != null &&
      key != null &&
      staves != null &&
      clefs != null &&
      clefs!.isNotEmpty &&
      time != null;

  Attributes copyWithParams(
      {int? divisions,
      MusicalKey? key,
      int? staves,
      List<Clef>? clefs,
      Time? time}) {
    return Attributes(
      divisions ?? this.divisions,
      key ?? this.key,
      staves ?? this.staves,
      clefs ?? this.clefs,
      time ?? this.time,
    );
  }

  Attributes copyWithObject(Attributes attributes) {
    return Attributes(
      attributes.divisions ?? this.divisions,
      attributes.key ?? this.key,
      attributes.staves ?? this.staves,
      attributes.clefs ?? this.clefs,
      attributes.time ?? this.time,
    );
  }
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
  none,
  major,
  minor,
  dorian,
  phrygian,
  lydian,
  mixolydian,
  aeolian,
  ionian,
  locrian
}

typedef Fifths = int;
enum CircleOfFifths {
  C_A,
  G_E,
  D_B,
  A_Fsharp,
  E_Csharp,
  B_Gsharp,
  Fsharp_Dsharp,
  Gflat_Eflat,
  Dflat_Bflat,
  Aflat_F,
  Eflat_C,
  Bflat_G,
  F_D
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
  Note(this.duration, this.voice, this.staff, this.notations);
  final int duration;
  final int voice;
  final int staff;
  final List<Notation> notations;
}

class RestNote extends Note {
  RestNote(int duration, int voice, int staff, List<Notation> notations) : super(duration, voice, staff, notations);
}

class PitchNote extends Note {
  PitchNote(int duration, int voice, int staff, List<Notation> notations,
      this.pitch, this.type, this.stem, this.beams,
      {this.dots = 0, this.chord = false})
      : super(duration, voice, staff, notations);
  final Pitch pitch;
  final NoteLength type;
  final StemValue stem;
  final List<Beam> beams;
  final int dots;
  final bool chord;

  NotePosition get notePosition => NotePosition(
      tone: pitch.step,
      length: type,
      octave: pitch.octave,
      accidental: pitch.accidental,
  );
}

abstract class Notation {
  Notation([PlacementValue? placementValue])
      : this.placement = placementValue ?? PlacementValue.below;
  final PlacementValue placement;
}

class Tied extends Notation {
  Tied(this.number, this.type, [PlacementValue? placement]) : super(placement);
  final int number;
  final StCtStpValue type;
}

class Slur extends Notation {
  Slur(this.number, this.type, [PlacementValue? placement]) : super(placement);
  final int number;
  final StCtStpValue type;
}

class Fingering extends Notation {
  Fingering(this.value, [PlacementValue? placement]) : super(placement);
  final String value;
}

class Accent extends Notation {
  Accent([PlacementValue? placement]) : super(placement);
}

class Staccato extends Notation {
  Staccato([PlacementValue? placement]) : super(placement);
}

class Dynamics extends Notation {
  Dynamics(this.type, [PlacementValue? placement]) : super(placement);
  final DynamicType type;
}

enum DynamicType {
  p,
  pp,
  ppp,
  pppp,
  ppppp,
  pppppp,
  f,
  ff,
  fff,
  ffff,
  fffff,
  ffffff,
  mp,
  mf,
  sf,
  sfp,
  sfpp,
  fp,
  rf,
  rfz,
  sfz,
  sffz,
  fz,
  n,
  pf,
  sfzp
}

enum StCtStpValue { start, continued, stop }

enum StemValue { down, up, double, none }

enum BeamValue { backward, begin, continued, end, forward }

enum PlacementValue { above, below }

class Beam {
  Beam(this.id, this.number, this.value);
  final int id;
  final int number;
  final BeamValue value;

  @override
  String toString() {
    return 'Beam(id: $id, number: $number, value: $value)';
  }
}

class Pitch {
  Pitch(this.step, this.octave, [this.alter]);
  final BaseTones step;
  final int octave;
  final int? alter;

  Accidentals get accidental => alter == null || alter == 0
      ? Accidentals.none
      : (alter == -1
          ? Accidentals.flat
          : (alter == 1 ? Accidentals.sharp : Accidentals.none));
}

class Backup extends MeasureContent {
  Backup(this.duration);
  final int duration;
}

class Forward extends MeasureContent {
  Forward(this.duration);
  final int duration;
}
