import 'dart:io' show File;
import 'dart:ui' show ImageByteFormat, Offset, instantiateImageCodec;

import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:music_notes_2/graphics/graphics_model/canvas_primitives.dart'
    show GroupElement;
import 'package:music_notes_2/graphics/graphics_model/transform.dart'
    show NodeTransform;
import 'package:music_notes_2/graphics/layout/geometry.dart'
    show absoluteBoundingBox;
import 'package:music_notes_2/graphics/render/render_scale.dart'
    show RenderScale;
import 'package:music_notes_2/graphics/wp1_contract_fixture.dart';

import 'golden_harness.dart';

/// The first golden of the new render pipeline (WP2-S5).
///
/// Renders the shared WP1 contract fixture (its deferred staff lines resolved
/// first, per S3/S4) through the S4 painter / S3 tree-walker and locks the
/// output behind `matchesGoldenFile`, so a later layout-rule refinement cannot
/// silently regress an already-correct render. Later work packages add their
/// own goldens using the same harness — only reference images are added.
///
/// ## Fixed inputs (documented for determinism)
///
/// - scale: `9` pixels per staff space (the legacy app's `staffHeight = 36`).
/// - framing: the fixture's absolute bounding box, with a `12` px margin.
/// - background: white (see [renderTreeToImage]).
void main() {
  /// The render scaling measure for the goldens.
  final renderScale = RenderScale(9);

  /// Device-pixel margin around the fixture in the golden.
  const margin = 12.0;

  /// Builds the fixture with its deferred staff lines already resolved.
  Wp1ContractFixture resolvedFixture() {
    final fixture = buildWp1ContractFixture();
    resolveAllStaffLines(fixture);
    return fixture;
  }

  /// Frames the fixture's bounding box with [margin] at [renderScale]:
  /// (image size, viewport origin mapping staff-space (0,0) onto the image).
  ({Size size, Offset viewportOrigin}) framingFor(double systemLeftStaffSpace,
      double systemTopStaffSpace, double systemWidth, double systemHeight) {
    final pixelsPerStaffSpace = renderScale.pixelsPerStaffSpace;
    final size = Size(
      systemWidth * pixelsPerStaffSpace + 2 * margin,
      systemHeight * pixelsPerStaffSpace + 2 * margin,
    );
    final viewportOrigin = Offset(
      margin - systemLeftStaffSpace * pixelsPerStaffSpace,
      margin - systemTopStaffSpace * pixelsPerStaffSpace,
    );
    return (size: size, viewportOrigin: viewportOrigin);
  }

  test('the WP1 contract fixture matches its golden', () async {
    final fixture = resolvedFixture();
    final bbox = absoluteBoundingBox(fixture.system);
    final framing = framingFor(bbox.left, bbox.top, bbox.width, bbox.height);

    await expectTreeMatchesGolden(
      fixture.system,
      renderScale: renderScale,
      size: framing.size,
      viewportOrigin: framing.viewportOrigin,
      goldenKey: 'wp1_contract_fixture.png',
    );
  });

  test('the golden would fail on an intentional perturbation (sanity)', () async {
    // `matchesGoldenFile` is an async matcher, so it cannot be wrapped in
    // `isNot` to assert a *non*-match. Instead we prove the comparator is
    // meaningful the other way round: a visibly perturbed render must differ
    // in pixels from the committed golden reference — so the golden test
    // would fail on this perturbation. We confirm by decoding the committed
    // golden PNG and diffing its raw RGBA against the perturbed render.
    final fixture = resolvedFixture();
    final bbox = absoluteBoundingBox(fixture.system);
    final framing = framingFor(bbox.left, bbox.top, bbox.width, bbox.height);
    final perturbedRoot = GroupElement(
      const NodeTransform(translation: Offset(3, 3)), // 3 staff spaces = 27 px
      [fixture.system],
    );
    final perturbed = await renderTreeToImage(
      perturbedRoot,
      renderScale: renderScale,
      size: framing.size,
      viewportOrigin: framing.viewportOrigin,
    );

    final goldenBytes =
        await File('test/goldens/wp1_contract_fixture.png').readAsBytes();
    final codec = await instantiateImageCodec(goldenBytes);
    final golden = (await codec.getNextFrame()).image;
    final perturbedRgba =
        (await perturbed.toByteData(format: ImageByteFormat.rawRgba))!;
    final goldenRgba =
        (await golden.toByteData(format: ImageByteFormat.rawRgba))!;

    expect(perturbedRgba.lengthInBytes, goldenRgba.lengthInBytes);
    var differingBytes = 0;
    for (var index = 0; index < perturbedRgba.lengthInBytes; index += 1) {
      if (perturbedRgba.getUint8(index) != goldenRgba.getUint8(index)) {
        differingBytes += 1;
      }
    }
    expect(
      differingBytes,
      greaterThan(0),
      reason: 'a perturbed render must differ from the committed golden',
    );
  });
}
