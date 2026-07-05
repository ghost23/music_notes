# WP1-S1 — Staff-space transform model + geometry as free functions

## Goal

Give every IR node (`Element` and its subclasses in `lib/graphics/graphics_model/canvas_primitives.dart`)
an explicit **transform** (translation, scale, rotation)
expressed in **staff-space units**, and split geometry functionality along
the right seam: a node's **local** extent may be a getter/method (derived purely from its own
fields), while **absolute** geometry that composes ancestor transforms is a
**free function** walking the tree.

After this story, an `Element` is a node positioned by a transform that can
report its own local bounds, and a free function can compute any subtree's
absolute extent.

## Background

Today (`lib/graphics/graphics_model/canvas_primitives.dart`):

- nodes carry only a single `Offset pointOfOrigin` — translation only, no scale
  or rotation;
- `boundingBox` is a getter that mixes *local* extent with cross-tree concerns.
  A local-extent getter is fine to keep; the part that needs ancestor transforms
  (absolute placement) belongs in a free function.

The architecture requires scale and rotation (e.g. a rotated beam, a scaled
glyph) and the coordinate decision (see `rewrite-plan.md`) requires staff-space
units throughout.

## Scope

**In:**
- A transform value type (translation `Offset`, uniform or x/y `scale`,
  `rotation`) with a documented convention. Reuse Flutter/`vector_math`
  (`Matrix4`/`Matrix3`) if it fits cleanly — check before hand-rolling.
- Each `Element` carries a transform field (replacing bare `pointOfOrigin`).
- A node's **local** bounding box may be a getter/method (derived purely from
  its own fields — e.g. a group folding its children's local boxes).
- Free functions (in a new `layout/geometry.dart` or similar):
  - compose a node's transform with its ancestors' to get an absolute transform;
  - compute the **absolute** (transform-composed) bounding box of a node/subtree.
- Documented statement that all numbers are staff-space units (1 staff space =
  the SMUFL unit; 4 staff spaces = 1 staff height = 1 em).

**Out:**
- Removing `Paint`/`TextStyle` (that is S2).
- Anchors (S4), semantic node types (S3), multi-staff containers (S6).
- Any rendering or pixel conversion.

## Design notes

- A getter/method is appropriate for the **local** bounding box (pure derived
  data from the node's own fields). Anything that needs ancestor transforms or
  external lookups (glyph metadata, the rest of the tree) is a free function.
- Free functions take the node (and its children/metadata) as parameters — no
  global state, no hidden lookups — so they unit-test with hand-built trees.
- Prefer exceptions over null for malformed input (e.g. NaN transform).
- Keep the value type small and immutable; provide a `copyWith`-style method on
  the model for producing modified copies (allowed by the principles).

## Acceptance criteria

- [ ] Every `Element` has a transform supporting translation, scale and rotation
      in staff-space units; the bare `pointOfOrigin`-only model is gone.
- [ ] **Absolute**/transform-composition logic lives in free functions, not in
      `Element` subclasses; a *local* bounding-box getter/method is permitted
      (pure derived data).
- [ ] A node can report its **local** bounding box.
- [ ] A free function returns the **absolute** bounding box of a subtree with
      nested transforms (translation + scale + rotation) composed correctly.
- [ ] Unit tests cover: identity transform; nested translation; scale; rotation;
      and a mixed nested case, each asserting expected staff-space coordinates.
- [ ] A short doc comment defines the unit and the transform convention
      (axis directions, rotation sign, order of operations).
- [ ] Project compiles; existing render code still builds (adapter shim is
      acceptable and will be cleaned up in WP2).
