import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:xml/xml.dart';
import 'musicXML/data.dart';
import 'musicXML/parser.dart';
import 'notes/music-line.dart';

Future<Score> loadXML() async {
  final rawFile = await rootBundle.loadString('hanon-no1-stripped.musicxml');
  return parseMusicXML(XmlDocument.parse(rawFile));
}

const double STAFF_HEIGHT = 36;

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
                if(snapshot.hasData) {
                  return MusicLine(
                    options: MusicLineOptions(
                      snapshot.data!,
                      STAFF_HEIGHT,
                      1,
                    ),
                  );
                } else if(snapshot.hasError) {
                  return Text('Oh, this failed!\n${snapshot.error}');
                } else {
                  return  SizedBox(
                    child: CircularProgressIndicator(),
                    width: 60,
                    height: 60,
                  );
                }
              }
          )
        ),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}