import 'package:flutter/widgets.dart' hide Element;

import '/graphics/graphics_model/canvas_primitives.dart';
import '/graphics/render/draw_primitives.dart';
import '/graphics/render/render_scale.dart';

/// Minimal `CustomPainter` that renders an IR [Element] tree at a given
/// [RenderScale] by delegating to the WP2-S3 tree-walker ([drawElement]).
///
/// This is the thinnest possible bridge from an `Element` tree + the single
/// render scaling measure to `CustomPainter.paint`: it performs **no** layout,
/// measurement, positioning or styling — everything it draws is already on the
/// tree (WP2-S3) and the scale converts staff-space to pixels (WP2-S2). The
/// painter owns no state of its own; it is a pure function of [root] and
/// [renderScale], so the WP2-S5 golden harness can drive it directly and the
/// WP7-era widget layer can wrap or replace it without touching the render
/// core.
///
/// The deferred elements of [root] must be **resolved** before painting (the
/// S3 walker refuses unresolved nodes — see WP1-S5); resolution is the layout
/// phase's job (WP3/WP6), not the painter's.
class IRTreePainter extends CustomPainter {
  IRTreePainter({required this.root, required this.renderScale});

  /// The IR scene-graph root to render.
  final Element root;

  /// The single render scaling measure (pixels per staff space) handed to the
  /// tree-walker. See [RenderScale].
  final RenderScale renderScale;

  @override
  void paint(Canvas canvas, Size size) =>
      drawElement(canvas, root, renderScale);

  @override
  bool shouldRepaint(covariant IRTreePainter oldDelegate) =>
      !identical(root, oldDelegate.root) ||
      renderScale.pixelsPerStaffSpace != oldDelegate.renderScale.pixelsPerStaffSpace;
}
