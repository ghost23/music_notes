/// The single render scaling measure: **pixels per staff space**.
///
/// The IR carries only staff-space units (1 staff space is the SMUFL native
/// unit; 1 em = 4 staff spaces = 1 staff height) and stores no pixel values.
/// The renderer supplies exactly this one scale and derives every pixel value
/// from it. Changing zoom or output size is a matter of passing a different
/// [RenderScale]; it never re-runs layout. This is the boundary the resolved
/// "Coordinate system" decision (`docs/rewrite-plan.md`) reserves as the
/// renderer's **only** own numeric contribution.
///
/// ## The em relationship (stated once)
///
/// 1 em = **4** staff spaces = 1 staff height, so a glyph at 1 em has a
/// staff-space font size of [staffSpacesPerEm]. The "× 4" em factor lives
/// here, exactly once.
///
/// ## Unit-conversion strategy: scale-the-canvas-once
///
/// The renderer applies [pixelsPerStaffSpace] as a single root
/// `canvas.scale(...)` and then walks the tree in **staff-space units**:
/// translations, leaf geometry, stroke widths and the glyph em font size are
/// all staff-space, and the root scale turns them into pixels in one place.
/// This keeps the tree-walker unit-agnostic — a cleaner fit for the "pure
/// tree-walker" goal of WP2.
///
/// The alternative — per-leaf multiplication by the measure (`strokeWidth ×
/// scale`, font size `4 × scale`, translation `× scale`, and the same for
/// every `Rect`/`Path`/line endpoint) — yields identical pixels but
/// re-introduces pixel arithmetic at every leaf (most awkwardly for `Path`
/// geometry). It was rejected here mainly for that reason. The one caveat with
/// scaling the canvas — glyph rasterisation under a large canvas scale — is
/// judged non-blocking for the vector (OpenType) SMUFL font: the outlines
/// scale crisply. Should glyph quality degrade in practice, the localized fix
/// is to render each glyph at [pixelEmFontSize] with the canvas scale reset
/// around it, without changing this measure's definition.
///
/// ## Validation
///
/// A non-positive or NaN measure is a programmer error: the constructor
/// throws, consistent with `NodeTransform`'s NaN guard
/// (`graphics_model/transform.dart`).
///
/// ## Per-node scale is a different concept
///
/// The per-node `scale` in `NodeTransform` is a *layout* quantity (a scaled
/// glyph, a squashed beam): it is unitless and composes within the tree in
/// staff-space. [RenderScale] is the single global staff-space→pixel factor
/// applied once at the render boundary. The two are kept distinct in naming.
class RenderScale {
  /// Pixels per staff space — the single staff-space→pixel factor.
  final double pixelsPerStaffSpace;

  /// One em, expressed in staff spaces: `1 em = 4 staff spaces = 1 staff
  /// height`. The "× 4" em factor lives here, exactly once.
  static const int staffSpacesPerEm = 4;

  /// Constructs the render scaling measure.
  ///
  /// Throws [ArgumentError] if [pixelsPerStaffSpace] is NaN or non-positive —
  /// a render scale has no meaningful zero or negative value.
  RenderScale(this.pixelsPerStaffSpace) {
    if (pixelsPerStaffSpace.isNaN || pixelsPerStaffSpace <= 0) {
      throw ArgumentError(
        'RenderScale.pixelsPerStaffSpace must be positive and not NaN; '
        'got $pixelsPerStaffSpace.',
      );
    }
  }

  /// Converts a staff-space length to pixels.
  ///
  /// This is the staff-space→pixel conversion. Under the scale-the-canvas-once
  /// strategy the renderer applies it once as a root canvas scale, so leaves do
  /// not call it per element; it is exposed for documentation and unit testing.
  double toPixels(double staffSpaces) => staffSpaces * pixelsPerStaffSpace;

  /// The pixel font size of a glyph at 1 em: `staffSpacesPerEm ×
  /// pixelsPerStaffSpace`. Under the scale-the-canvas-once strategy the glyph
  /// is drawn at the staff-space em size [staffSpacesPerEm] and the canvas
  /// scale produces this pixel value; exposed for documentation and testing.
  double get pixelEmFontSize => staffSpacesPerEm * pixelsPerStaffSpace;

  /// Returns a copy with [pixelsPerStaffSpace] replaced.
  RenderScale copyWith({double? pixelsPerStaffSpace}) =>
      RenderScale(pixelsPerStaffSpace ?? this.pixelsPerStaffSpace);
}
