import '../graphics_model/canvas_primitives.dart'
    show Element, GlyphElement, LineElement, RectElement;

/// An independently-resolvable slot of layout output (WP3-S1).
///
/// Rules do not fight over whole elements; they contribute to **channels**, and
/// the cascade (S2) resolves conflicts **per channel**: each channel is
/// resolved independently, so a rule that loses `translate-x` to a more
/// specific rule can still win `colour` if it is the only contributor there.
///
/// Every element exposes a **common** set of channels ([CommonChannel]); the
/// primitive leaves additionally expose **per-primitive geometry** channels
/// ([LineGeometryChannel], [RectGeometryChannel]) at **whole-point**
/// granularity. See [channelsOf] for the mapping.
///
/// Each channel is tagged [ChannelClassification.continuous] (a numeric value
/// the driver writes with damping) or [ChannelClassification.discrete] (a
/// choice/styling value written directly — there is no "40% of the way from
/// flag-up to flag-down"). See `docs/wp3/README.md` — "Channels and the
/// cascade".
sealed class Channel {
  const Channel();

  /// Whether the driver damps writes to this channel (continuous) or writes
  /// the winning value directly (discrete/styling).
  ChannelClassification get classification;
}

/// Whether a channel's value is damped (continuous) or written directly
/// (discrete/styling) — the property S2's write step keys off.
enum ChannelClassification {
  /// A numeric value (a transform component or a geometry point). The driver
  /// writes `current + dampingFactor · (target − current)` — under-relaxation
  /// that kills overshoot, the leading cause of oscillation in a relaxation
  /// loop. Postconditions over continuous channels must be **ε-tolerance**-based,
  /// since damping only approaches a target asymptotically.
  continuous,

  /// A choice or styling value (`glyph-identity`, colours, staff-space stroke
  /// width). There is no meaningful interpolation between two glyphs or two
  /// colours, so the driver writes the winning value directly. (`strokeWidth`
  /// is numeric but classified discrete, because *all* `Styling` fields are
  /// written directly — damping applies to transform + geometry channels only.)
  discrete,
}

/// Channels common to (potentially) every element: the [NodeTransform]
/// components, the discrete `glyph-identity` choice, and one channel per
/// [Styling] field.
///
/// `translateX` / `translateY` are kept **separate** (not one `translate`
/// channel): "one rule owns horizontal placement, another owns vertical" is a
/// pervasive division of labour (spacing owns x, staff-position owns y), and
/// translation is always exactly two well-known axes, so the split is cheap.
///
/// `glyphIdentity` is a common-*family* channel — it is part of the common
/// vocabulary, not a primitive-geometry channel — but it is only **exposed** on
/// a [GlyphElement], since only a glyph-bearing element carries a [Glyph]
/// identity to choose (see [channelsOf]). Contributing `glyphIdentity` to a
/// non-glyph element has no target to write and is a rule bug.
class CommonChannel extends Channel {
  const CommonChannel(this.slot);

  final CommonSlot slot;

  @override
  ChannelClassification get classification => slot.classification;

  @override
  bool operator ==(Object other) =>
      other is CommonChannel && other.slot == slot;

  @override
  int get hashCode => Object.hash(CommonChannel, slot);

  // Const singletons — canonical, so identity equality also holds across them.
  static const translateX = CommonChannel(CommonSlot.translateX);
  static const translateY = CommonChannel(CommonSlot.translateY);
  static const scale = CommonChannel(CommonSlot.scale);
  static const rotation = CommonChannel(CommonSlot.rotation);
  static const glyphIdentity = CommonChannel(CommonSlot.glyphIdentity);
  static const strokeColor = CommonChannel(CommonSlot.strokeColor);
  static const fillColor = CommonChannel(CommonSlot.fillColor);
  static const strokeWidth = CommonChannel(CommonSlot.strokeWidth);
}

/// The specific common slot a [CommonChannel] represents.
enum CommonSlot {
  translateX,
  translateY,
  scale,
  rotation,
  glyphIdentity,
  strokeColor,
  fillColor,
  strokeWidth;

  /// Continuous (damped) vs discrete (written directly). See
  /// [ChannelClassification] for the rationale, in particular why
  /// [strokeWidth] is discrete despite being numeric.
  ChannelClassification get classification => switch (this) {
        translateX ||
        translateY ||
        scale ||
        rotation =>
          ChannelClassification.continuous,
        glyphIdentity ||
        strokeColor ||
        fillColor ||
        strokeWidth =>
          ChannelClassification.discrete,
      };
}

/// The primitive-specific geometry channels of a [LineElement], at
/// **whole-point** granularity (deliberately *not* split into x/y, to keep the
/// channel count in check): [LineSlot.start] and [LineSlot.end]. Both
/// continuous.
///
/// *Consequence of whole-point channels:* if two rules ever need independent
/// control of a point's x vs its y, they collide on the whole-point channel and
/// one suppresses the other entirely. That is the coupled-channels question in
/// miniature and is **deferred** — the first concrete rule that needs per-axis
/// control is the trigger to revisit (see `docs/wp3/README.md`).
class LineGeometryChannel extends Channel {
  const LineGeometryChannel(this.slot);

  final LineSlot slot;

  @override
  ChannelClassification get classification => ChannelClassification.continuous;

  @override
  bool operator ==(Object other) =>
      other is LineGeometryChannel && other.slot == slot;

  @override
  int get hashCode => Object.hash(LineGeometryChannel, slot);

  static const start = LineGeometryChannel(LineSlot.start);
  static const end = LineGeometryChannel(LineSlot.end);
}

/// The two endpoints of a [LineElement]'s segment.
enum LineSlot { start, end }

/// The primitive-specific geometry channels of a [RectElement], at
/// whole-point granularity: the two defining corners [RectSlot.northEast] and
/// [RectSlot.southWest]. Both continuous.
class RectGeometryChannel extends Channel {
  const RectGeometryChannel(this.slot);

  final RectSlot slot;

  @override
  ChannelClassification get classification => ChannelClassification.continuous;

  @override
  bool operator ==(Object other) =>
      other is RectGeometryChannel && other.slot == slot;

  @override
  int get hashCode => Object.hash(RectGeometryChannel, slot);

  static const northEast = RectGeometryChannel(RectSlot.northEast);
  static const southWest = RectGeometryChannel(RectSlot.southWest);
}

/// The two defining corners of a [RectElement].
enum RectSlot { northEast, southWest }

/// The primitive-specific geometry channels of a cubic bezier curve, at
/// whole-point granularity: its two endpoints and two control points.
///
/// **Deferred — no current IR element exposes these.** A dedicated curve
/// primitive (the leaf a slur/tie/beam edge resolves into) does not exist in
/// the IR yet: slurs/ties/beams are [CrossReferenceElement]s whose resolution
/// math is WP6, and today they resolve to [LineElement] / [PathElement] leaves.
/// Per the no-speculation principle this channel family is declared here — it
/// is part of the intended channel vocabulary the design pins — but it is
/// **not** wired by [channelsOf] until WP6 introduces the curve primitive and
/// its channels together.
///
/// (A [PathElement] holds an opaque Flutter `Path` whose individual control
/// points are not addressable, so it exposes no geometry channels — only the
/// common channels.)
class CurveGeometryChannel extends Channel {
  const CurveGeometryChannel(this.slot);

  final CurveSlot slot;

  @override
  ChannelClassification get classification => ChannelClassification.continuous;

  @override
  bool operator ==(Object other) =>
      other is CurveGeometryChannel && other.slot == slot;

  @override
  int get hashCode => Object.hash(CurveGeometryChannel, slot);

  static const start = CurveGeometryChannel(CurveSlot.start);
  static const end = CurveGeometryChannel(CurveSlot.end);
  static const controlPoint1 = CurveGeometryChannel(CurveSlot.controlPoint1);
  static const controlPoint2 = CurveGeometryChannel(CurveSlot.controlPoint2);
}

/// The whole-points of a cubic bezier curve.
enum CurveSlot { start, end, controlPoint1, controlPoint2 }

/// The channels [element] exposes — the common channels every element carries,
/// plus the primitive-specific geometry channels of a leaf.
///
/// - **Every element:** the four transform channels ([CommonChannel.translateX],
///   [translateY], [scale], [rotation]) and the three `Styling` channels
///   ([strokeColor], [fillColor], [strokeWidth]).
/// - **A [GlyphElement]:** additionally [CommonChannel.glyphIdentity].
/// - **A [LineElement]:** additionally [LineGeometryChannel.start] / [.end].
/// - **A [RectElement]:** additionally [RectGeometryChannel.northEast] /
///   [.southWest].
/// - Curve/bezier geometry channels are deferred until a curve primitive is
///   introduced (WP6); no current element exposes them.
///
/// This is the concrete mapping that makes "per-primitive geometry channels at
/// whole-point granularity" testable, and the one the driver consults to know
/// which channels a given element can be contributed to.
Set<Channel> channelsOf(Element element) {
  final channels = <Channel>{
    CommonChannel.translateX,
    CommonChannel.translateY,
    CommonChannel.scale,
    CommonChannel.rotation,
    CommonChannel.strokeColor,
    CommonChannel.fillColor,
    CommonChannel.strokeWidth,
  };
  switch (element) {
    case GlyphElement():
      channels.add(CommonChannel.glyphIdentity);
    case LineElement():
      channels.addAll(const [LineGeometryChannel.start, LineGeometryChannel.end]);
    case RectElement():
      channels.addAll(
          const [RectGeometryChannel.northEast, RectGeometryChannel.southWest]);
    case _:
      // A composing node (GroupElement / CompositeElement) or a PathElement:
      // common channels only — no primitive-specific geometry to expose.
      break;
  }
  return channels;
}
