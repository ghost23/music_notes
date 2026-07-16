# WP3-S3 — Rule scheduler: precondition graph & SCC condensation

## Goal

Decide the **order** in which rules are asked to act within a pass, derived from
their **preconditions**. Build the precondition dependency graph, condense it into
its **strongly-connected components** (a DAG of SCCs), run the SCCs in
**topological order** (hard gating between them), and iterate the members of an
SCC in a fixed **registration order** each pass. The distinction that makes this
safe: only **hard gates** create edges; **convergence hints** do not — so a
data-flow cycle (beam↔stem) is scheduled every pass and relaxed by the loop
rather than deadlocking.

See the [WP3 design reference](./README.md) — "Dependency cycles are handled by
iteration, not feared", and the two precondition flavours under "The rule
contract".

## Background

Preconditions depend on **layout output**, not on *building*: WP5 builds the whole
tree up front, so every element already exists when the driver runs. A
precondition says "the layout state I consume is ready" — rule A reads a channel
that rule B writes. Two rules can therefore genuinely form a **cycle** (stem
reads the beam's placed position; beam-placement reads the stems' lengths). That
is a real, classic engraving coupling — a coupled fixed point the relaxation loop
already solves — **not** a deadlock.

A cycle only deadlocks if **both** edges are modelled as **hard gates**, so
neither rule ever starts. Hence the scheduler's core job is to build edges *only*
from hard gates (which form a DAG by construction, since S5 resolution is a DAG)
and to leave convergence hints out of the graph entirely.

## Scope

**In:**

- **Build the precondition graph.** Add an edge A→B when A **hard-gates** on B's
  output ("A's input geometry does not exist / the element A reads is not
  resolved per S5 until B has run"). Read the hard-gate-vs-hint flag from the S1
  contract.
- **Convergence hints create no edges.** Both endpoints of a hint run **every
  pass**; the loop (S4) relaxes them. A precondition that *would* create a cycle
  is the signal that a convergence coupling was mis-modelled as a gate.
- **Condense into SCCs.** Produce the DAG of strongly-connected components
  (check pub.dev for a small, well-tested graph/SCC package before writing
  Tarjan by hand — per the reuse principle).
- **Order.** **Topological** order **between** SCCs (hard gating runs in
  dependency order); a fixed **registration** order **within** an SCC (there is
  no order inside a cycle, so run members in a stable order each pass and let the
  loop converge them).
- **Distinguish a genuine deadlock from a benign cycle.** An SCC arising from a
  cycle of **hard gates** is a construction error (a mis-modelled hint) and must
  be **reported**, not silently accepted. An SCC that exists only because of
  convergence couplings is benign (and, since hints add no edges, will not even
  appear as an edge-induced cycle — this criterion guards against a rule
  *declaring* a hard gate that closes a loop).

**Out:**

- Actually running rules / collecting contributions and applying the cascade
  (S4 + S2).
- The relaxation loop, the action budget, and damping (S4/S2).
- **Merging** an SCC into a single rule — that is a *modelling* escape hatch
  (used when a coupling must be single-pass-consistent, or an SCC converges badly
  in practice), documented here as an option but **not** performed by the
  scheduler.
- The S5-WP1 *resolution*/building DAG — rules do not build, so they cannot
  create a hard *resolution* cycle (that is a WP1/builder invariant, out of
  scope).

## Design notes

- **Gate only on hard prerequisites.** The whole safety argument rests on hard
  gates forming a DAG (input-exists / resolved-per-S5) and convergence couplings
  being expressed as hints. Encode this so the graph literally cannot contain a
  hint edge.
- **The scheduler never deletes an edge.** It condenses; it does not break cycles
  by dropping dependencies. Within an SCC it *orders arbitrarily but stably*; it
  does not pretend a dependency is absent.
- **Prefer an existing graph package.** SCC condensation + topological sort is a
  solved problem; only hand-roll if no suitable pub.dev package exists (per
  `../code-principle.md`).
- **Registration order is the stable within-SCC key** — the same tie-break the
  cascade (S2) uses for equal-specificity peers, so the two are consistent.

## Acceptance criteria

- [ ] The precondition graph is built from **hard gates only**; convergence hints
      produce **no** edges.
- [ ] SCC condensation yields a DAG; SCCs run in **topological** order, members
      **within** an SCC in **registration** order.
- [ ] A beam↔stem coupling expressed as **hints** produces no edge and no
      deadlock — both rules are scheduled every pass.
- [ ] A cycle of **hard gates** is detected and **reported** as a construction
      error (a mis-modelled hint), rather than silently accepted.
- [ ] Unit tests cover: a linear DAG order, a diamond, a hint cycle (no
      deadlock), and a hard-gate cycle (reported).
