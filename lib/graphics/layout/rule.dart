import 'package:vector_math/vector_math_64.dart' show Matrix4;

import 'package:music_notes_2/graphics/graphics_model/canvas_primitives.dart'
    show Element;

import 'channel.dart' show Channel;
import 'contribution.dart' show Contribution;
import 'scope.dart' show Scope;
import 'specificity.dart' show Specificity;

/// The execution contract every layout rule satisfies (WP3-S1).
///
/// A layout rule is a small, isolated unit (the CSS-inspired ambition lives in
/// WP4; WP3 only needs this execution contract). It exposes **three predicates**
/// plus a declarative `apply`, kept separate because each drives different
/// machinery:
///
/// - **[applicability]** — *"is this rule responsible for this context at all?"*
///   Filters scopes; runs no layout math. The seed of the WP4 selector concept.
/// - **[precondition]** — *"can I run yet?"* Drives **scheduling/ordering**
///   (S3). Returns [PreconditionResult], which **distinguishes a hard gate from
///   a convergence hint** — the distinction that keeps dependency cycles from
///   deadlocking (gate only on hard prerequisites; express convergence couplings
///   as hints so the relaxation loop relaxes them).
/// - **[postcondition]** — *"are my constraints now satisfied?"* Drives
///   **convergence** (S4). Side-effect-free and **ε-tolerance**-based, never
///   exact equality (damping only approaches a target asymptotically).
///   Evaluated only over the channels the rule **won** in the cascade.
/// - **[apply]** — the rule's actual work, **declarative**: returns the
///   [Contribution]s (channel → local target) it wants for the scope. It never
///   mutates the tree and holds no reference that could.
///
/// A rule may be flagged **validator-only** ([isValidatorOnly]): it implements
/// [applicability] + [postcondition] but **no `apply`** (emits no
/// contributions). It observes and reports, never affects layout — the safe
/// path to introduce a rule as a pure checker first (see
/// `docs/wp3/README.md` — "Validator-only rules").
///
/// ## Rules are declarative, not imperative
///
/// `apply` states the **target** value(s) it wants for specific channels, never
/// running imperative code that mutates nodes. Three reasons (carry the design
/// doc's rationale): less duplicated micro-layout math (pushed into the driver's
/// primitives, S4), testable in isolation (assert the contributions emitted),
/// and **resolvable conflicts** (only channel-keyed targets can be cascaded;
/// opaque mutations cannot). A [Contribution] is a complete, standalone
/// **target** in the local frame — never a delta (the type forbids it).
///
/// ## Local targets, not globals
///
/// Rules speak in their **local** (parent-relative) frame; the driver owns
/// local→global composition and the relational math. The author never writes
/// global coordinates.
///
/// ## The driver owns the write
///
/// A rule declares *what value a channel should have*; the driver (S2)
/// collects contributions across all rules, resolves each channel by the
/// cascade, and writes the winners in place. A rule never touches the tree.
abstract class LayoutRule {
  /// A human-readable name for diagnostics. Stable across runs (used in the
  /// `(rule, scope)` key and diagnostic records).
  String get name;

  /// An opaque, comparable specificity plus registration order. The cascade
  /// (S2) selects the highest-specificity contribution per channel and breaks
  /// ties by registration order. WP3 consumes specificity *as a given* — the
  /// concrete metric is a WP4 dependency; the placeholder lets WP3's own tests
  /// drive the cascade without WP4.
  Specificity get specificity;

  /// `true` for a rule that implements [applicability] + [postcondition] but
  /// **no `apply`** — it emits no contributions and never affects layout, only
  /// reports. The safe path to introduce a rule as a pure checker first.
  bool get isValidatorOnly;

  /// The scopes (one per application) this rule is responsible for in [tree].
  ///
  /// This is the **applicability** predicate made concrete: it filters the
  /// tree down to the [Scope]s the rule targets, before anything else runs.
  /// It must not run any layout math — only decide *where* the rule applies
  /// and assemble each application's [Scope] (root + context). The driver (S4)
  /// calls this once per pass to enumerate the rule's applications.
  ///
  /// Why this returns built [Scope]s (not just candidate roots): the rule knows
  /// which context elements it needs (descendants, cross-reference targets, or
  /// other neighbours), so it assembles each scope's context here. The driver
  /// then feeds each [Scope] to [precondition] / [apply] / [postcondition].
  Iterable<Scope> applicability(Element tree);

  /// Whether this rule can run on [scope] yet (its input layout state is
  /// ready). Drives scheduling (S3).
  ///
  /// Returns [PreconditionResult], which **distinguishes a hard gate from a
  /// convergence hint** — the distinction that keeps dependency cycles from
  /// deadlocking:
  /// - a **hard gate** ([PreconditionResult.blocked]) — "my input geometry does
  ///   not exist yet / the element I read is not *resolved* (WP1-S5)". A real
  ///   prerequisite; forms a DAG by construction.
  /// - a **convergence hint** ([PreconditionResult.ready] carrying
  ///   `unmetHints`) — "I'd compute a better value if B were placed, but I can
  ///   run against whatever is there now and improve next pass". **Not** a gate.
  ///
  /// A precondition that would create a cycle is the signal that a convergence
  /// coupling was mis-modelled as a gate (see `docs/wp3/README.md` — "Dependency
  /// cycles are handled by iteration").
  PreconditionResult precondition(Scope scope, Map<Element, Matrix4> index);

  /// Whether this rule's constraints are now satisfied on [scope], to within
  /// tolerance — the check that feeds the settled test (S4).
  ///
  /// **Side-effect-free** and **ε-tolerance**-based (an ε band, "within
  /// tolerance of the required clearance"), never exact equality: damping only
  /// *approaches* a target asymptotically, so an exact test would never read
  /// "satisfied".
  ///
  /// Evaluated only over [wonChannels] — the channels the rule **won** in the
  /// cascade this pass. A rule that lost a channel to a more specific rule must
  /// **not** keep asserting over it (it was overruled; that claim is void — see
  /// "Postconditions decompose per channel too" in the design doc). The driver
  /// passes [wonChannels] so a loser genuinely stands down on overruled
  /// channels rather than reporting "unsatisfied" forever.
  bool postcondition(Scope scope, Set<Channel> wonChannels,
      Map<Element, Matrix4> index);

  /// Emits this rule's local-target [Contribution]s for [scope] — the rule's
  /// actual work, **declarative**: it states the target value(s) it wants for
  /// specific channels of the scope's elements, never mutating the tree.
  ///
  /// Each [Contribution] targets **one element's one channel** with a complete
  /// local-frame target (never a delta). A [Scope] may span several elements
  /// (a beam and its stems, a notehead and its preceding dot); the rule emits
  /// one contribution per (element, channel) it wants to move.
  ///
  /// **Validator-only rules do not implement this** ([isValidatorOnly] == true):
  /// the default returns an empty list, so a validator-only rule emits nothing
  /// by construction. A non-validator rule overrides this to declare its
  /// targets.
  Iterable<Contribution> apply(Scope scope, Map<Element, Matrix4> index) =>
      const [];
}

/// The result of [LayoutRule.precondition], distinguishing a **hard gate**
/// from a **convergence hint** (WP3-S1) — the distinction S3 uses to keep
/// dependency cycles from deadlocking.
sealed class PreconditionResult {
  const PreconditionResult();

  /// `true` when the rule may run now (not hard-blocked). A hint-bearing
  /// [ready] is still runnable — the hints just mean the value may improve
  /// next pass.
  bool get canRun;
}

/// A **hard gate** — "my input geometry does not exist yet / the element I
/// read is not *resolved* (WP1-S5)". A real prerequisite that forms a DAG by
/// construction. The rule must **not** run while blocked; the scheduler (S3)
/// waits until the gate clears.
class Blocked extends PreconditionResult {
  const Blocked(this.reason);

  /// Why the rule cannot run yet (a diagnostic message; e.g.
  /// "beam not yet resolved").
  final String reason;

  @override
  bool get canRun => false;

  @override
  String toString() => 'Blocked($reason)';
}

/// **Ready to run.** The rule's hard prerequisites are met. It may still carry
/// `unmetHints` — convergence couplings that would let it compute a better
/// value once satisfied, but do **not** gate it: the rule runs against the
/// current state and improves next pass if a hint is unmet.
class Ready extends PreconditionResult {
  const Ready({this.unmetHints = const []});

  /// Convergence hints not yet satisfied (e.g. "the beam I attach to is not yet
  /// placed"). Empty when fully ready. These are **not** gates — the rule runs
  /// regardless; the relaxation loop (S4) relaxes them across passes.
  final List<String> unmetHints;

  @override
  bool get canRun => true;

  @override
  String toString() =>
      unmetHints.isEmpty ? 'Ready' : 'Ready(hints: $unmetHints)';
}
