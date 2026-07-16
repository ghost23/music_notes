# WP3-S5 — Diagnostics: record schema, driver emission & JSONL sink

## Goal

Make the driver's problems **reportable**. Because the driver **never blocks
rendering** (best-effort output always — S4), a problem that is not *reported*
becomes invisible. This story defines the **structured diagnostic record schema**
(the single source of truth), has the driver **emit** records at the S4 hooks
(non-convergence, budget exhaustion, cascade-suppression traces, tie-break
notices), and ships a **JSON/JSONL file sink** via `package:logging`. Automated
tests assert on the **structured records**, never on formatted log text.

See the [WP3 design reference](./README.md) — "Diagnostics", "The record schema
(WP3 owns this)", and "What WP3 emits and ships".

## Background

Diagnostics are the driver's structured output *besides* the laid-out tree, and
the **primary feedback loop** for authoring rules. The governing discipline is
**one structured source of truth, multiple sinks** — the same discipline as
"settled is derived, not stored". The file dump (this story) and the visual
overlay (S6) are both *sinks* that render the same records. Keeping the source of
truth structured is what lets tests assert on it directly instead of parsing
text.

The `(rule, scope)` settledness report and the emission hooks come from S4; this
story defines the richer **record** artifact those hooks feed, and the first
sink.

## Scope

**In:**

- **The record schema** (WP3 owns it). Each diagnostic record carries:
  - the **`(rule, scope, channel)`** key it pertains to (channel optional);
  - a **severity** mapping onto `package:logging` levels — non-convergence and
    validator flags → `WARNING`; suppression/tie-break traces → `FINE`;
  - a **residual** where meaningful (e.g. "0.3sp short of the required
    clearance");
  - a **location/bbox**, taken **for free** from the absolute-transform index the
    driver already maintains (S4), so records carry spatial position with no
    renderer involved;
  - an **opaque, typed rule-payload hook** carrying `categories / measurements /
    positions / labels`. The driver does **not** interpret it — it just carries
    it to the sinks. This is where a rule's own categorized diagnostics will live
    (populated by WP5/WP6).
- **Driver-level emission** at the S4 hooks: **non-convergence** (a `(rule,
  scope)` that spent its action budget with its postcondition unsatisfied),
  **budget exhaustion**, **cascade-suppression traces**, and
  **peer/registration-order tie-break** notices — each with the correct severity.
- **A JSON/JSONL file sink** via `package:logging` (a small hand-written
  `onRecord` handler — the package has no built-in file output). One JSON record
  per line, so the regression harness reads it parse-stably.
- Structured records (or the JSONL) are the **test oracle**; free-form log text
  is never asserted on (it is brittle).

**Out:**

- The **generic visual overlay renderer** (S6) — the second sink, consuming this
  same schema.
- The **rule-contributed content** of the payload hook (the actual width
  categories, clearances, …) — that arrives with the rules in **WP5/WP6**; S5
  ships the hook and exercises it with **synthetic** content in tests.
- Any gate on rendering — diagnostics **report**, never block (S4).
- CI wiring for where the JSONL lands in a pipeline — a later concern.

## Design notes

- **Structured source of truth → direct assertions.** Tests inspect the record
  objects (or one-record-per-line JSONL), never scraped log strings. This is the
  same rationale as the WP2-S5 harness asserting on pixels via a golden rather
  than on prose.
- **The bbox is free.** The driver already maintains the absolute-transform index
  each pass (S4); reading a record's location from it costs nothing and needs no
  renderer — keep that dependency direction (diagnostics read the index; they do
  not compute geometry).
- **The payload hook is opaque and typed.** The driver carries
  `(categories, measurements, positions, labels)` verbatim to the sinks and never
  branches on their meaning. This is what lets S6 be semantically agnostic and
  lets WP5/WP6 add categories without touching the driver.
- **Severity mapping is deliberate**, so a sink can filter (a `WARNING`-only view
  for real problems; `FINE` for the suppression/tie-break trace when debugging a
  cascade).

## Acceptance criteria

- [ ] A diagnostic **record schema** exists with the `(rule, scope, channel?)`
      key, a `package:logging` **severity**, an optional **residual**, a **bbox**
      sourced from the absolute index, and an **opaque typed payload hook**
      (`categories/measurements/positions/labels`).
- [ ] The driver **emits** records for non-convergence, budget exhaustion,
      cascade suppression, and tie-breaks, each with the correct severity.
- [ ] A **JSONL file sink** (via `package:logging`) writes one parse-stable JSON
      record per line.
- [ ] Tests assert on the **structured records** (and/or the JSONL), not on
      free-form text; a non-convergent fake fixture produces the expected
      `WARNING` record carrying its residual and bbox.
