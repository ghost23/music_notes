import 'package:flutter_test/flutter_test.dart';
import 'package:music_notes_2/graphics/generated/glyph_advance_widths.dart';
import 'package:music_notes_2/graphics/generated/glyph_definitions.dart';
import 'package:music_notes_2/graphics/layout/glyph_metadata.dart';

/// Unit tests for the parameterised per-glyph advance-width reader (WP1-S3).
///
/// Per the glyph-knowledge contract, per-glyph metadata is **never copied** onto
/// a node; it is read on demand via free functions that take the metadata table
/// as a **parameter** (the S4 testability rule). Advance width is surfaced in
/// WP1 here (decided in S3, called out in the doc) as a spacing **input** a
/// layout rule may override — not the final gap.
void main() {
  group('glyphAdvanceWidth', () {
    test('returns the generated table value for a known glyph', () {
      // gClef is a well-known glyph with an advance width in the generated table.
      final expected = glyphAdvanceWidths[Glyph.gClef]!;
      expect(expected, isNot(isNull));
      expect(glyphAdvanceWidth(Glyph.gClef), expected);
    });

    test('reads from an explicitly supplied (hand-built) table — no global state', () {
      final fakeTable = {Glyph.gClef: 9.75};
      expect(glyphAdvanceWidth(Glyph.gClef, advanceWidths: fakeTable), 9.75);
    });

    test('a different glyph reads a different value from the supplied table', () {
      final fakeTable = {Glyph.gClef: 9.75, Glyph.fClef: 7.0};
      expect(glyphAdvanceWidth(Glyph.fClef, advanceWidths: fakeTable), 7.0);
    });

    test('throws ArgumentError when the glyph is absent from the supplied table', () {
      // A missing advance width is a programmer/usage error, not a recoverable
      // condition (exceptions-over-null).
      expect(
        () => glyphAdvanceWidth(Glyph.gClef, advanceWidths: const {}),
        throwsArgumentError,
      );
    });
  });

  group('glyphAdvanceWidth contract: never copied, an input not the gap', () {
    test('returns a staff-space scalar (the isolated glyph advance)', () {
      // The value is a per-glyph fact in staff-space units — a *hint* the WP5
      // spacing rule consumes. The rule may widen/tighten/ignore it, so this
      // is not asserted as "the gap" here, only as the per-glyph input.
      final w = glyphAdvanceWidth(Glyph.noteheadBlack);
      expect(w, isA<double>());
      expect(w, greaterThan(0));
    });
  });
}
