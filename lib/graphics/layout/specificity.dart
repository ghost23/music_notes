/// An opaque, comparable handle ranking a layout rule for the cascade
/// (WP3-S1).
///
/// The cascade (S2) resolves per-channel conflicts by **specificity**: the
/// highest-specificity contribution to a channel wins; ties break by
/// registration order (last registered wins, as in CSS). This is what avoids
/// the priority-inflation problem a hand-assigned integer priority causes —
/// order is *derived* from selector specificity, not picked by an author.
///
/// ## WP3 consumes, WP4 defines
///
/// WP3 **adopts the cascade mechanism** but consumes specificity *as a given*:
/// the concrete metric is a WP4 dependency (it is derived from the selector
/// grammar, which WP4 owns). WP3 ships only the handle here — a comparable
/// token plus a registration order — so S2 can select and tie-break without WP3
/// committing to a metric.
///
/// [Specificity] is therefore deliberately an *opaque* comparable: a placeholder
/// [rank] lets WP3's own tests drive the cascade (S2) before WP4 exists. A real
/// selector-derived specificity (WP4) will replace the placeholder while
/// keeping this same interface, so the cascade never depends on the concrete
/// metric.
class Specificity implements Comparable<Specificity> {
  /// Creates a placeholder specificity with the given integer [rank].
  ///
  /// Higher [rank] = more specific. **Test/placeholder only** — a real
  /// specificity is derived from a selector (WP4); this constructor exists so
  /// WP3's own tests can drive the cascade without WP4. Two specificities with
  /// the same [rank] are *peers* and fall back to registration order
  /// (see [Specificity] class doc and `docs/wp3/README.md` — "Convergence is
  /// the hard part").
  const Specificity(this.rank);

  /// The placeholder ordering rank. Higher is more specific.
  final int rank;

  @override
  int compareTo(Specificity other) => rank.compareTo(other.rank);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Specificity && other.rank == rank);

  @override
  int get hashCode => Object.hash(Specificity, rank);

  @override
  String toString() => 'Specificity($rank)';
}
