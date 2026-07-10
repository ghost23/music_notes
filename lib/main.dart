import 'package:flutter/material.dart';

/// Minimal placeholder entry point.
///
/// The legacy single-pass renderer (`MusicLine`) was removed in WP2-S1. The new
/// layout→render pipeline is not wired up yet: WP2-S4 will replace this
/// placeholder with a `CustomPainter` that renders the WP1 S7 contract fixture
/// through the pure tree-walker, and WP3 will later feed real parsed scores.
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

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Layout engine not wired yet.'),
      ),
    );
  }
}
