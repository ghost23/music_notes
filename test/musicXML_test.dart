// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

// ignore_for_file: file_names

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:music_notes_2/graphics/music_line.dart';
import 'package:music_notes_2/musicXML/data.dart';
import 'package:music_notes_2/musicXML/parser.dart';
import 'package:xml/xml.dart';

void main() {
  test('musicXML parser', () {
    final XmlDocument document = loadMusicXMLFile('./hanon-no1-stripped.musicxml');
    final Score score = parseMusicXML(document);

    expect(score.parts, hasLength(equals(1)));

    final Part firstPart = score.parts.first;

    expect(firstPart.measures, hasLength(equals(3)));

    final Measure firstMeasure = firstPart.measures.first;
    final Attributes attributes = firstMeasure.contents.whereType<Attributes>().first;

    expect(attributes.staves, equals(2));
    expect(attributes.time!.beats, equals(2));
  });

  testGoldens('A simple first golden test', (tester) async {
    final Score score = Score([
      Part([
        Measure([
          Attributes(1, MusicalKey(CircleOfFifths.C_A.v, KeyMode.major), 1, [Clef(1, Clefs.G)], Time(4, 4)),
          PitchNote(1, 1, 1, [], Pitch(BaseTones.C, 2), NoteLength.quarter, StemValue.up, []),
          PitchNote(1, 1, 1, [], Pitch(BaseTones.D, 2), NoteLength.quarter, StemValue.up, []),
          PitchNote(1, 1, 1, [], Pitch(BaseTones.E, 2), NoteLength.quarter, StemValue.up, []),
          PitchNote(1, 1, 1, [], Pitch(BaseTones.F, 2), NoteLength.quarter, StemValue.up, []),
        ])
      ])
    ]);

    final builder = GoldenBuilder.column()
      ..addScenario(
          'demo',
          SizedBox(
              width: 500,
              height: 240,
              child: MusicLine(
                options: MusicLineOptions(
                  score,
                  36,
                  1,
                ),
              )));

    await tester.pumpWidgetBuilder(builder.build(), surfaceSize: const Size(500, 300));

    await screenMatchesGolden(tester, 'main_demo');
  });
}
