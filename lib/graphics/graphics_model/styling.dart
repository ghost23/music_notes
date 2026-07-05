import 'dart:ui' show Color;

/// Scale-free presentational styling carried by an IR element (WP1-S2).
///
/// The layout model deliberately separates two things that "styling"
/// conflates:
/// - **pixel-bearing / scale-dependent render data** (pixel font sizes, pixel
///   stroke widths, Flutter's `Paint`/`TextStyle`) — does **not** belong in the
///   IR; it depends on the render scaling measure and is a render-phase
///   concern;
/// - **scale-free presentational styling** (stroke/fill **color**, staff-space
///   stroke thickness) — **does** belong in the IR. It carries no pixel units,
///   does not depend on the scaling measure, and is a genuine layout-time
///   decision (e.g. an editorially red note, a greyed-out cue, a highlighted
///   symbol).
///
/// [Styling] captures only the latter:
/// - [strokeColor] / [fillColor] are plain ARGB [Color] values — no pixel
///   units. We reuse Flutter's [Color] ("reuse first") rather than introduce a
///   custom color type; the only constraint is that no `Paint` is constructed
///   inside the model. The renderer builds the `Paint`.
/// - [strokeWidth] is a stroke thickness in **staff-space units** (sourced
///   from `EngravingDefaults` where applicable), never in pixels.
///
/// ## Fill-vs-stroke intent is derived from color presence
///
/// There is no separate intent enum: which colors are set *is* the intent.
///
/// | [strokeColor] | [fillColor] | intent |
/// |---|---|---|
/// | set | null | stroke |
/// | null | set | fill |
/// | set | set | stroke + fill |
/// | null | null | unresolved (see below) |
///
/// Use [hasStroke] / [hasFill] to read the derived intent.
///
/// ## The renderer has no styling defaults
///
/// **The layout phase is the sole source of styling.** The renderer draws
/// exactly what it is given and **throws** if a required scale-free property is
/// missing (no color set, or a stroke without a [strokeWidth]). It never
/// invents a default color or thickness.
///
/// "Unset" ([Styling.inherit] / a `null` field) therefore does **not** mean
/// "fall back to a renderer default". It means *unresolved*: the layout must
/// resolve it before the renderer sees it — by inheriting from the parent in
/// the scene-graph cascade, or by applying a **default style defined in the IR
/// element definition** (e.g. a notehead's default fill). Such default styles
/// are defined in the element definitions, which are introduced in later work
/// packages; they are layout-time defaults, never render-time ones.
///
/// ## Boundary with the renderer
///
/// The **renderer** (WP2) turns the resolved [Styling] + the single render
/// scaling measure into a concrete Flutter `Paint`/`TextStyle`: it converts a
/// staff-space [strokeWidth] to pixels (`strokeWidth × scale`), and a glyph's
/// size from staff-space to a pixel font size (`4 × scale`, since 1 em = 4
/// staff spaces). Those *scale-dependent pixel* values are a render concern;
/// the *scale-free* values ([Color], [strokeWidth]) come from the IR. No
/// `Paint` or `TextStyle` is ever constructed inside the model layer.
class Styling {
  const Styling({
    this.strokeColor,
    this.fillColor,
    this.strokeWidth,
  });

  /// Fully unspecified styling — i.e. *unresolved*.
  ///
  /// This is the default carried by an element that has not been styled at
  /// layout time. It is **not** a renderer default: if a [Styling.inherit]
  /// reaches the renderer, the layout has failed to resolve it and the
  /// renderer throws. Default styles, when wanted, are defined in the IR
  /// element definitions and applied during layout.
  static const Styling inherit = Styling();

  /// Stroke color. When set, the element is stroked (see [hasStroke]).
  final Color? strokeColor;

  /// Fill color. When set, the element is filled (see [hasFill]).
  final Color? fillColor;

  /// Stroke thickness in **staff-space units** (1 staff space = the SMUFL
  /// unit; 4 staff spaces = 1 em). Sourced from `EngravingDefaults` where
  /// applicable. Required when [strokeColor] is set (the renderer throws on a
  /// stroke without a width); irrelevant for a pure fill. Never in pixels.
  final double? strokeWidth;

  /// `true` when no scale-free property is set (everything unresolved).
  bool get isInherit =>
      strokeColor == null && fillColor == null && strokeWidth == null;

  /// `true` when this styling requests a stroke ([strokeColor] set).
  bool get hasStroke => strokeColor != null;

  /// `true` when this styling requests a fill ([fillColor] set).
  bool get hasFill => fillColor != null;

  /// Returns a copy with the given fields replaced.
  ///
  /// Because every field is nullable and uses `??` fallback, a field can only
  /// be set or kept — not reset to `null` — through `copyWith`. Construct a
  /// fresh [Styling] (or [Styling.inherit]) to clear everything.
  Styling copyWith({
    Color? strokeColor,
    Color? fillColor,
    double? strokeWidth,
  }) =>
      Styling(
        strokeColor: strokeColor ?? this.strokeColor,
        fillColor: fillColor ?? this.fillColor,
        strokeWidth: strokeWidth ?? this.strokeWidth,
      );
}
