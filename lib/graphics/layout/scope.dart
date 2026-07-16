import 'package:music_notes_2/graphics/graphics_model/canvas_primitives.dart'
    show Element;

/// One application of a layout rule: a **root** element plus the **context**
/// elements that participate in that one application (WP3-S1).
///
/// A rule rarely acts on a single element in isolation — its geometry depends
/// on neighbours. A stem-length rule's root is the stem, but it reads the beam
/// it attaches to; a slur rule's root is the slur, but it reads the noteheads
/// it spans; an accidental-stacking rule's root is one accidental, but it reads
/// the others in the stack. So a [Scope] is a root plus the additional elements
/// that form the rule's *context* for that one application.
///
/// ## What the context contains
///
/// The context is whatever the rule genuinely needs to read, regardless of
/// where it sits in the tree:
/// - **descendants of the root** — e.g. a note rule whose root is a
///   `PitchedNoteElement` may include its `stem` / `dots` leaves as context;
/// - **cross-reference targets held by the root** — e.g. a slur rule whose root
///   is a `SlurElement` includes the noteheads its `crossReferences` point at;
///   a beam rule includes its referenced stems;
/// - **arbitrary other elements** the rule reads — e.g. the preceding dot, a
///   sibling accidental, the staff the root sits in.
///
/// The [Scope] itself is pure data — it does not derive or validate the
/// context. **Building scopes is the driver's job (S4):** for each rule, the
/// driver walks the tree, decides where the rule applies (via
/// [LayoutRule.applicability]), and constructs a [Scope] per application with
/// the context that rule asks for (see [LayoutRule.buildScope]). S1 only pins
/// the type every application keys off.
///
/// ## Why a designated root
///
/// Every scope has exactly one [root] — the primary element the rule acts on
/// and writes contributions to. This gives each application a stable identity
/// for the per-`(rule, scope)` action budget (S4): the budget is keyed by the
/// `(rule, root)` pair, so a rule can act on the same root at most N times
/// before being frozen. For a *peer-pair* rule (e.g. a collision rule between
/// two adjacent notes where neither is inherently primary), the driver
/// designates one element as [root] deterministically; the other is context.
///
/// ## Identity
///
/// [root] and the [context] entries are held by **Dart object identity**, like
/// cross-references and the absolute-transform index: the driver writes a
/// target's channel in place, never replacing the node, so a scope stays valid
/// across layout passes.
class Scope {
  /// Creates a scope with [root] and an (ordered, deterministic) [context].
  const Scope({required this.root, this.context = const []});

  /// The primary element this rule application acts on. The per-`(rule, scope)`
  /// action budget (S4) is keyed by `(rule, root)`.
  final Element root;

  /// The additional elements participating in this one application —
  /// descendants of [root], cross-reference targets it holds, or other
  /// elements the rule reads. Order is deterministic (the driver builds
  /// scopes in a fixed walk order) but carries no domain meaning; conceptually
  /// a set. May be empty for a rule that acts on the root alone.
  final List<Element> context;

  /// Every element in this scope — [root] first, then [context]. The
  /// flattened view a rule iterates when it needs all participants.
  List<Element> get all => <Element>[root, ...context];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Scope &&
          identical(other.root, root) &&
          _sameContext(other.context));

  bool _sameContext(List<Element> other) {
    if (context.length != other.length) return false;
    for (var i = 0; i < context.length; i++) {
      if (!identical(context[i], other[i])) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(identityHashCode(root), Object.hashAll(context.map(identityHashCode)));

  @override
  String toString() =>
      'Scope(root: ${root.runtimeType}, context: ${context.map((e) => e.runtimeType).join(', ')})';
}
