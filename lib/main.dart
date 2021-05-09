import 'package:flutter/material.dart';
import 'package:music_notes_2/notes/notes.dart';
import 'notes/music-line.dart';

const double FONT_SIZE = 72;

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
  MyHomePage({Key key}) : super(key: key);

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
          child: MusicLine(fontSize: FONT_SIZE, staffs: [Clefs.g, Clefs.f],)
        ),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}