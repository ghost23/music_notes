import 'dart:ui';
import 'package:music_notes_2/notes/render-functions/staff.dart';
import 'package:xml/xml.dart';
import 'dart:io';
import 'data.dart';

XmlDocument loadMusicXMLFile(String filePath) {
  final File file = File(filePath);
  return XmlDocument.parse(file.readAsStringSync());
}

Score parseMusicXML(XmlDocument document) {
  final parts = document.findAllElements('part');
  return Score(parts.map(parsePartXML));
}

Part parsePartXML(XmlElement partXML) {
  final measures = partXML.findAllElements('measure');
  return Part(measures.map(parseMeasureXML));
}

Measure parseMeasureXML(XmlElement measureXML) {
  final childElements = measureXML.children.whereType<XmlElement>();
  final Iterable<MeasureContent> contents = childElements.map((child) {
    switch (child.name.qualified) {
      case 'attributes': {
        return parseAttributesXML(child);
      }
      case 'barline': {
        return parseBarlineXML(child);
      }
      case 'direction': {
        return parseDirectionXML(child);
      }
      case 'note': {
        return parseNoteXML(child);
      }
      case 'backup': {
        return parseBackupXML(child);
      }
      case 'forward': {
        return parseForwardXML(child);
      }
      default: {
        return null;
      }
    }
  }).whereType<MeasureContent>();

  return Measure(contents);
}

Attributes? parseAttributesXML(XmlElement attributesXML) {
  final divisionsElmt = attributesXML.getElement('divisions');
  final int? divisions = divisionsElmt != null ? int.parse(divisionsElmt.innerText) : null;

  final keyElmt = attributesXML.getElement('key');
  MusicalKey? key;
  if(keyElmt != null) {
    final fifthElmt = keyElmt.getElement('fifths');
    final int? fifth = fifthElmt != null ? int.parse(fifthElmt.innerText) : null;

    final modeElmt = keyElmt.getElement('mode');
    final String? modeString = modeElmt?.innerText;
    final KeyMode? mode = modeString != null ? KeyMode.values.firstWhere((e) => e.toString() == 'KeyMode.$modeString') : null;

    if(fifth != null) {
      key = MusicalKey(fifth, mode);
    }
  }

  final stavesElmt = attributesXML.getElement('staves');
  final int? staves = stavesElmt != null ? int.parse(stavesElmt.innerText) : null;

  final clefElmts = attributesXML.findAllElements('clef');
  Iterable<Clef> clefs = [];
  if(clefElmts.isNotEmpty) {
    clefs = clefElmts.map((clefElmt) {
      final signElmt = clefElmt.getElement('sign');
      final String? signString = signElmt?.innerText;
      final Clefs? sign = signString != null ? Clefs.values.firstWhere((e) => e.toString() == 'Clefs.$signString') : null;

      final int number = int.parse(clefElmt.getAttribute('number') ?? '1');

      if(sign != null) {
        return Clef(number, sign);
      } else return null;
    }).whereType<Clef>();
  }

  final timeElmt = attributesXML.getElement('time');
  Time? time;
  if(timeElmt != null) {
    final beatsElmt = timeElmt.getElement('beats');
    final int? beats = beatsElmt != null ? int.parse(beatsElmt.innerText) : null;

    final beatTypeElmt = timeElmt.getElement('beat-type');
    final int? beatType = beatTypeElmt != null ? int.parse(beatTypeElmt.innerText) : null;

    if(beats != null && beatType != null) {
      time = Time(beats, beatType);
    }
  }
  if(divisions == null && key == null && staves == null && clefs.length <= 0 && time == null) {
    return null;
  } else {
    return Attributes(divisions, key, staves, clefs, time);
  }
}

Barline parseBarlineXML(XmlElement barlineXML) {
  final String? barStyleString = barlineXML.getElement('bar-style')?.innerText;
  final BarLineTypes sign;
  switch (barStyleString) {
    case 'dashed': sign = BarLineTypes.dashed; break;
    case 'heavy': sign = BarLineTypes.heavy; break;
    case 'heavy-heavy': sign = BarLineTypes.heavyHeavy; break;
    case 'heavy-light': sign = BarLineTypes.dashed; break;
    case 'light-heavy': sign = BarLineTypes.dashed; break;
    case 'light-light': sign = BarLineTypes.dashed; break;
    default: sign = BarLineTypes.regular;
  }

  return Barline(sign);
}

Direction? parseDirectionXML(XmlElement directionXML) {
  final typeElmt = directionXML.getElement('direction-type');
  DirectionType? type;
  switch (typeElmt?.innerText) {
    case 'octave-shift': type = parseOctaveShiftXML(typeElmt!); break;
    case 'wedge': type = parseWedgeXML(typeElmt!); break;
    case 'words': type = parseWordsXML(typeElmt!); break;
    case null: {
      throw new AssertionError('direction-type element missing in direction.');
    }
    default: {
      return null;
    }
  }
  final String? placementString = directionXML.getAttribute('placement');
  final PlacementValue? placement = placementString != null ? PlacementValue.values.firstWhere((e) => e.toString() == 'PlacementValue.$placementString') : null;

  final staffElmt = directionXML.getElement('staff');
  final int? staff = staffElmt != null ? int.parse(staffElmt.innerText) : null;

  if(type != null && staff != null) {
    return Direction(type, staff, placement);
  } else {
    return null;
  }
}

OctaveShift? parseOctaveShiftXML(XmlElement octaveShiftXML) {
  final int number = int.parse(octaveShiftXML.getAttribute('number') ?? '1');

  final String? typeString = octaveShiftXML.getAttribute('type');
  final UpDownStopCont? type = typeString != null ? UpDownStopCont.values.firstWhere((e) => e.toString() == 'UpDownStopCont.$typeString') : null;

  final sizeAttr = octaveShiftXML.getAttribute('size');
  final int? size = sizeAttr != null ? int.parse(sizeAttr) : null;

  if(type != null) {
    return OctaveShift(number, type, size);
  } else {
    return null;
  }
}

Wedge? parseWedgeXML(XmlElement wedgeXML) {
  final int number = int.parse(wedgeXML.getAttribute('number') ?? '1');

  final String? typeString = wedgeXML.getAttribute('type');
  final WedgeType? type = typeString != null ? WedgeType.values.firstWhere((e) => e.toString() == 'WedgeType.$typeString') : null;

  if(type != null) {
    return Wedge(number, type);
  } else {
    return null;
  }
}

Words? parseWordsXML(XmlElement wordsXML) {
  final String content = wordsXML.innerText;

  final fontFamily = wordsXML.getAttribute('font-family');

  final fontSizeString = wordsXML.getAttribute('font-size');
  final double? fontSize = fontSizeString != null ? double.parse(fontSizeString) : null;

  final String? fontStyleString = wordsXML.getAttribute('font-styles');
  final FontStyle? fontStyle = fontStyleString != null ? FontStyle.values.firstWhere((e) => e.toString() == 'FontStyle.$fontStyleString') : null;

  final String? fontWeightString = wordsXML.getAttribute('font-weight');
  final FontWeight? fontWeight;
  switch(fontWeightString) {
    case 'normal': fontWeight = FontWeight.normal; break;
    case 'bold': fontWeight = FontWeight.bold; break;
    default: fontWeight = null;
  }

  if(content.length > 0) {
    return Words(content, fontFamily: fontFamily, fontSize: fontSize, fontStyle: fontStyle, fontWeight: fontWeight);
  } else {
    return null;
  }
}

PlacementValue? parsePlacementAttr(XmlElement someXML) {
  final String? placementString = someXML.getAttribute('placement');
  return placementString != null ? PlacementValue.values.firstWhere((e) => e.toString() == 'PlacementValue.$placementString') : null;
}

Note? parseNoteXML(XmlElement noteXML) {
  final pitchElmt = noteXML.getElement('pitch');
  final pitch = pitchElmt != null ? parsePitchXML(pitchElmt) : null;

  final durationElmt = noteXML.getElement('duration');
  final int? duration = durationElmt != null ? int.parse(durationElmt.innerText) : null;

  final voiceElmt = noteXML.getElement('voice');
  final int voice = voiceElmt != null ? int.parse(voiceElmt.innerText) : 1;

  final String? typeString = noteXML.getElement('type')?.innerText;
  final NoteLength? type;
  switch(typeString) {
    case 'whole': type = NoteLength.whole; break;
    case 'half': type = NoteLength.half; break;
    case 'quarter': type = NoteLength.quarter; break;
    case 'eighth': type = NoteLength.eighth; break;
    case '16th': type = NoteLength.sixteenth; break;
    case '32nd': type = NoteLength.thirtysecond; break;
    default: type = null;
  }

  final String? stemString = noteXML.getElement('stem')?.innerText;
  final StemValue? stem = stemString != null ? StemValue.values.firstWhere((e) => e.toString() == 'StemValue.$stemString') : null;

  final staffElmt = noteXML.getElement('staff');
  final int? staff = staffElmt != null ? int.parse(staffElmt.innerText) : null;

  final beamElmts = noteXML.findAllElements('beam');
  final beams = beamElmts.map(parseBeamXML).whereType<Beam>();

  final notationElmts = noteXML.findAllElements('notation');
  final notations = notationElmts.map(parseNotationXML).expand((e) => e);

  final dots = noteXML.findAllElements('dot').length;

  final chord = noteXML.getElement('chord') != null;

  if(pitch != null && duration != null && type != null && stem != null && staff != null) {
    return Note(pitch, duration, voice, type, stem, staff, beams, notations, dots: dots, chord: chord);
  } else {
    return null;
  }
}

Pitch? parsePitchXML(XmlElement pitchXML) {
  final stepElmt = pitchXML.getElement('step');
  final String? stepString = stepElmt?.innerText;
  final BaseTones? step = stepString != null ? BaseTones.values.firstWhere((e) => e.toString() == 'BaseTones.$stepString') : null;

  final octaveElmt = pitchXML.getElement('octave');
  final int? octave = octaveElmt != null ? int.parse(octaveElmt.innerText) : null;

  final alterElmt = pitchXML.getElement('alter');
  final int? alter = alterElmt != null ? int.parse(alterElmt.innerText) : null;

  if(step != null && octave != null) {
    return Pitch(step, octave, alter);
  } else {
    return null;
  }
}

Beam? parseBeamXML(XmlElement beamXML) {
  final String? valueString = beamXML.innerText;
  final BeamValue? value = valueString != null ? BeamValue.values.firstWhere((e) => e.toString() == 'BeamValue.$valueString') : null;

  final int number = int.parse(beamXML.getAttribute('number') ?? '1');

  if(value != null) {
    return Beam(number, value);
  } else {
    return null;
  }
}

Iterable<Notation> parseNotationXML(XmlElement notationXML) {
  final List<Notation> result = [];

  final fingeringElmt = notationXML.findAllElements('fingering');
  final String? fingering = fingeringElmt.length >= 1 ? fingeringElmt.first.innerText : null;
  if(fingering != null) {
    result.add(Fingering(fingering, parsePlacementAttr(fingeringElmt.first)));
  }

  final tiedElement = notationXML.getElement('tied');
  final Tied? tied = tiedElement != null ? parseTiedXML(tiedElement) : null;
  if(tied != null) {
    result.add(tied);
  }

  final slurElement = notationXML.getElement('slur');
  final Slur? slur = slurElement != null ? parseSlurXML(slurElement) : null;
  if(slur != null) {
    result.add(slur);
  }

  final staccatoElmt = notationXML.findAllElements('staccato');
  final bool staccato = staccatoElmt.length >= 1;
  if(staccato) {
    result.add(Staccato(parsePlacementAttr(staccatoElmt.first)));
  }

  final accentElmt = notationXML.findAllElements('accent');
  final bool accent = accentElmt.length >= 1;
  if(accent) {
    result.add(Accent(parsePlacementAttr(accentElmt.first)));
  }

  final dynamicsElmt = notationXML.getElement('dynamics');
  final String? dynamicString = dynamicsElmt?.firstElementChild?.name.qualified;
  final DynamicType? dynamic = dynamicString != null ? DynamicType.values.firstWhere((e) => e.toString() == 'DynamicType.$dynamicString') : null;
  if(dynamicsElmt != null && dynamic != null) {
    result.add(Dynamics(dynamic, parsePlacementAttr(dynamicsElmt)));
  }

  return result;
}

Tied? parseTiedXML(XmlElement tiedXML) {
  final PlacementValue? placement = parsePlacementAttr(tiedXML);

  final String? typeString = tiedXML.getAttribute('type');
  final StCtStpValue? type = typeString != null ? StCtStpValue.values.firstWhere((e) => e.toString() == 'StCtStpValue.$typeString') : null;

  final int number = int.parse(tiedXML.getAttribute('number') ?? '1');

  if(type != null) {
    return Tied(number, type, placement);
  } else {
    return null;
  }
}

Slur? parseSlurXML(XmlElement slurXML) {
  final PlacementValue? placement = parsePlacementAttr(slurXML);

  final String? typeString = slurXML.getAttribute('type');
  final StCtStpValue? type = typeString != null ? StCtStpValue.values.firstWhere((e) => e.toString() == 'StCtStpValue.$typeString') : null;

  final int number = int.parse(slurXML.getAttribute('number') ?? '1');

  if(type != null) {
    return Slur(number, type, placement);
  } else {
    return null;
  }
}



Backup? parseBackupXML(XmlElement backupXML) {
  final durationElmt = backupXML.getElement('duration');
  final int? duration = durationElmt != null ? int.parse(durationElmt.innerText) : null;
  return duration != null ? Backup(duration) : null;
}

Forward? parseForwardXML(XmlElement forwardXML) {
  final durationElmt = forwardXML.getElement('duration');
  final int? duration = durationElmt != null ? int.parse(durationElmt.innerText) : null;
  return duration != null ? Forward(duration) : null;
}