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

The **driver** writes these fields on the existing nodes (never `copyWith`-
replace a node that may be a reference target — see S5). Rules do **not** mutate
the tree directly: they *declare* per-channel target contributions and the driver
resolves them and writes the winners in place (see "Rules are declarative" and
"Channels and the cascade" below). WP3 orchestrates *when* rules run and *owns
the write*; the geometry values themselves come from the rules.

## Terminology — two distinct senses of "resolved"

These are easy to conflate and mean different things:

- **Reference resolution (WP1-S5).** A *deferred* element (beam, slur, tie) goes
  from **unresolved** (holds references, has no drawable geometry, *throws* if
  rendered) to **resolved** (has concrete primitives). This is a structural
  state of an individual element.
- **Settled / stable (this document).** The layout *as a whole* has reached a
  fixed point: every rule reports its constraints satisfied (collision rules
  included). This is a convergence property of the whole tree, derived from
  checks — **not** a flag stored on nodes.

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

- **Apply** — the rule's actual work. **Not** a free-form mutation: the rule
  *emits per-channel target contributions* (see "Channels and the cascade") for
  the scope it targets. The driver collects contributions across all rules,
  resolves each channel, and writes the winners. A rule declares *what value a
  channel should have*; it never touches the tree itself.

### Rules are declarative, not imperative

The `apply` above is deliberately **declarative**: a rule states the target
value(s) it wants for specific channels, rather than running imperative code that
mutates nodes. This is a deliberate move away from the "rules mutate in place"
phrasing of earlier drafts, for three reasons:

- **Less duplicated code.** Imperative rules each re-derive the same micro-layout
  math (edge of the previous notehead, distributing slack across columns,
  composing transforms). Declarative rules push those algorithms into **one**
  central place — the driver's layout primitives — where they are written and
  tested once. Rules shrink to the genuinely domain-specific part.
- **Testable in isolation.** A rule is a function from (scope, absolute index) to
  a set of contributions. It can be tested by asserting the contributions it
  emits, without standing up the whole engine.
- **Resolvable conflicts.** Only because contributions are *declared and keyed by
  channel* can the driver resolve competing rules per channel (below). Opaque
  mutations cannot be cascaded.

**Local targets, not deltas, not globals.** Two independent axes, kept separate:

- *Coordinate frame:* rules speak in their **local** (parent-relative) frame. The
  driver owns local→global composition (the absolute-transform index) and the
  relational math. A rule expresses local *intent* — "clear the preceding dot by
  0.2sp" — and a driver primitive turns that into a concrete local value. The
  author never writes global coordinates.
- *Value kind:* a contribution is a **target** (a complete, standalone value for
  the channel *in the local frame*), never a **delta/increment**. A delta has no
  meaning without a base, so its result would depend on application order and on
  which other rules fired — which reintroduces the priority-ordering problem and
  makes per-channel suppression incoherent. A target is a complete answer the
  cascade can select or discard, order-independently.

Where accumulation *is* the correct domain behaviour (e.g. stacking multiple
accidentals), that is **one rule** reading all participants and computing each
one's local target — explicit and centralized — not the cascade summing
independent deltas from rules blind to each other.

### Validator-only rules

A rule may be flagged as **validator-only**: it implements applicability +
postcondition but **no `apply`** — it emits no contributions to any channel. It
observes and reports but never affects layout. This gives us a safe path to
**introduce a new rule as a pure checker first** — watch what it would flag
across real fixtures — before we let it start emitting contributions and moving
symbols (see the targeted collision-rule path below).

## Collisions are rules, not a privileged global algorithm

Raw geometric overlap is **not** the same as "unsettled" — correct notation
overlaps constantly (notehead↔stem, accidental tucked under the prior note,
ledger lines across the stem, beam on stem tips). What matters is a **forbidden
collision**: a specific pair that engraving rules require to keep clearance,
violating it. That is *domain knowledge* (which pairs must not touch, and how
much clearance), not a pure geometry sweep.

So collision handling is modelled as **collision rules** for the known cases
(accidental-vs-augmentation-dot, note-vs-note in adjacent columns,
dot-on-a-staff-line nudging, …) — ordinary rules with the same
applicability/precondition/postcondition/apply shape. Each carries the domain
knowledge for the pair(s) it governs: which must keep clearance, and how much.

This keeps a single uniform abstraction — everything is a rule — instead of a
rule system *plus* a special global algorithm with different semantics.

A targeted collision rule may start life **validator-only** (see above): a pure
checker for a specific pair, watched across real fixtures before it is allowed to
start moving symbols.

> **Rejected: a catch-all overlap validator.** An earlier draft proposed one
> validator-only rule that would sweep for *any* unanticipated forbidden overlap
> and emit it as a diagnostic ("we're missing a rule"). We dropped it: it is
> internally contradictory. Forbidden-ness is *domain knowledge* (which pairs
> must not touch, and by how much) that lives inside the specific rules — but a
> catch-all is by definition the rule with no such knowledge. It could only see
> raw geometry, and raw overlap is not the signal (correct notation overlaps
> constantly). So it would either flag every legitimate overlap as noise, or need
> to duplicate the very domain knowledge the specific rules already hold. It also
> has no registry to consult for "is this overlap already expected?" — that
> expectation lives inside the rules, not anywhere it could read. The only
> coherent version flips the model to an allowlist ("nothing may overlap unless a
> rule permits this pair"), which means enumerating every legitimate overlap in
> real notation — enormous, and fighting reality. The real "we're missing a rule"
> detector is the WP2-S5 visual-regression harness plus a human eyeball, not an
> in-engine validator.

## Channels and the cascade

This is the heart of the conflict model, and it is **CSS-inspired** (the full
selector/cascade grammar is WP4; WP3 needs the execution mechanics). The core
idea: rules do not fight over whole elements — they contribute to **channels**,
and conflicts are resolved **per channel**.

### Channels

A **channel** is an independently-resolvable slot of layout output. Every element
exposes a common set; primitive leaves expose extra geometry channels on top.

- **Common to all elements** (the `NodeTransform` + choices + presentation):
  - `translate-x`, `translate-y` — kept **separate**, because "one rule owns
    horizontal placement, another owns vertical" is a pervasive division of
    labour (spacing owns x, staff-position owns y), and translation is always
    exactly two well-known axes, so the split is cheap.
  - `scale`, `rotation`.
  - `glyph-identity` — a discrete choice (flag-up vs flag-down), resolved by the
    same cascade but with no target *math*, just a winning choice.
  - one channel per `Styling` field (colour, stroke width, …).
- **Primitive-specific geometry channels.** Each primitive type declares its own,
  at **whole-point granularity** (deliberately *not* split into x/y, to keep the
  channel count in check):
  - line → `start`, `end`;
  - rect → `northeast`, `southwest`;
  - curve/bezier (slur, beam edge) → its endpoints plus each control point.

  This folds *intrinsic geometry* into the same cascade as everything else, so
  the canonical **stem-length-extends-to-beam** hand-off (stem-direction rule
  sets the stem; beam resolver extends the same endpoint) is a normal per-channel
  resolution, not an uncontrolled imperative mutation.

  *Consequence of whole-point channels:* if two rules ever need independent
  control of a point's x vs. its y, they collide on the whole-point channel and
  one suppresses the other entirely. That is the coupled-channels question in
  miniature (below); the first concrete rule that needs per-axis control is the
  trigger to revisit.

### The cascade (per-channel suppression)

Each pass, for every applicable scope whose preconditions hold, rules emit their
local-target contributions. For **each channel independently**, the driver:

1. gathers all contributions to that channel,
2. picks the **highest-specificity** contributor (specificity is derived from the
   rule's selector shape — WP4 — *not* a hand-assigned priority integer; this is
   what avoids priority inflation),
3. breaks ties by **source/registration order** (last registered wins, as in
   CSS),
4. writes that winner's local target; every other contribution to that channel is
   **suppressed** (has no effect), exactly like a shadowed CSS declaration.

Because resolution is per channel, a rule that loses `translate-x` to a more
specific rule still wins `colour` if it is the only contributor there — nothing
bundled in a rule is lost just because one of its channels was overruled.

### Postconditions decompose per channel too

A rule only gets to assert over the channels it **won**. If rule A lost
`translate-x` to a more specific rule B, A's postcondition must **not** keep
asserting "element is right of X" — it lost that channel, so that claim is void;
A evaluates only the channels it still owns (e.g. `colour`). This is what keeps
the loser from reporting "unsatisfied" forever on a channel it was overruled on,
and is what makes the loop converge on contested channels: the loser genuinely
stands down *on that channel*, contributing nothing — just like a shadowed CSS
declaration.

### Coupled channels — noted, deferred

Sometimes a rule's channels are not independent ("if I move it right I must also
flip the flag"), so suppressing one channel but not the other could produce an
incoherent mix. We may eventually let a rule declare a **coupled group** of
channels (win them together or not at all). CSS mostly ignores this; we might not
be able to. **We are deferring it**: the first concrete rule that genuinely needs
it is the trigger to design a solution.

## The driver loop (sketch)

```
build tree from data model (WP5 builders)
build absolute-transform/anchor index (top-down, from current transforms)
repeat, up to a bounded iteration count:
    collect contributions:
        for each rule, in dependency order (preconditions):
            for each applicable scope whose preconditions hold:
                emit this rule's local-target contributions, keyed by channel
    resolve the cascade:
        for each channel: pick highest-specificity contribution
                           (tie-break: registration order); suppress the rest
        write the winning local targets into the IR in place
    rebuild the absolute-transform/anchor index   # geometry changed
    evaluate all postconditions (each rule over the channels it won)
    if all satisfied: -> SETTLED, stop
if not settled after the bound:
    emit best-effort tree + diagnostics (do NOT block rendering)
```

### Convergence is the hard part (harder than efficiency)

A relaxation loop can **oscillate**: rule A shoves the accidental left off the
dot, rule B shoves the dot right off the accidental, forever. Two guards:

- **Specificity + per-channel suppression (primary).** Conflicts are resolved by
  the cascade (above), not by a hand-assigned priority integer. Order is *derived*
  from selector specificity, so it does not inflate — no author picks a number.
  A pairwise conflict cannot oscillate because the loser is **suppressed** on the
  contested channel and, per the postcondition rule, stops asserting over it: it
  genuinely stands down rather than shoving back next pass. *Limits:* specificity
  disambiguates *hierarchical* conflicts (general vs. specialization) cleanly, but
  two rules of *equal* specificity over a shared region are **peers** — there the
  registration-order tie-break decides, or the two rules genuinely want to be
  **merged into one**. And concrete specificity depends on WP4 defining what a
  selector *is*; WP3 adopts the mechanism, WP4 makes the metric concrete.
- **Bounded iteration count (always).** Suppression removes *pairwise*
  oscillation, but coupled chains across many rules can still fail to reach a
  fixed point. The loop keeps a hard cap regardless — a non-negotiable backstop
  against non-termination.

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
notehead is touched by the stem, accidental, dot, and collision rules). Each rule
is evaluated only over the **channels it won** in the cascade (a rule suppressed
on a channel makes no claim there). Whole-tree "settled" is the conjunction of
those results. Nothing new is persisted in the WP1 IR. (A forbidden overlap the
engine has no rule for is therefore *not* detected here — the layout can be
"settled but visually wrong"; finding such gaps is the regression harness's job,
not the driver's.)

## Coupling to WP1

- **Absolute-transform/anchor index.** Postconditions and collision checks need
  *absolute* bounding boxes, which are composed **top-down** by free functions
  (no parent pointers — WP1-S1/S5). The driver owns this index, rebuilds it after
  each mutating pass, and passes it to rules. It is pass-local derived data, not
  IR state (see the rewrite-plan WP3 note).
- **Spatial bucketing.** Collision rules that need to find candidate pairs can
  use the IR's existing `Column` / `Measure` / `Staff` nesting as spatial
  buckets, so pair-finding need not be O(n²) across the whole score. (Optimise
  only if measured — rewrite-plan.)
- **Reference resolution (S5).** Deferred-element resolution is one kind of pass
  the driver schedules; its resolvers read the same absolute index. Stem-length-
  extends-to-beam is the canonical case where a deferred resolution writes back
  into an already-placed element's geometry.

## Scope

**In (WP3):**
- The rule execution contract (applicability / precondition / postcondition;
  declarative per-channel `apply`; validator-only flag).
- The channel set and the per-channel cascade (gather → highest-specificity wins
  → suppress the rest → write local targets).
- The pass driver: scheduling by dependency order, the cascade, bounded
  iteration, index rebuild, settled detection, best-effort + diagnostics on
  non-convergence.
- The (rule, scope) settledness report as derived, pass-local data.

**Out:**
- The WP4 selector grammar and the concrete **specificity metric** it induces
  (WP3 adopts the cascade *mechanism* but consumes specificity as a given; only
  the minimal applicability query is needed here).
- The actual music rules (WP5 intra-measure, WP6 context-dependent).
- The catalogue of forbidden-collision pairs + clearances (domain data supplied
  by WP5/WP6 rules; WP3 only runs the checks).

## Resolved

- **Conflict model.** *Decided:* **specificity + per-channel suppression** (see
  "Channels and the cascade"). Order is derived from selector specificity, not a
  hand-assigned priority, which avoids inflation; conflicts resolve per channel by
  suppressing the loser. Residual: equal-specificity *peers* fall back to
  registration order or want merging, and the concrete specificity metric is a
  WP4 dependency. *Considered and set aside:* **monotonic relaxation** (define a
  global "badness" energy and only ever descend) — it guarantees termination by
  construction, but needs a single scalar all heterogeneous constraints reduce
  to, i.e. **constraint weights**, which have the same inflation problem priority
  had and no natural common currency (how many sp of overlap = how many sp of
  misalignment?). Specificity avoids needing a common currency at all. (Damping
  — cap movement per pass — remains on the table as cheap anti-overshoot
  insurance; see below.)

## Open design questions

- **Coupled channels.** When must a rule win/lose a *group* of channels together
  rather than per-channel (e.g. move-right implies flip-flag)? Deferred until the
  first concrete rule needs it (see "Channels and the cascade").
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
