// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
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
}
