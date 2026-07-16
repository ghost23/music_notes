# WP3-S1 — Rule contract & channel model

## Goal

Define the **vocabulary** the whole driver is built on, before any machinery
runs: the layout-**rule contract** (its three predicates + declarative `apply` +
validator-only flag), the **channel** set (the independently-resolvable slots of
layout output), and the **contribution** value type a rule emits. This story
delivers only interfaces and pure-data types — no cascade, no scheduler, no loop
— exercised by hand-built **fake** rules that assert the contributions they emit.

Everything downstream keys off these types: the cascade (S2) resolves
contributions per channel, the scheduler (S3) reads preconditions, the driver
loop (S4) evaluates postconditions and applies budgets, and diagnostics
(S5/S6) reference the `(rule, scope, channel)` shape. So they are pinned first.

See the [WP3 design reference](./README.md) — "The rule contract", "Rules are
declarative, not imperative", "Validator-only rules", and "Channels and the
cascade" — which this story turns into concrete interfaces, and
[`../code-principle.md`](../code-principle.md).

## Background

The design settled on a **declarative** rule: a rule *declares* the target
value(s) it wants for specific channels rather than mutating nodes imperatively.
The driver owns the write. This story encodes that decision in the types, so it
cannot be violated later: a rule is a function from (scope, absolute geometry) to
a set of channel-keyed **targets**, with no handle to mutate the tree.

The three predicates are kept **separate** deliberately, because each drives
different machinery: applicability filters scopes, preconditions drive
scheduling (S3), postconditions drive convergence (S4). Bundling them would blur
those roles.

## Scope

**In:**

- **The `LayoutRule` contract**, exposing:
  - **Applicability** — a scope query answering "is this rule responsible for
    this context at all?" WP3 needs only a boolean/scope filter over the tree
    (the seed of the WP4 selector concept). It must not run any layout math.
  - **Precondition** — a predicate over current layout state, in **two
    flavours** the type must distinguish, because S3 treats them differently:
    - a **hard gate** — "my input geometry does not exist yet / the element I
      read is not *resolved* (S5)". A real prerequisite; forms a DAG.
    - a **convergence hint** — "I'd compute a better value if B were placed, but
      I can run now and improve next pass". Not a gate.
  - **Postcondition** — a **side-effect-free**, **ε-tolerance** predicate over
    the current tree state ("within tolerance of the required clearance"), never
    exact equality (damping only approaches a target asymptotically). Evaluated
    (in S4) only over the channels the rule **won**.
  - **`apply`** — **declarative**: returns a set of **contributions** (channel →
    local target) for the scope it targets. It never mutates the tree and holds
    no reference that could.
  - A **validator-only flag** — a rule that implements applicability +
    postcondition but **no `apply`** (emits no contributions). It observes and
    reports, never affects layout — the safe path to introduce a rule as a pure
    checker first.
- **The specificity handle.** Each rule exposes an **opaque, comparable**
  specificity token plus its **registration order**. WP3 **adopts** the cascade
  mechanism but consumes specificity *as a given* — the concrete metric is a WP4
  dependency. Provide a trivial placeholder ordering so WP3's own tests can drive
  the cascade (S2) without WP4.
- **The channel enumeration.** A channel is an independently-resolvable slot of
  layout output.
  - **Common to every element:** `translate-x`, `translate-y` (kept **separate**
    — spacing owns x, staff-position owns y), `scale`, `rotation`,
    `glyph-identity` (a discrete choice), and one channel per `Styling` field.
  - **Primitive-specific geometry channels**, declared per primitive type at
    **whole-point** granularity: line → `start`, `end`; rect → `northeast`,
    `southwest`; curve/bezier → endpoints + each control point.
  - Each channel is classified **continuous** (damped in S2) vs
    **discrete/styling** (written directly): `glyph-identity` and `Styling`
    fields are discrete; transform + geometry channels are continuous.
- **The `Contribution` value type** — a `(channel, target)` pair, where the
  target is:
  - expressed in the rule's **local (parent-relative) frame** — the author never
    writes global coordinates; the driver owns local→global composition;
  - a **complete, standalone target**, **never a delta/increment** — the type
    must make a delta *unrepresentable*, so results cannot depend on application
    order and per-channel suppression stays coherent.

**Out:**

- The per-channel cascade / suppression and the write step (S2).
- Scheduling and SCC condensation (S3).
- The concrete **specificity metric** and the selector grammar (WP4) — only the
  minimal applicability query and an opaque specificity handle live here.
- The driver's local→global composition primitives (S4) — the *contract* (rules
  speak local; the driver composes) is stated here; the primitives ship with the
  driver.
- Any real music rule (WP5/WP6) — tests use fakes only.

## Design notes

- **Declarative, not imperative — three reasons** (carry the design doc's
  rationale): less duplicated micro-layout math (pushed into the driver's
  primitives), testable in isolation (assert the contributions a rule emits), and
  **resolvable conflicts** (only channel-keyed targets can be cascaded;
  opaque mutations cannot).
- **Targets, not deltas.** Accumulation *where it is correct domain behaviour*
  (stacking accidentals) is **one rule** reading all participants and computing
  each local target — explicit and centralized — not the cascade summing blind
  deltas. The type forbids the delta path so this stays true.
- **ε-tolerance postconditions.** Because S2's damping only *approaches* a target,
  an exact-equality postcondition would never read "satisfied". The contract
  makes the tolerance band part of the postcondition, not an afterthought.
- **Whole-point geometry channels** keep the channel count in check. The known
  consequence — two rules needing independent x vs y of one point collide on the
  whole-point channel — is the coupled-channels question in miniature and is
  **deferred**; the first concrete rule that needs per-axis control is the
  trigger to revisit (see the design doc).
- **Specificity is consumed, not defined.** Model the handle as an opaque
  comparable + registration order so S2 can select and tie-break without WP3
  committing to a metric. Document clearly that WP4 makes it concrete.

## Acceptance criteria

- [ ] A `LayoutRule` contract exposes applicability, a precondition that
      **distinguishes hard gate from convergence hint**, an ε-tolerance
      side-effect-free postcondition, a declarative `apply` returning
      contributions, and a validator-only flag.
- [ ] The channel set is defined, including per-primitive geometry channels at
      whole-point granularity, and every channel is tagged **continuous** vs
      **discrete/styling**.
- [ ] `Contribution` is a channel-keyed, **local-frame**, **target-only** value;
      a delta/increment is not representable by the type.
- [ ] A rule exposes an opaque, comparable **specificity** handle plus
      registration order, with a placeholder ordering for tests and a doc note
      that the concrete metric is WP4-supplied.
- [ ] Fake rules (including a **validator-only** one) unit-test that `apply`
      emits the expected contributions, that a validator-only rule emits none,
      and that a postcondition evaluates without side effects.
