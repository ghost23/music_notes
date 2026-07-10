import 'package:flutter/material.dart';

import '/graphics/layout/geometry.dart' show absoluteBoundingBox;
import '/graphics/render/ir_tree_painter.dart';
import '/graphics/render/render_scale.dart';
import '/graphics/wp1_contract_fixture.dart';

/// The render scaling measure for the app: **9 pixels per staff space**.
///
/// The legacy single-pass renderer used a staff height of 36 px = 4 staff
/// spaces, i.e. 9 px per staff space. We keep that value so the on-screen size
/// matches the old app; the renderer itself stays parameterised (WP2-S2).
final RenderScale renderScale = RenderScale(9);

/// Device-pixel margin around the drawn fixture.
const double margin = 12;

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

/// Displays the WP1 S7 contract fixture through the WP2 tree-walker.
///
/// This is a stand-in until the WP3 layout engine builds the IR from a real
/// parsed `Score` (see `docs/wp2/S4-entry-point-and-e2e.md`): the app currently
/// shows the hand-built fixture that WP2's render test and WP1's geometry
/// tests assert against — the single shared example.
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final Wp1ContractFixture fixture;

  @override
  void initState() {
    super.initState();
    fixture = buildWp1ContractFixture();
    // Resolve the deferred staff lines *before* rendering: the S3 walker refuses
    // unresolved nodes (WP1-S5). Staff-line length is content-driven, so it is
    // resolved once the content width is known — the real pipeline order is
    // WP3 resolves, then the renderer draws.
    resolveAllStaffLines(fixture);
  }

  @override
  Widget build(BuildContext context) {
    final bbox = absoluteBoundingBox(fixture.system);
    final pixelsPerStaffSpace = renderScale.pixelsPerStaffSpace;
    final contentWidth = bbox.width * pixelsPerStaffSpace;
    final contentHeight = bbox.height * pixelsPerStaffSpace;

    // The fixture's staff-space origin (system at (0,0)) has content extending
    // into negative y (clefs above the staff top line), so place the scene's
    // bounding-box top-left at [margin, margin] of the viewport. This is a
    // call-site viewport offset, not renderer logic — the painter stays a pure
    // function of (root, scale).
    final viewportOffset = Offset(
      margin - bbox.left * pixelsPerStaffSpace,
      margin - bbox.top * pixelsPerStaffSpace,
    );

    return Scaffold(
      body: Center(
        child: Transform.translate(
          offset: viewportOffset,
          child: CustomPaint(
            size: Size(contentWidth, contentHeight),
            painter: IRTreePainter(
              root: fixture.system,
              renderScale: renderScale,
            ),
          ),
        ),
      ),
    );
  }
}
