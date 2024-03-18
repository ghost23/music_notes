import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:xml/xml.dart';

import 'graphics/music_line.dart';
import 'musicXML/data.dart';
import 'musicXML/parser.dart';

Future<Score> loadXML() async {
  final rawFile = await rootBundle.loadString('hanon-no1-stripped.musicxml');
  final result = parseMusicXML(XmlDocument.parse(rawFile));
  return result;
}

const double staffHeight = 36;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music Notes 2',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  MyHomePageState createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Center(
        child: Container(
            alignment: Alignment.center,
            width: size.width - 40,
            height: size.height - 40,
            child: FutureBuilder<Score>(
                future: loadXML(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return MusicLine(
                      options: MusicLineOptions(
                        snapshot.data!,
                        staffHeight,
                        1,
                      ),
                    );
                  } else if (snapshot.hasError) {
                    return Text('Oh, this failed!\n${snapshot.error}');
                  } else {
                    return const SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(),
                    );
                  }
                })),
      ),
    );
  }
}
