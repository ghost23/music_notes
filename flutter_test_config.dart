import 'dart:async';
import 'dart:io' show File;
import 'dart:typed_data' show ByteData;

import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart' show TestWidgetsFlutterBinding;

/// Test bootstrap (WP2-S5): loads the Bravura SMUFL font (and BravuraText) into
/// the test font registry so that glyph goldens rasterise as **real glyphs**,
/// not missing-glyph boxes.
///
/// Runs once before the whole suite. The fonts are declared as app fonts in
/// `pubspec.yaml` (`fonts/Bravura.otf`, `fonts/BravuraText.otf`); here we read
/// them from disk and register them with the test binding's font registry.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  await _loadFont(family: 'Bravura', path: 'fonts/Bravura.otf');
  await _loadFont(family: 'BravuraText', path: 'fonts/BravuraText.otf');

  await testMain();
}

Future<void> _loadFont({required String family, required String path}) async {
  final bytes = await File(path).readAsBytes();
  final loader = FontLoader(family);
  loader.addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}
