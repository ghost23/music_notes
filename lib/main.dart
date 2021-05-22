import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:xml/xml.dart';
import 'musicXML/data.dart';
import 'notes/music-line.dart';

Future<XmlDocument> loadXML() async {
  final rawFile = await rootBundle.loadString('assets/hanon-no1-stripped.musicxml');
  return XmlDocument.parse(rawFile);
}

const double STAFF_HEIGHT = 72;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music Notes 2',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: Center(
        child: Container(
          alignment: Alignment.center,
          width: 600,
          height: 500,
          child: MusicLine(options: MusicLineOptions(STAFF_HEIGHT, STAFF_HEIGHT), staffs: [Clefs.G, Clefs.F],)
        ),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}