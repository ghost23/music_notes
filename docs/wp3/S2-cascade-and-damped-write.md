# WP3-S2 — Per-channel cascade & the damped write

## Goal

Implement the CSS-inspired **cascade** and the **write step** it feeds. Given all
the contributions gathered for the applicable scopes in a pass, resolve **each
channel independently** — gather → highest-specificity wins → tie-break by
registration order → **suppress** the rest — then **write** the winning local
targets into the IR **in place**, applying **damping** on continuous channels and
direct writes on discrete/styling channels. Produce a **suppression report**
(who won and who was suppressed, per channel) that S4 uses to scope
postconditions and S5 turns into diagnostics.

This is a pure, self-contained unit: a bag of contributions in → a mutated IR
subtree + a suppression report out. It does **not** decide *which* rules run
(that is the scheduler S3 and the loop S4).

See the [WP3 design reference](./README.md) — "Channels and the cascade",
"The cascade (per-channel suppression)", and "Bound and damping".

## Background

The heart of the conflict model is that rules do **not** fight over whole
elements — they contribute to **channels**, and conflicts are resolved **per
channel**. This is what lets a rule that loses `translate-x` to a more specific
rule still win `colour` if it is the only contributor there: nothing bundled in a
rule is lost because one of its channels was overruled.

Damping is applied by the driver at the **write step, after the cascade** — the
rule still emits a clean, undamped target; the driver moves only part-way toward
it. Doing it here (not in the rule) is precisely what keeps the target-based rule
contract (S1) clean: a rule never expresses a delta.

## Scope

**In:**

- **Per-channel resolution.** For each channel independently: gather all
  contributions to it; pick the **highest-specificity** contributor (using the
  S1 specificity handle); break ties by **registration order** (last registered
  wins, as in CSS); the rest are **suppressed** (have no effect). Because
  resolution is per channel, a rule losing one channel still wins another it
  solely contributes to.
- **In-place write into the IR.** Write the winning **local** targets onto the
  existing nodes — **never** `copyWith`-replace a node that may be a reference
  target (the S5 identity invariant): `translate-x/y` → `NodeTransform`;
  geometry point channels → the primitive's endpoints/control points;
  `glyph-identity` → the leaf's glyph; each `Styling` channel → its field.
- **Damping at write time**, on **continuous** channels only:
  ```
  written = current + 0.4 * (target - current)     # close 40% of the gap per pass
  ```
  This under-relaxation kills overshoot, the leading cause of oscillation. The
  damping factor is a single documented constant (starter **0.4**).
- **Direct write** for **discrete/styling** channels — `Styling` fields and
  `glyph-identity` are written straight to the winning value (there is no "40% of
  the way from flag-up to flag-down").
- **The suppression report** — a pass-local structure keyed by channel recording
  the winning rule and the suppressed rules (and the tie-break reason where one
  applied). It feeds S4's per-channel postcondition scoping and S5's
  suppression/tie-break diagnostics.

**Out:**

- Gathering *which* scopes are applicable and *which* rules' preconditions hold
  (S3 scheduler + S4 loop) — S2 takes a given bag of contributions.
- Postcondition evaluation and the settled test (S4).
- The absolute-transform index rebuild (S4 owns it) — S2 writes local values and
  does not itself need absolute geometry.
- The concrete specificity **metric** (WP4); S2 consumes the S1 handle.

## Design notes

- **Damping at write time keeps the contract clean.** It is applied after the
  cascade selects a winner, so a rule's `apply` never has to know about it and
  never expresses a delta — the two axes (declarative target vs damped write)
  stay orthogonal.
- **Suppression = a shadowed CSS declaration.** The loser contributes nothing on
  the contested channel — this is what (together with the S4 postcondition rule)
  prevents pairwise oscillation. S2 only has to record the suppression; S4 uses
  it to stop the loser asserting.
- **In-place mutation preserves node identity (S5).** Cross-references and the
  absolute-transform index key on Dart object identity, stable only if a pass
  mutates a node's fields rather than replacing it. The write step must mutate.
- **0.4 and 10 are mutually consistent starters.** 0.4 damping over the 10-pass
  budget (S4) closes `1 − 0.6¹⁰ ≈ 99.4%` of a stationary gap, so the two starters
  are at least tuned *together* (both provisional — see the open question).

## Acceptance criteria

- [ ] Each channel resolves **independently**: highest-specificity wins, ties
      break by registration order, the rest are suppressed; a rule losing
      `translate-x` to a more specific rule still wins `colour` when it is the
      sole contributor there.
- [ ] **Continuous** channels are written **damped** (`current + 0.4·(target −
      current)`); **discrete/styling** channels (`glyph-identity`, `Styling`) are
      written directly — verified numerically.
- [ ] Writes mutate nodes **in place**; node identity is stable so
      cross-references and the absolute-transform index still point at the right
      nodes afterward.
- [ ] The cascade produces a **suppression report** listing, per channel, the
      winner and the suppressed contributors.
- [ ] Unit tests with hand-built contributions cover a contested channel, a
      sole-contributor channel, discrete-vs-continuous writes, the tie-break, and
      in-place identity preservation.
