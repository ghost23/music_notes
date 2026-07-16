# WP3-S7 — Capstone: driver end-to-end with fake rules

## Goal

Prove the **whole driver** end-to-end on a **hand-built** fixture, driven by a
small set of **fake-but-representative** rules, before any real WP5/WP6 rule
exists. This is the WP3 analogue of WP1-S7 (contract proven on a hand-built
multi-staff example) and WP2-S4/S5 (that fixture rendered and locked behind a
golden): it demonstrates that the rule contract (S1), the cascade (S2), the
scheduler (S3), the loop (S4), and the diagnostics toolset (S5/S6) compose into a
working engine.

The capstone reuses the WP1-S7 grand-staff fixture and drives it with toy rules
that exercise every driver mechanism: the settle loop, per-channel cascade
resolution on a contested channel, cross-tree resolution, the `(rule, scope)`
settledness report, and both diagnostics sinks (JSONL + overlay).

See the [WP3 design reference](./README.md) — "Collisions are rules, not a
privileged global algorithm", "Validator-only rules", and "Scope".

## Background

WP3 has **no** real music rules (WP5/WP6) and does **not** build the IR from a
parsed `Score` (WP5 builders). So the capstone, like WP1-S7 and WP2-S4, works on a
**hand-built** IR — the shared `buildWp1ContractFixture()` grand staff — plus
**fake** rules written only to drive the engine. The rules are deliberately toy:
they are *not* engraving-correct; they exist to exercise each driver mechanism on
a realistic tree.

"Everything is a rule" is demonstrated here: a **collision** (accidental vs
augmentation dot) is handled by an ordinary rule with the same
applicability/precondition/postcondition/apply shape, not a privileged global
algorithm — and it follows the **validator-only → emitting** promotion path (a
pure checker first, watched across the fixture, then allowed to move symbols).

## Scope

**In:**

- **A capstone harness** that reuses `buildWp1ContractFixture()` (no new tree)
  and registers a handful of **fake rules** exercising:
  - a **horizontal-spacing** rule owning `translate-x`;
  - a **staff-position** rule owning `translate-y`;
  - a **stem-length-extends-to-beam** resolution — a deferred resolution writing
    an already-placed element's geometry channel via the absolute index
    (the canonical cross-tree hand-off);
  - an **accidental-vs-augmentation-dot collision** rule.
- **The validator-only → emitting promotion path** on the collision rule: run it
  **validator-only** first (it emits diagnostic records, moves nothing), then
  enable its `apply` so it moves the accidental within tolerance.
- **A contested channel**: two rules both contributing `translate-x` to one
  element, resolved by specificity + suppression, with the loser standing down
  (no oscillation).
- **End-to-end run:** driver settles (or degrades gracefully) → the
  `(rule, scope)` settledness report → **JSONL** diagnostics → a **diagnostics
  overlay golden** (via the WP2-S5 harness).

**Out:**

- **Real engraving correctness** and the **real** rules (WP5/WP6) — the capstone
  rules are toys that drive the engine, not a spacing/collision implementation.
- Building the IR from a parsed `Score` (WP5 builders).
- **Tuning** the `10` / `0.4` starters — the capstone may *observe* convergence
  behaviour to inform the open tuning question, but does not tune.
- **Spatial bucketing** of the collision pair-finding — the fixture is small
  enough not to need it; noted as the place it *could* appear, kept deferred.

## Design notes

- **Fakes are representative, not correct.** Each fake rule is chosen to exercise
  a distinct driver mechanism (an x-owner, a y-owner, a cross-tree resolution, a
  collision + validator path). Correct engraving is explicitly WP5/WP6.
- **Reuse the WP1/WP2 assets.** Import `buildWp1ContractFixture()` and drive the
  overlay golden through the WP2-S5 harness — no second fixture, no duplicated
  render/golden setup (per `../code-principle.md` and the WP2-S5 "one fixture,
  shared" note).
- **The collision rule is the "everything is a rule" demonstrator.** It shows a
  forbidden-clearance case handled with the ordinary rule shape and the
  validator-first safety path — not a special global collision pass.
- **Settled but visually wrong is possible and expected.** A forbidden overlap
  the fake rule set has no rule for is *not* detected by the driver (the layout
  can be "settled but visually wrong"); finding such gaps is the regression
  harness's job, not the driver's. The capstone documents this boundary rather
  than trying to close it.

## Acceptance criteria

- [ ] The driver runs the WP1-S7 fixture with the fake rule set and reaches
      **settled** (or degrades gracefully with diagnostics).
- [ ] A **contested** `translate-x` resolves by specificity + suppression; the
      loser **stands down** (no oscillation across passes).
- [ ] **Stem-length-extends-to-beam** resolves **cross-tree** via the absolute
      index (an already-placed element's geometry is rewritten).
- [ ] The **collision** rule runs **validator-only** first (emits records, moves
      nothing), then **emitting** (moves the accidental within tolerance).
- [ ] The `(rule, scope)` **settledness report** and **JSONL** diagnostics are
      produced, and a **diagnostics overlay golden** is committed via the WP2-S5
      harness.
- [ ] The full WP1 + WP2 + WP3 suite passes and `flutter analyze` is clean.
