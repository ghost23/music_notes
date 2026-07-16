import 'dart:ui' show Color, Offset;

import 'package:music_notes_2/graphics/generated/glyph_definitions.dart'
    show Glyph;
import 'package:music_notes_2/graphics/graphics_model/canvas_primitives.dart'
    show Element;

import 'channel.dart'
    show
        Channel,
        CommonChannel,
        LineGeometryChannel,
        RectGeometryChannel;

/// A complete, standalone layout **target** for one channel of one element
/// (WP3-S1) — the value kind a [Contribution] carries.
///
/// A rule expresses the value a channel *should have*, never a delta/increment
/// (the design's "Targets, not deltas" decision). The type enforces this:
/// there is **no delta variant** here, so an order-dependent increment is
/// *unrepresentable*. Every [TargetValue] is a complete answer the cascade
/// (S2) can select or discard order-independently.
///
/// ## Local frame
///
/// A target is expressed in the target element's **local (parent-relative)**
/// frame — the rule author never writes global coordinates. The driver (S4)
/// owns local→global composition. A rule declares local *intent* ("clear the
/// preceding dot by 0.2sp"); a driver primitive turns that into a concrete
/// local value.
///
/// ## Why a sealed sum (and four kinds)
///
/// Channels carry values of different Dart types — a translation component is
/// a `double`, a geometry point is an `Offset`, a colour is a `Color`, a glyph
/// choice is a `Glyph`. Rather than boxing everything as `Object`/`dynamic`
/// (which loses the channel↔value-kind correspondence at compile time), the
/// value is a small sealed sum, and the [Contribution] typed factories pair each
/// channel with its one correct kind — so a `translate-x` contribution cannot
/// accidentally carry a `Color`.
///
/// Accumulation *where it is correct domain behaviour* (stacking accidentals)
/// is **one rule** reading all participants and computing each one's local
/// target — explicit and centralized — not the cascade summing blind deltas.
sealed class TargetValue {
  const TargetValue();
}

/// A scalar numeric target (a `double`): for `translate-x`, `translate-y`,
/// `rotation`, and `stroke-width`.
class ScalarTarget extends TargetValue {
  const ScalarTarget(this.value);
  final double value;

  @override
  bool operator ==(Object other) =>
      other is ScalarTarget && other.value == value;

  @override
  int get hashCode => Object.hash(ScalarTarget, value);

  @override
  String toString() => 'ScalarTarget($value)';
}

/// A whole-point target (an [Offset]): for `scale` (per-axis) and the
/// primitive geometry channels (line `start`/`end`, rect corners).
///
/// Geometry channels are at **whole-point** granularity (see
/// [RectGeometryChannel] / [LineGeometryChannel]): the x and y of one point are
/// a single target, so the rule states the complete point it wants.
class OffsetTarget extends TargetValue {
  const OffsetTarget(this.value);
  final Offset value;

  @override
  bool operator ==(Object other) =>
      other is OffsetTarget && other.value == value;

  @override
  int get hashCode => Object.hash(OffsetTarget, value);

  @override
  String toString() => 'OffsetTarget($value)';
}

/// A colour target: for `stroke-color` and `fill-color` (`Styling` fields).
class ColorTarget extends TargetValue {
  const ColorTarget(this.value);
  final Color value;

  @override
  bool operator ==(Object other) =>
      other is ColorTarget && other.value == value;

  @override
  int get hashCode => Object.hash(ColorTarget, value);

  @override
  String toString() => 'ColorTarget($value)';
}

/// A discrete glyph-identity choice (a `Glyph`): for `glyph-identity`
/// (flag-up vs flag-down, etc.). No target *math* — just a winning choice.
class GlyphTarget extends TargetValue {
  const GlyphTarget(this.value);
  final Glyph value;

  @override
  bool operator ==(Object other) =>
      other is GlyphTarget && other.value == value;

  @override
  int get hashCode => Object.hash(GlyphTarget, value);

  @override
  String toString() => 'GlyphTarget($value)';
}

/// A single `(target element, channel, target)` declaration a rule emits in its
/// `apply` (WP3-S1).
///
/// Rules are **declarative**: `apply` returns a list of these rather than
/// mutating nodes. The driver (S2) collects contributions across all rules,
/// resolves each channel by the cascade, and writes the winners. A rule
/// declares *what value a channel should have* for a specific element; it never
/// touches the tree itself and holds no reference that could.
///
/// Each [Contribution] targets **one element's one channel** with a complete
/// [TargetValue] in the target's **local frame**. A rule's [Scope](../rule.dart)
/// may span several elements (a beam and its stems, a notehead and its
/// preceding dot); the rule emits one [Contribution] per (element, channel) it
/// wants to move. The contribution's [target] must be one of the scope's
/// elements (the driver checks this), so a rule cannot reach outside its scope.
///
/// Use the typed factories ([Contribution.translateX], [Contribution.lineStart],
/// …) rather than the raw constructor: they pair each channel with its correct
/// [TargetValue] kind, so a channel/value mismatch fails loudly instead of
/// silently surfacing as a wrong write in the cascade.
class Contribution {
  /// Creates a contribution with a raw [value]. Prefer the typed factories; use
  /// this only when constructing one from data whose channel/value pairing is
  /// already validated.
  const Contribution(this.target, this.channel, this.value);

  /// The element this contribution targets (by identity — the driver writes
  /// its channel in place, never replacing the node).
  final Element target;

  /// The channel being contributed to.
  final Channel channel;

  /// The complete local-frame target value. Never a delta.
  final TargetValue value;

  // ---- Common transform channels (continuous) ----

  /// Contribute the local `translate-x` (a scalar, in staff-space units).
  static Contribution translateX(Element target, double value) =>
      Contribution(target, CommonChannel.translateX, ScalarTarget(value));

  /// Contribute the local `translate-y` (a scalar, in staff-space units).
  static Contribution translateY(Element target, double value) =>
      Contribution(target, CommonChannel.translateY, ScalarTarget(value));

  /// Contribute the local per-axis `scale` (an [Offset]: `(sx, sy)`).
  static Contribution scale(Element target, Offset value) =>
      Contribution(target, CommonChannel.scale, OffsetTarget(value));

  /// Contribute the local `rotation` (a scalar, radians, clockwise positive).
  static Contribution rotation(Element target, double value) =>
      Contribution(target, CommonChannel.rotation, ScalarTarget(value));

  // ---- Common discrete channels ----

  /// Contribute the discrete `glyph-identity` choice (a [Glyph]).
  ///
  /// The [target] must be a [GlyphElement] (only a glyph-bearing element
  /// exposes the `glyph-identity` channel — see [Channel] / `channelsOf`).
  static Contribution glyphIdentity(Element target, Glyph value) =>
      Contribution(target, CommonChannel.glyphIdentity, GlyphTarget(value));

  /// Contribute the `stroke-color` ([Styling.strokeColor]).
  static Contribution strokeColor(Element target, Color value) =>
      Contribution(target, CommonChannel.strokeColor, ColorTarget(value));

  /// Contribute the `fill-color` ([Styling.fillColor]).
  static Contribution fillColor(Element target, Color value) =>
      Contribution(target, CommonChannel.fillColor, ColorTarget(value));

  /// Contribute the staff-space `stroke-width` ([Styling.strokeWidth]).
  static Contribution strokeWidth(Element target, double value) =>
      Contribution(target, CommonChannel.strokeWidth, ScalarTarget(value));

  // ---- LineElement geometry channels (continuous, whole-point) ----

  /// Contribute a [LineElement]'s `start` point (local-frame [Offset]).
  static Contribution lineStart(Element target, Offset value) =>
      Contribution(target, LineGeometryChannel.start, OffsetTarget(value));

  /// Contribute a [LineElement]'s `end` point (local-frame [Offset]).
  static Contribution lineEnd(Element target, Offset value) =>
      Contribution(target, LineGeometryChannel.end, OffsetTarget(value));

  // ---- RectElement geometry channels (continuous, whole-point) ----

  /// Contribute a [RectElement]'s north-east corner (local-frame [Offset]).
  static Contribution rectNorthEast(Element target, Offset value) =>
      Contribution(target, RectGeometryChannel.northEast, OffsetTarget(value));

  /// Contribute a [RectElement]'s south-west corner (local-frame [Offset]).
  static Contribution rectSouthWest(Element target, Offset value) =>
      Contribution(target, RectGeometryChannel.southWest, OffsetTarget(value));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Contribution &&
          identical(other.target, target) &&
          other.channel == channel &&
          other.value == value);

  @override
  int get hashCode => Object.hash(identityHashCode(target), channel, value);

  @override
  String toString() =>
      'Contribution(${target.runtimeType}, $channel, $value)';
}
