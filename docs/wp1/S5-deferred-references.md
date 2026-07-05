# WP1-S5 — Deferred references for context-dependent elements

## Goal

Let the IR represent an element whose geometry **cannot be computed yet** because
it depends on the final positions of other elements — a slur over notes whose
Y is not yet known, a beam across stems, a tie between noteheads. The element
exists in the tree early, holds **references** to the elements/anchors it depends
on, and is **resolved** in a later layout pass.

This is the structural reason the rewrite exists (see `architecture.md`); WP1
provides only the *mechanism*, not the actual beam/slur math (that is WP6).

## Background

`architecture.md`: "You cannot draw the legato line before you know where its
underlying notes are placed. So you need to be able to create the legato line but
be able to alter it once you have all the other symbols placed."

The multi-pass driver (WP3) will run resolution passes; WP1 must give those
passes something well-defined to operate on.

## Scope

**In:**
- A representation for an element in one of two states:
  - **unresolved** — holds references (to target elements and/or named anchors
    from S4) plus enough intent to resolve later; has no final drawable geometry;
  - **resolved** — has concrete staff-space geometry (primitives) like any other
    element.
- A reference type that can point at another node and, optionally, a named
  anchor on it (reusing S4 anchors), without copying that node's data.
- A clear, queryable way to find unresolved elements in a tree (so WP3's pass
  driver can iterate them) — via a free traversal function.
- Defined behaviour for an unresolved element encountered by geometry/render
  functions: it is **not drawable**; attempting to treat it as resolved
  **throws** (exceptions-over-null).

**Out:**
- The actual resolution logic for beams/slurs/ties/dynamics (WP6).
- The pass scheduler / convergence detection (WP3).
- Persisting references across re-layout / serialization.

## Design notes

- Prefer modelling resolution as a **free function** `resolve(unresolved, tree)
  → resolved element`, keeping the unresolved node as pure data holding intent +
  references. This matches the functional principle and keeps WP6 rules testable.
- References should be stable identifiers/handles, not deep copies, so that when
  a target moves the reference still points at the right node. Decide and
  document the identity scheme (e.g. node identity vs. an explicit id field).
- Avoid leaking partial geometry: an unresolved node must be impossible to
  mistake for a resolved one (distinct type/state, checked by traversal/render).
- Keep the dependency direction explicit and acyclic where possible; document
  what happens if a reference target is itself unresolved.
- **How a reference obtains a target's *absolute* geometry.** IR nodes carry no
  parent link (by design — see S1: absolute geometry is composed **top-down** by
  free functions that thread `parentAbsolute` down the walk, not by walking up).
  A deferred element therefore cannot start from a referenced notehead and
  accumulate its ancestor transforms. The resolver must instead consume an
  **absolute-transform/anchor index built by a single top-down pass** — e.g. a
  `Map<Element, Matrix4>` (or resolved-anchor cache) keyed by node identity —
  and read each target's absolute position from it. Do **not** re-search from the
  root per reference (O(n·m)), and do **not** add parent pointers to work around
  it (that turns the tree into a cyclic graph and breaks the pure-data / free-
  function principle). This index is the contract between WP3's pass driver and
  the resolvers.
- **Node identity must stay stable across passes.** References and the index
  above are keyed by node identity, so a layout pass must **mutate a node's
  `transform` in place** rather than `copyWith`-replacing the whole node —
  replacing a node silently breaks every reference and index entry pointing at
  it. `Element` is intentionally mutable to allow this; keep it that way for
  nodes that can be reference targets.

## Acceptance criteria

- [ ] The IR can hold an element in an explicit **unresolved** state carrying
      references to other elements and (optionally) their named anchors (S4).
- [ ] A free traversal function returns all unresolved elements in a tree, in a
      deterministic order, for a pass driver to consume.
- [ ] Geometry/render of an unresolved element is impossible by construction or
      **throws** a descriptive exception — it never silently yields empty/zero
      geometry.
- [ ] A documented identity/reference scheme explains how a reference keeps
      pointing at the correct node after that node's transform changes.
- [ ] Unit tests cover: building an unresolved element with references;
      traversal finding it; and the throw-on-unresolved-geometry path.
- [ ] No beam/slur/tie math is implemented here (correctly deferred to WP6); the
      story delivers only the mechanism, demonstrated with a trivial fake
      resolver in tests.
