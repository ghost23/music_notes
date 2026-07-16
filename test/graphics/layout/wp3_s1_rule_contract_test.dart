import 'dart:ui' show Color, Offset, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;

import 'package:music_notes_2/graphics/generated/glyph_definitions.dart'
    show Glyph;
import 'package:music_notes_2/graphics/graphics_model/canvas_primitives.dart'
    show Element, GlyphElement, GroupElement, LineElement, RectElement;
import 'package:music_notes_2/graphics/graphics_model/styling.dart'
    show Styling;
import 'package:music_notes_2/graphics/graphics_model/transform.dart'
    show NodeTransform;
import 'package:music_notes_2/graphics/layout/channel.dart';
import 'package:music_notes_2/graphics/layout/contribution.dart';
import 'package:music_notes_2/graphics/layout/rule.dart';
import 'package:music_notes_2/graphics/layout/scope.dart';
import 'package:music_notes_2/graphics/layout/specificity.dart';

/// Unit tests for the WP3-S1 vocabulary types (no engine, no cascade, no loop).
///
/// They pin the four acceptance criteria:
/// - the `LayoutRule` contract exposes applicability, a precondition that
///   distinguishes hard gate from convergence hint, an ε-tolerance
///   side-effect-free postcondition, a declarative `apply`, and a
///   validator-only flag;
/// - the channel set, incl. per-primitive geometry channels at whole-point
///   granularity, every channel tagged continuous vs discrete/styling;
/// - `Contribution` is channel-keyed, local-frame, target-only — a delta is not
///   representable;
/// - a rule exposes an opaque comparable specificity + registration order, with
///   a placeholder ordering for tests.
///
/// Exercised by **fake** rules (incl. a validator-only one), per the story.
void main() {
  const black = Styling(strokeColor: Color(0xFF000000), strokeWidth: 0.12);

  GlyphElement noteheadAt(double x, double y) => GlyphElement(
        NodeTransform(translation: Offset(x, y)),
        Glyph.noteheadBlack,
        styling: const Styling(fillColor: Color(0xFF000000)),
      );

  LineElement line(Offset start, Offset end) => LineElement(
        const NodeTransform.identity(),
        start,
        end,
        styling: black,
      );

  final emptyIndex = <Element, Matrix4>{};

  group('channelsOf', () {
    test('every element exposes the four transform + three styling channels', () {
      final node = GroupElement(const NodeTransform.identity(), const []);
      final channels = channelsOf(node);
      expect(channels, contains(CommonChannel.translateX));
      expect(channels, contains(CommonChannel.translateY));
      expect(channels, contains(CommonChannel.scale));
      expect(channels, contains(CommonChannel.rotation));
      expect(channels, contains(CommonChannel.strokeColor));
      expect(channels, contains(CommonChannel.fillColor));
      expect(channels, contains(CommonChannel.strokeWidth));
    });

    test('a GlyphElement additionally exposes glyph-identity', () {
      final g = noteheadAt(0, 0);
      final channels = channelsOf(g);
      expect(channels, contains(CommonChannel.glyphIdentity));
    });

    test('a LineElement exposes start/end geometry channels', () {
      final l = line(Offset.zero, const Offset(0, -3));
      final channels = channelsOf(l);
      expect(channels, contains(LineGeometryChannel.start));
      expect(channels, contains(LineGeometryChannel.end));
      expect(channels, isNot(contains(CommonChannel.glyphIdentity)));
    });

    test('a RectElement exposes NE/SW corner geometry channels', () {
      final r = RectElement(
          const NodeTransform.identity(), const Rect.fromLTWH(0, 0, 2, 2));
      final channels = channelsOf(r);
      expect(channels, contains(RectGeometryChannel.northEast));
      expect(channels, contains(RectGeometryChannel.southWest));
    });

    test('no current element exposes curve geometry channels (deferred to WP6)',
        () {
      // Curve channels exist in the vocabulary but are not wired by channelsOf
      // until a curve primitive is introduced (WP6).
      expect(channelsOf(noteheadAt(0, 0)),
          isNot(contains(CurveGeometryChannel.start)));
      expect(channelsOf(line(Offset.zero, Offset.zero)),
          isNot(contains(CurveGeometryChannel.controlPoint1)));
    });
  });

  group('channel classification', () {
    test('transform + geometry channels are continuous (damped)', () {
      expect(CommonChannel.translateX.classification,
          ChannelClassification.continuous);
      expect(CommonChannel.scale.classification,
          ChannelClassification.continuous);
      expect(CommonChannel.rotation.classification,
          ChannelClassification.continuous);
      expect(LineGeometryChannel.start.classification,
          ChannelClassification.continuous);
      expect(RectGeometryChannel.northEast.classification,
          ChannelClassification.continuous);
      expect(CurveGeometryChannel.start.classification,
          ChannelClassification.continuous);
    });

    test('glyph-identity and styling fields are discrete (written directly)',
        () {
      expect(CommonChannel.glyphIdentity.classification,
          ChannelClassification.discrete);
      expect(CommonChannel.strokeColor.classification,
          ChannelClassification.discrete);
      expect(CommonChannel.fillColor.classification,
          ChannelClassification.discrete);
      // strokeWidth is numeric but discrete: damping applies to transform +
      // geometry only, never styling (see ChannelClassification).
      expect(CommonChannel.strokeWidth.classification,
          ChannelClassification.discrete);
    });
  });

  group('Contribution: target-only, local-frame, channel-keyed', () {
    test('a translate-x contribution carries a scalar target, not a delta', () {
      final note = noteheadAt(0, 0);
      final c = Contribution.translateX(note, 2.5);
      expect(c.target, same(note));
      expect(c.channel, CommonChannel.translateX);
      expect(c.value, isA<ScalarTarget>());
      expect((c.value as ScalarTarget).value, 2.5);
    });

    test('geometry contributions carry whole-point offset targets', () {
      final stem = line(Offset.zero, const Offset(0, -3));
      final start = Contribution.lineStart(stem, const Offset(0, 0));
      final end = Contribution.lineEnd(stem, const Offset(0, -3.5));
      expect(start.channel, LineGeometryChannel.start);
      expect(start.value, isA<OffsetTarget>());
      expect((start.value as OffsetTarget).value, const Offset(0, 0));
      expect(end.channel, LineGeometryChannel.end);
      expect((end.value as OffsetTarget).value, const Offset(0, -3.5));
    });

    test('glyph-identity carries a Glyph choice', () {
      final note = noteheadAt(0, 0);
      final c = Contribution.glyphIdentity(note, Glyph.noteheadHalf);
      expect(c.channel, CommonChannel.glyphIdentity);
      expect(c.value, isA<GlyphTarget>());
      expect((c.value as GlyphTarget).value, Glyph.noteheadHalf);
    });

    test('styling contributions carry the correct value kind', () {
      final note = noteheadAt(0, 0);
      expect(Contribution.strokeColor(note, const Color(0xFFFF0000)).value,
          isA<ColorTarget>());
      expect(Contribution.fillColor(note, const Color(0xFF00FF00)).value,
          isA<ColorTarget>());
      expect(Contribution.strokeWidth(note, 0.1).value, isA<ScalarTarget>());
    });

    test('a delta/increment is not representable by the type', () {
      // No factory produces a delta; TargetValue is a sealed sum with exactly
      // four target kinds — scalar, offset, colour, glyph — and no delta
      // variant. The only way to express "move by" is to compute the complete
      // target from current state and emit it, which is the rule's job, not
      // the type's. Assert the four kinds exist and are distinct TargetValues.
      final a = const ScalarTarget(1);
      final b = const OffsetTarget(Offset.zero);
      final c = const ColorTarget(Color(0xFF000000));
      final d = const GlyphTarget(Glyph.noteheadBlack);
      for (final value in [a, b, c, d]) {
        expect(value, isA<TargetValue>());
      }
      expect(a == b, isFalse);
      expect(a == c, isFalse);
      expect(a == d, isFalse);
      expect(b == c, isFalse);
    });

    test('equality is by target identity + channel + value', () {
      final note = noteheadAt(0, 0);
      final a = Contribution.translateX(note, 2.0);
      final b = Contribution.translateX(note, 2.0);
      final c = Contribution.translateX(note, 3.0);
      expect(a, b);
      expect(a == c, isFalse);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('Specificity: opaque comparable + registration order', () {
    test('higher rank is more specific (placeholder ordering)', () {
      const general = Specificity(1);
      const specific = Specificity(5);
      expect(general.compareTo(specific), lessThan(0));
      expect(specific.compareTo(general), greaterThan(0));
      expect(general.compareTo(general), 0);
    });

    test('equal ranks are peers (fall back to registration order)', () {
      const a = Specificity(3);
      const b = Specificity(3);
      expect(a.compareTo(b), 0);
      expect(a, b);
    });
  });

  group('Scope: root + context (multi-element)', () {
    test('a scope has a root and may carry several context elements', () {
      final beam = GroupElement(const NodeTransform.identity(), const []);
      final stemA = line(Offset.zero, const Offset(0, -3));
      final stemB = line(Offset.zero, const Offset(2, -3));
      final scope =
          Scope(root: beam, context: [stemA, stemB]);
      expect(identical(scope.root, beam), isTrue);
      expect(scope.context.length, 2);
      expect(identical(scope.context[0], stemA), isTrue);
      expect(identical(scope.context[1], stemB), isTrue);
      expect(scope.all, [beam, stemA, stemB]);
    });

    test('context can include a cross-reference target (not a descendant)',
        () {
      // A slur's scope: root = the slur, context = the noteheads it references
      // (reached via cross-reference, not as children).
      final slur = GroupElement(const NodeTransform.identity(), const []);
      final noteA = noteheadAt(1, 2);
      final noteB = noteheadAt(5, 3);
      final scope = Scope(root: slur, context: [noteA, noteB]);
      expect(scope.context, containsAll([noteA, noteB]));
    });

    test('a scope may act on the root alone (empty context)', () {
      final note = noteheadAt(0, 0);
      final scope = Scope(root: note);
      expect(scope.context, isEmpty);
      expect(scope.all, [note]);
    });

    test('equality is by identity of root + context elements', () {
      final root = noteheadAt(0, 0);
      final ctx = noteheadAt(1, 0);
      final a = Scope(root: root, context: [ctx]);
      final b = Scope(root: root, context: [ctx]);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('LayoutRule contract via fakes', () {
    test('applicability filters the tree down to the rule\'s scopes', () {
      final noteA = noteheadAt(0, 0);
      final noteB = noteheadAt(4, 0);
      final tree =
          GroupElement(const NodeTransform.identity(), [noteA, noteB]);
      final rule = _FakeTranslateXRule(targets: [noteA, noteB], targetX: 10);
      final scopes = rule.applicability(tree).toList();
      expect(scopes.length, 2);
      expect(identical(scopes[0].root, noteA), isTrue);
      expect(identical(scopes[1].root, noteB), isTrue);
    });

    test('apply emits the expected local-target contributions', () {
      final note = noteheadAt(0, 0);
      final tree = GroupElement(const NodeTransform.identity(), [note]);
      final rule = _FakeTranslateXRule(targets: [note], targetX: 10);
      final scope = rule.applicability(tree).single;

      final contributions = rule.apply(scope, emptyIndex).toList();
      expect(contributions.length, 1);
      expect(contributions[0].channel, CommonChannel.translateX);
      expect(identical(contributions[0].target, note), isTrue);
      expect((contributions[0].value as ScalarTarget).value, 10.0);
    });

    test('a validator-only rule emits no contributions', () {
      final note = noteheadAt(0, 0);
      final tree = GroupElement(const NodeTransform.identity(), [note]);
      final rule = _FakeValidatorRule(expectedX: 10);
      expect(rule.isValidatorOnly, isTrue);

      final scope = rule.applicability(tree).single;
      expect(rule.apply(scope, emptyIndex), isEmpty);
    });

    test('precondition distinguishes a hard gate from a convergence hint', () {
      // A rule gated on a target being resolved: blocked while unresolved,
      // ready once resolved.
      final slur = GroupElement(const NodeTransform.identity(), const [])
        ..isResolved = false;
      final resolvedSlur = GroupElement(const NodeTransform.identity(), const [])
        ..isResolved = true;
      final rule = _FakeGatedRule();

      final blocked = rule.precondition(
          Scope(root: slur), emptyIndex);
      expect(blocked, isA<Blocked>());
      expect(blocked.canRun, isFalse);

      final ready = rule.precondition(
          Scope(root: resolvedSlur), emptyIndex);
      expect(ready, isA<Ready>());
      expect(ready.canRun, isTrue);
    });

    test('a Ready result may carry unmet convergence hints (still runnable)',
        () {
      final rule = _FakeHintedRule();
      final result = rule.precondition(
          Scope(root: noteheadAt(0, 0)), emptyIndex);
      expect(result, isA<Ready>());
      expect(result.canRun, isTrue);
      expect((result as Ready).unmetHints, isNotEmpty);
    });

    test('postcondition is ε-tolerance and evaluates without side effects', () {
      // The fake's postcondition is satisfied within tolerance of targetX.
      final note = noteheadAt(0, 0)..transform =
          NodeTransform(translation: const Offset(9.99, 0));
      final tree = GroupElement(const NodeTransform.identity(), [note]);
      final rule = _FakeTranslateXRule(targets: [note], targetX: 10);

      final scope = rule.applicability(tree).single;
      // Within ε of 10 -> satisfied, even though not bit-exact (damping only
      // approaches a target asymptotically; the postcondition is ε-based).
      expect(
        rule.postcondition(scope, {CommonChannel.translateX}, emptyIndex),
        isTrue,
      );
      // The node was not mutated by the read-only postcondition.
      expect(note.transform.translation.dx, 9.99);

      // Far from target -> not satisfied.
      note.transform =
          NodeTransform(translation: const Offset(5.0, 0));
      expect(
        rule.postcondition(scope, {CommonChannel.translateX}, emptyIndex),
        isFalse,
      );
    });

    test('a suppressed rule stands down on the lost channel (postcondition '
        'over won channels only)', () {
      // If the rule lost translate-x (wonChannels excludes it), it must not
      // assert over it — the postcondition passes vacuously for a channel it
      // was overruled on. Here the node is far from the target, but because
      // the rule won NO channels, it makes no claim.
      final note = noteheadAt(0, 0)..transform =
          NodeTransform(translation: const Offset(0, 0));
      final tree = GroupElement(const NodeTransform.identity(), [note]);
      final rule = _FakeTranslateXRule(targets: [note], targetX: 10);
      final scope = rule.applicability(tree).single;

      expect(
        rule.postcondition(scope, const <Channel>{}, emptyIndex),
        isTrue, // won nothing -> no claim -> stands down
      );
    });

    test('a rule exposes specificity + name', () {
      final rule = _FakeTranslateXRule(targets: const [], targetX: 0);
      expect(rule.name, 'fake-translate-x');
      expect(rule.specificity, const Specificity(1));
    });
  });
}

// ---- Fake rules (test doubles, not real music rules) ----

/// A fake rule that owns `translate-x` for a fixed set of notehead targets,
/// pushing each to `targetX`. Used to assert `apply` emits expected
/// contributions and the ε-tolerance postcondition.
class _FakeTranslateXRule extends LayoutRule {
  _FakeTranslateXRule({required this.targets, required this.targetX});

  final List<GlyphElement> targets;
  final double targetX;

  static const _epsilon = 0.05;

  @override
  String get name => 'fake-translate-x';

  @override
  Specificity get specificity => const Specificity(1);

  @override
  bool get isValidatorOnly => false;

  @override
  Iterable<Scope> applicability(Element tree) sync* {
    final present = targets.toSet();
    for (final target in present) {
      yield Scope(root: target);
    }
  }

  @override
  PreconditionResult precondition(Scope scope, Map<Element, Matrix4> index) =>
      const Ready();

  @override
  bool postcondition(
      Scope scope, Set<Channel> wonChannels, Map<Element, Matrix4> index) {
    if (!wonChannels.contains(CommonChannel.translateX)) return true;
    final node = scope.root;
    return (node.transform.translation.dx - targetX).abs() <= _epsilon;
  }

  @override
  Iterable<Contribution> apply(
      Scope scope, Map<Element, Matrix4> index) sync* {
    yield Contribution.translateX(scope.root, targetX);
  }
}

/// A fake **validator-only** rule: it observes whether a notehead sits near an
/// expected X but emits no contributions. Proves a validator-only rule emits
/// nothing and still evaluates its postcondition.
class _FakeValidatorRule extends LayoutRule {
  _FakeValidatorRule({required this.expectedX});

  final double expectedX;
  static const _epsilon = 0.05;

  @override
  String get name => 'fake-validator';

  @override
  Specificity get specificity => const Specificity(2);

  @override
  bool get isValidatorOnly => true;

  @override
  Iterable<Scope> applicability(Element tree) sync* {
    // Targets every GlyphElement in the tree (a trivial selector stand-in).
    for (final descendant in _descendants(tree)) {
      if (descendant is GlyphElement) {
        yield Scope(root: descendant);
      }
    }
  }

  @override
  PreconditionResult precondition(Scope scope, Map<Element, Matrix4> index) =>
      const Ready();

  @override
  bool postcondition(
      Scope scope, Set<Channel> wonChannels, Map<Element, Matrix4> index) {
    // A validator-only rule wins no channels, so wonChannels is empty; it
    // reports its observation via the postcondition regardless.
    final node = scope.root;
    return (node.transform.translation.dx - expectedX).abs() <= _epsilon;
  }

  // apply inherited: returns const [] — a validator-only rule emits nothing.
}

/// A fake rule whose precondition is a **hard gate** on its root being resolved.
class _FakeGatedRule extends LayoutRule {
  @override
  String get name => 'fake-gated';

  @override
  Specificity get specificity => const Specificity(3);

  @override
  bool get isValidatorOnly => false;

  @override
  Iterable<Scope> applicability(Element tree) sync* {
    for (final descendant in _descendants(tree)) {
      yield Scope(root: descendant);
    }
  }

  @override
  PreconditionResult precondition(Scope scope, Map<Element, Matrix4> index) {
    if (!scope.root.isResolved) {
      return Blocked('${scope.root.runtimeType} is not resolved');
    }
    return const Ready();
  }

  @override
  bool postcondition(
      Scope scope, Set<Channel> wonChannels, Map<Element, Matrix4> index) {
    return scope.root.isResolved;
  }

  @override
  Iterable<Contribution> apply(Scope scope, Map<Element, Matrix4> index) =>
      const [];
}

/// A fake rule whose precondition is **ready but carrying an unmet hint** — a
/// convergence coupling that does not gate the rule.
class _FakeHintedRule extends LayoutRule {
  @override
  String get name => 'fake-hinted';

  @override
  Specificity get specificity => const Specificity(1);

  @override
  bool get isValidatorOnly => false;

  @override
  Iterable<Scope> applicability(Element tree) sync* {
    for (final descendant in _descendants(tree)) {
      yield Scope(root: descendant);
    }
  }

  @override
  PreconditionResult precondition(Scope scope, Map<Element, Matrix4> index) =>
      const Ready(unmetHints: ['the beam I attach to is not yet placed']);

  @override
  bool postcondition(
      Scope scope, Set<Channel> wonChannels, Map<Element, Matrix4> index) =>
      true;

  @override
  Iterable<Contribution> apply(Scope scope, Map<Element, Matrix4> index) =>
      const [];
}

/// Pre-order descendants of [root] (root excluded).
Iterable<Element> _descendants(Element root) sync* {
  for (final child in root.elements) {
    yield child;
    yield* _descendants(child);
  }
}
