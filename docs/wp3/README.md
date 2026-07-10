# WP3 — Layout Engine Core (multi-pass driver)

**Status: preliminary / thinking-in-progress.** This document captures the
current state of our design thinking for the multi-pass layout driver and the
rule contract it runs. It is not yet broken into developer stories; it exists to
pin down the concepts we agreed on before we commit to an interface.

See [`../rewrite-plan.md`](../rewrite-plan.md) (WP3 section + "Pass convergence"
open question), [`../code-principle.md`](../code-principle.md), and the WP1 IR
contract — especially [`../wp1/S5-deferred-references.md`](../wp1/S5-deferred-references.md),
whose *reference resolution* mechanism WP3 consumes.

## Goal

Turn the WP1 IR (a pure-data scene graph of `Element`s carrying mutable
transforms in staff-space units) into a **laid-out** tree by running layout rules
over it in repeated passes until the layout **settles**. The driver is the spine
for the property that motivates the whole rewrite: *setting one symbol's
position can affect another symbol we already placed.*

The driver itself computes **no** music geometry. It only: builds the tree,
schedules rules, feeds them the derived data they need (absolute geometry),
detects when the layout has settled, and hands a best-effort tree to the
renderer.

## Where layout output lives (recap of the WP1 decision)

There is **no separate "layout result" struct.** Layout output is written
**in place** into the IR:

- position/scale/rotation → each `Element`'s mutable `NodeTransform transform`;
- intrinsic geometry → primitive leaves (`LineElement.startPoint/endPoint` for
  stem length, etc.);
- glyph choice (e.g. flag-up vs flag-down) → the leaf's `Glyph` identity;
- presentation → `Styling`.

Rules mutate these fields on the existing nodes (never `copyWith`-replace a node
that may be a reference target — see S5). WP3 orchestrates *when* rules run; it
does not own the output.

## Terminology — two distinct senses of "resolved"

These are easy to conflate and mean different things:

- **Reference resolution (WP1-S5).** A *deferred* element (beam, slur, tie) goes
  from **unresolved** (holds references, has no drawable geometry, *throws* if
  rendered) to **resolved** (has concrete primitives). This is a structural
  state of an individual element.
- **Settled / stable (this document).** The layout *as a whole* has reached a
  fixed point: every rule reports its constraints satisfied, and no forbidden
  collisions remain. This is a convergence property of the whole tree, derived
  from checks — **not** a flag stored on nodes.

To avoid overloading "resolved," this doc uses **settled** for the WP3
convergence sense.

## The rule contract

A layout rule is a small, isolated unit (the CSS-inspired ambition lives in WP4;
WP3 only needs the execution contract). A rule exposes up to **three predicates**
plus an action. Keeping the three predicates separate is deliberate — they drive
different machinery.

1. **Applicability — "is this rule responsible for this context at all?"**
   A stem/beam rule has nothing to say about a barline. Applicability filters the
   tree down to the scopes a rule targets, before anything else runs. (This is
   the seed of the WP4 selector concept; WP3 just needs a boolean/scope query.)

2. **Precondition — "can I run *yet*?"**
   Governs **scheduling/ordering**. A stem-length rule cannot finalize until the
   beam it attaches to is placed. Preconditions induce a **dependency ordering**
   between rules (ideally a DAG); a rule is only asked to act, or asked about its
   postcondition, once its preconditions hold.

3. **Postcondition — "are my constraints now satisfied?"**
   Governs **convergence**. This is the check that feeds the settled test. It
   must be evaluable against the *current* tree state without side effects.

Plus:

- **Apply** — the rule's actual work: mutate transforms / geometry / styling to
  move the targeted scope toward satisfying its postcondition.

### Validator-only rules

A rule may be flagged as **validator-only**: it implements applicability +
postcondition but **no `apply`** (or an `apply` that is a no-op). It observes and
reports but never mutates the tree. This gives us a safe path to **introduce a
new rule as a pure checker first** — watch what it would flag across real
fixtures — before we let it start moving symbols. It is also how the collision
safety-net below is expressed.

## Collisions are rules, not a privileged global algorithm

Raw geometric overlap is **not** the same as "unsettled" — correct notation
overlaps constantly (notehead↔stem, accidental tucked under the prior note,
ledger lines across the stem, beam on stem tips). What matters is a **forbidden
collision**: a specific pair that engraving rules require to keep clearance,
violating it. That is *domain knowledge* (which pairs must not touch, and how
much clearance), not a pure geometry sweep.

So collision handling is modelled as:

- **Collision rules** for the known cases (accidental-vs-augmentation-dot,
  note-vs-note in adjacent columns, dot-on-a-staff-line nudging, …) — ordinary
  rules with the same applicability/precondition/postcondition/apply shape.
- **One catch-all overlap validator** (validator-only) as a safety net that
  flags *unanticipated* forbidden overlaps as **diagnostics** — a signal that we
  are missing a rule, not that the score is un-renderable.

This keeps a single uniform abstraction instead of a rule system *plus* a
special global algorithm with different semantics.

## The driver loop (sketch)

```
build tree from data model (WP5 builders)
build absolute-transform/anchor index (top-down, from current transforms)
repeat, up to a bounded iteration count:
    for each rule, in dependency + priority order:
        for each applicable scope whose preconditions hold:
            apply the rule (mutates transforms/geometry in place)
    rebuild the absolute-transform/anchor index   # transforms changed
    evaluate all postconditions + the catch-all validator
    if all satisfied and no forbidden collisions: -> SETTLED, stop
if not settled after the bound:
    emit best-effort tree + diagnostics (do NOT block rendering)
```

### Convergence is the hard part (harder than efficiency)

A relaxation loop can **oscillate**: rule A shoves the accidental left off the
dot, rule B shoves the dot right off the accidental, forever. Two guards:

- **Ordering via priority (tentative).** A dependency order from preconditions
  handles most sequencing; where two rules genuinely conflict, a **priority**
  decides who yields, so a satisfied higher-priority rule is not undone by a
  lower one. **Open concern:** priority tends to inflate — every rule author
  believes their rule is the most important. We adopt priority *for now* but
  flag it as unresolved; we may need a more principled conflict model (see open
  questions).
- **Bounded iteration count (always).** The loop has a hard cap regardless. This
  is a non-negotiable backstop against non-termination.

### Non-convergence must degrade gracefully

Because every `Element` **always** carries a transform value, "unsettled" never
means "un-drawable." If the loop hits its bound without settling, the driver
emits the current best-effort geometry **plus diagnostics**, and the renderer
draws it. Unsettled is a **quality / convergence signal, not a gate on output**.
(Contrast S5's separate `isResolved` flag: an *unresolved* node has only
tentative geometry and is refused at the render boundary — that is a
structural failure the builder/resolvers must not leave behind. "Settled" and
"resolved" are different notions: a node can be *resolved* (geometry built)
but not yet *settled* (a rule might still tweak it) — the former gates drawing,
the latter gates convergence.)

## Where "settled" state lives

**Not on the elements.** A stored `settled`/`resolved` boolean on a node can lie
after a later mutation. Instead, settledness is **derived** each pass by
evaluating postconditions, and reported as a driver-owned structure keyed by
**(rule instance, scope)** — because one element participates in many rules (a
notehead is touched by the stem, accidental, dot, and collision rules). Whole-
tree "settled" is just the conjunction of all postcondition results plus the
catch-all validator. Nothing new is persisted in the WP1 IR.

## Coupling to WP1

- **Absolute-transform/anchor index.** Postconditions and collision checks need
  *absolute* bounding boxes, which are composed **top-down** by free functions
  (no parent pointers — WP1-S1/S5). The driver owns this index, rebuilds it after
  each mutating pass, and passes it to rules. It is pass-local derived data, not
  IR state (see the rewrite-plan WP3 note).
- **Spatial bucketing.** The catch-all overlap sweep uses the IR's existing
  `Column` / `Measure` / `Staff` nesting as spatial buckets, so it need not be
  O(n²) across the whole score. (Optimise only if measured — rewrite-plan.)
- **Reference resolution (S5).** Deferred-element resolution is one kind of pass
  the driver schedules; its resolvers read the same absolute index. Stem-length-
  extends-to-beam is the canonical case where a deferred resolution writes back
  into an already-placed element's geometry.

## Scope

**In (WP3):**
- The rule execution contract (applicability / precondition / postcondition /
  apply; validator-only flag).
- The pass driver: scheduling by dependency order + priority, bounded iteration,
  index rebuild, settled detection, best-effort + diagnostics on non-convergence.
- The (rule, scope) settledness report as derived, pass-local data.

**Out:**
- The WP4 selector grammar / cascade / property-conflict model (only the minimal
  applicability query is needed here).
- The actual music rules (WP5 intra-measure, WP6 context-dependent).
- The catalogue of forbidden-collision pairs + clearances (domain data supplied
  by WP5/WP6 rules; WP3 only runs the checks).

## Open design questions

- **Conflict model beyond priority.** Priority is a placeholder. Is there a more
  principled scheme (explicit "who-yields-to-whom" relations, monotonic
  relaxation, constraint weights) that avoids priority inflation?
- **Dependency cycles.** Preconditions ideally form a DAG. What do we do if two
  rules mutually depend (A needs B placed, B needs A placed)? Detect and break,
  or express as a single combined rule?
- **Bound + damping.** What iteration bound is realistic, and do we need damping
  (limit how far a rule may move a symbol per pass) to guarantee progress rather
  than oscillation within the bound?
- **Dirty-tracking.** Rebuilding the full absolute index every pass is the
  correct default; when is per-subtree dirty-tracking worth the invalidation
  complexity? (Defer until profiled.)
- **Diagnostics surface.** What shape do best-effort/non-convergence diagnostics
  take, and how do they reach the visual-regression harness (WP2-S5)?
