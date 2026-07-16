# WP3-S4 — The pass driver loop (the settle spine)

## Goal

The heart of WP3. Given an **already-built** IR root and a registered set of
rules, run layout **passes until the layout settles** or every `(rule, scope)`
action budget is spent, then hand a **best-effort** tree to the renderer. Each
pass: (re)build the absolute-transform/anchor index, collect contributions in
scheduler order (S3) from applicable scopes whose preconditions hold and whose
per-`(rule, scope)` budget is not exhausted, run the S2 cascade + damped write,
rebuild the index, evaluate all postconditions **over the channels each rule
won**, and test **settled**. Non-convergence **degrades gracefully** — best-effort
output plus a diagnostics hook — and never blocks rendering.

This story ties S1–S3 together into the driver loop and owns the convergence
guarantees. Building the IR from a real `Score` is **WP5** (builders); WP3 drives
an existing IR tree (a hand-built fixture, e.g. the WP1-S7 grand staff).

See the [WP3 design reference](./README.md) — "The driver loop (sketch)",
"Convergence is the hard part", "Bound and damping", "Where 'settled' state
lives", and "Non-convergence must degrade gracefully".

## Background

The driver computes **no** music geometry. It builds nothing, decides nothing
about which pairs must clear — it only schedules rules, feeds them derived data
(absolute geometry via the index), resolves their contributions (S2), detects
when the layout has settled, and emits a best-effort tree. All the geometry
values come from the rules.

Convergence — not efficiency — is the hard part. A relaxation loop can
**oscillate** (A shoves the accidental left off the dot, B shoves the dot right
off the accidental, forever). Three guards, layered: per-channel **suppression**
(S2) kills pairwise oscillation, the **action budget** (here) guarantees
termination for coupled chains, and **damping** (S2) kills overshoot.

## Scope

**In:**

- **Own the absolute-transform/anchor index.** Reuse the existing S5 free
  functions (`absoluteTransformIndex` in `layout/cross_references.dart`),
  extending them for the absolute **bounding boxes / anchors** that postconditions
  and collision checks need. Rebuild it **fresh** after each mutating pass
  (O(n)); it is **pass-local derived data**, never stored on nodes.
- **The pass loop**, per the design sketch: repeat until settled or all
  `(rule, scope)` pairs are frozen — collect contributions (scheduler order,
  applicable + preconditions-hold + budget-not-exhausted), resolve the cascade
  and write (S2), rebuild the index, evaluate postconditions, stop if all
  satisfied.
- **The per-`(rule, scope)` action budget** (starter **10**). Each pair may act
  at most 10 times; decrement on emit; a pair that exhausts its budget is
  **frozen** (emits no further contributions) but its postcondition is **still
  evaluated** for the settled report and diagnostics. Because total actions ≤
  10 × (number of pairs) is finite, this **alone guarantees termination** — no
  separate global pass counter.
- **Postcondition evaluation over won channels.** Consume S2's suppression report
  so each rule asserts only over the channels it **won**; a rule suppressed on a
  channel makes **no claim** there (this is what makes contested channels
  converge — the loser genuinely stands down).
- **Settled detection.** Derived each pass as the conjunction of all
  `(rule, scope)` postconditions (each over its won channels, within ε). Store it
  as the driver-owned, **pass-local (rule instance, scope) settledness report** —
  nothing persisted on the WP1 nodes.
- **Graceful degradation.** If budgets exhaust while unsettled, emit the current
  best-effort geometry plus a diagnostics hook (records defined in S5) and let the
  renderer draw it. "Unsettled" is a **quality/convergence signal, not a gate on
  output** — contrast S5's `isResolved`, which *is* a hard render gate.
- **Integration.** Drive S3's ordering and S2's cascade/write from inside the
  loop; expose the emission hooks S5 attaches sinks to.

**Out:**

- Building the IR from a parsed `Score` (WP5 builders) — the driver takes a root.
- The diagnostic **record schema** and its **sinks** (S5) — S4 exposes the
  settledness report and emission hooks; S5 defines the records and file sink.
- The **real** music/collision rules and the catalogue of forbidden pairs
  (WP5/WP6); tests use fakes.
- **Spatial bucketing** of collision pair-finding via `Column`/`Measure`/`Staff`
  — noted as available (rules may use the IR nesting as buckets) but an
  optimisation to apply only if measured; not built here.

## Design notes

- **Rebuild fresh, don't cache.** Absolute positions are a pure function of
  current transforms; rebuilding the index each mutating pass means it can never
  be stale. This is *why* we prefer it over cached absolutes or parent pointers
  (which demand careful invalidation). Dirty-tracking is deferred until profiled.
- **The three guards are layered, not alternatives.** Suppression (S2) removes
  pairwise oscillation; the budget (here) bounds coupled chains and guarantees
  termination; damping (S2) removes overshoot. The loop relies on all three.
- **Settled ≠ resolved.** A node can be *resolved* (geometry built, S5) but not
  yet *settled* (a rule might still tweak it). The former gates **drawing**; the
  latter gates **convergence**. Keep them distinct; never persist either as a
  node flag that could lie after a later mutation.
- **Validator-only rules** (S1) participate: their postconditions feed the
  settled report and diagnostics, but they emit no contributions and consume no
  budget on the write side.
- **Cross-tree resolution is a scheduled pass.** The canonical
  stem-length-extends-to-beam hand-off — a deferred resolution writing an
  already-placed element's geometry channel — runs through the same index and
  the same cascade, not as a special case.

## Acceptance criteria

- [ ] The driver converges a hand-built fixture driven by fake **convergent**
      rules; "settled" is detected; the absolute index is rebuilt after each
      mutating pass and is never stored on nodes.
- [ ] An **oscillating** pair terminates (via suppression) and a **coupled
      chain** terminates (via the budget); when still unsettled at the end, a
      **best-effort** tree is emitted rather than an error.
- [ ] The per-`(rule, scope)` action budget is enforced (≤ 10); a **frozen** pair
      emits nothing further, yet its postcondition is still evaluated.
- [ ] Postconditions are evaluated **only over the channels each rule won**,
      verified against S2's suppression report (a suppressed rule makes no claim).
- [ ] The **(rule instance, scope) settledness report** is derived pass-locally;
      no settled/resolved state is persisted on WP1 nodes.
- [ ] Cross-tree resolution works: a deferred resolution (stem→beam) writes an
      already-placed element's geometry channel via the index.
- [ ] Unit tests cover convergent, oscillating, budget-exhaustion, validator-only,
      and graceful-degradation paths.
