import 'dart:ui' show Canvas, Image, ImageByteFormat, PictureRecorder;

import 'package:flutter/widgets.dart' show CustomPaint, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:music_notes_2/main.dart' show MyApp;
import 'package:music_notes_2/graphics/layout/geometry.dart'
    show absoluteBoundingBox;
import 'package:music_notes_2/graphics/render/ir_tree_painter.dart';
import 'package:music_notes_2/graphics/render/render_scale.dart';
import 'package:music_notes_2/graphics/wp1_contract_fixture.dart';

/// End-to-end render proof for WP2-S4.
///
/// Renders the shared WP1 contract fixture (its deferred staff lines resolved
/// first, as the real pipeline will) through the [IRTreePainter] / S3
/// tree-walker onto a recording canvas, and asserts:
/// - the paint completes without throwing — proving no unresolved node, no
///   missing styling, and no contract violation reaches the canvas; and
/// - the rasterised output is non-empty — proving it actually draws something.
///
/// It imports the shared [buildWp1ContractFixture] rather than duplicating a
/// hand-built tree, so WP2's render test and WP1's geometry tests assert
/// against the same example.
void main() {
  /// Builds the fixture with its deferred staff lines already resolved.
  Wp1ContractFixture resolvedFixture() {
    final fixture = buildWp1ContractFixture();
    resolveAllStaffLines(fixture);
    return fixture;
  }

  final renderScale = RenderScale(9);

  test('the resolved fixture renders through the painter without throwing', () {
    final fixture = resolvedFixture();
    final painter =
        IRTreePainter(root: fixture.system, renderScale: renderScale);

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    // The painter draws the tree at the canvas origin; size only affects the
    // painter's hint footprint, not what it draws.
    expect(() => painter.paint(canvas, const Size(400, 300)), returnsNormally);
  });

  test('the rendered fixture produces non-empty output', () async {
    final fixture = resolvedFixture();
    final painter =
        IRTreePainter(root: fixture.system, renderScale: renderScale);

    // Bring the fixture's bounding box (which extends to negative y — clefs
    // above the staff origin) fully into frame, then rasterise.
    final bbox = absoluteBoundingBox(fixture.system);
    final pixelsPerStaffSpace = renderScale.pixelsPerStaffSpace;
    final width = (bbox.width * pixelsPerStaffSpace).ceil();
    final height = (bbox.height * pixelsPerStaffSpace).ceil();

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder)
      ..translate(
        -bbox.left * pixelsPerStaffSpace,
        -bbox.top * pixelsPerStaffSpace,
      );
    painter.paint(canvas, Size(width.toDouble(), height.toDouble()));

    final image = await recorder.endRecording().toImage(width, height);
    expect(await hasNonTransparentPixel(image), isTrue,
        reason: 'the rendered fixture should draw at least one pixel');
  });

  testWidgets('the app widget builds and paints the fixture without error',
      (tester) async {
    await tester.pumpWidget(const MyApp());
    // Pumping built and painted the fixture through the [IRTreePainter] that
    // [MyApp] installs; reaching this point without throwing means the whole
    // main.dart path (fixture build → slur resolve → viewport offset → paint)
    // is sound. (Material also uses a CustomPaint internally, so match by
    // painter type, not just CustomPaint.)
    expect(
      find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is IRTreePainter,
      ),
      findsOneWidget,
    );
  });
}

/// Scans [image] for any non-fully-transparent pixel (alpha > 0).
Future<bool> hasNonTransparentPixel(Image image) async {
  final bytes = await image.toByteData(format: ImageByteFormat.rawRgba);
  if (bytes == null) return false;
  final rgba = bytes.buffer.asUint8List();
  for (var index = 3; index < rgba.length; index += 4) {
    if (rgba[index] != 0) return true;
  }
  return false;
}
