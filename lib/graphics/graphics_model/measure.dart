import 'dart:ui' show Rect;

/// Legacy render-layer geometry typedefs (WP1-S3).
///
/// The semantic `MeasureElement` / column nodes that previously lived here
/// have moved to the deliberate layer-2 taxonomy under
/// `lib/graphics/graphics_model/semantic/structural.dart`. This file now holds
/// only the render-layer geometry typedefs that the legacy single-pass
/// renderer (`render/measure.dart`, `render/drawing_context.dart`) still
/// consumes. They will be removed when the render phase becomes a pure
/// tree-walker (WP2) and the multi-staff fixture (S7) replaces these ad-hoc
/// records; until then they are kept here so the legacy path keeps compiling.

/// Geometry of a measure's attribute column, as computed by the legacy
/// renderer.
typedef MeasureAttributesGeometry = ({Rect boundingBox});

/// Geometry of a whole measure, as computed by the legacy renderer.
typedef MeasureGeometry = ({
  Rect boundingBox,
  List<Rect> staveBoundingBoxes,
  MeasureAttributesGeometry? attributesGeometry
});
