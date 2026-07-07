import 'dart:ui' show Color, Offset, Path, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:music_notes_2/graphics/generated/glyph_definitions.dart';
import 'package:music_notes_2/graphics/graphics_model/canvas_primitives.dart';
import 'package:music_notes_2/graphics/graphics_model/styling.dart';
import 'package:music_notes_2/graphics/graphics_model/transform.dart';

/// Unit tests for the scale-free presentational styling of the IR (WP1-S2).
///
/// The IR carries only scale-free styling: a stroke/fill [Color] (a plain ARGB
/// value with no pixel units) and a staff-space stroke thickness. There is no
/// separate fill-vs-stroke intent — intent is derived from which colors are set
/// ([Styling.hasStroke] / [Styling.hasFill]). No `Paint`/`TextStyle` and no
/// pixel values are stored on the model.
void main() {
  group('Styling.inherit', () {
    test('every field is unset (unresolved)', () {
      const s = Styling.inherit;
      expect(s.strokeColor, isNull);
      expect(s.fillColor, isNull);
      expect(s.strokeWidth, isNull);
      expect(s.isInherit, isTrue);
      expect(s.hasStroke, isFalse);
      expect(s.hasFill, isFalse);
    });

    test('is the default for every Element subclass', () {
      // Construct each leaf type without passing styling.
      final rect = RectElement(const NodeTransform.identity(), const Rect.fromLTWH(0, 0, 1, 1));
      final line = LineElement(const NodeTransform.identity(), Offset.zero, const Offset(1, 1));
      final path = PathElement(const NodeTransform.identity(), _unitPath());
      final glyph = GlyphElement(const NodeTransform.identity(), Glyph.fourStringTabClef);
      for (final element in [rect, line, path, glyph]) {
        expect(element.styling, Styling.inherit);
        expect(element.styling.isInherit, isTrue);
      }
    });
  });

  group('fill-vs-stroke intent derived from color presence', () {
    test('strokeColor only → hasStroke, not hasFill', () {
      const s = Styling(strokeColor: Color(0xFF000000), strokeWidth: 0.13);
      expect(s.hasStroke, isTrue);
      expect(s.hasFill, isFalse);
    });

    test('fillColor only → hasFill, not hasStroke', () {
      const s = Styling(fillColor: Color(0xFFFF0000));
      expect(s.hasFill, isTrue);
      expect(s.hasStroke, isFalse);
    });

    test('both colors → stroke + fill', () {
      const s = Styling(
        strokeColor: Color(0xFF000000),
        fillColor: Color(0xFFFF0000),
        strokeWidth: 0.13,
      );
      expect(s.hasStroke, isTrue);
      expect(s.hasFill, isTrue);
    });

    test('neither color → unresolved (inherit)', () {
      const s = Styling(strokeWidth: 0.13);
      expect(s.hasStroke, isFalse);
      expect(s.hasFill, isFalse);
    });
  });

  group('Styling fields', () {
    test('holds a stroke and a fill color independently', () {
      const s = Styling(
        strokeColor: Color(0xFF000000),
        fillColor: Color(0xFFFF0000),
      );
      expect(s.strokeColor, const Color(0xFF000000));
      expect(s.fillColor, const Color(0xFFFF0000));
      expect(s.isInherit, isFalse);
    });
  });

  group('Styling.copyWith', () {
    test('overrides only the supplied fields', () {
      const base = Styling(
        strokeColor: Color(0xFF111111),
        fillColor: Color(0xFF222222),
        strokeWidth: 0.13,
      );
      final copy = base.copyWith(strokeWidth: 0.5);
      expect(copy.strokeColor, const Color(0xFF111111));
      expect(copy.fillColor, const Color(0xFF222222));
      expect(copy.strokeWidth, 0.5);
    });

    test('returns a new instance (immutability)', () {
      const base = Styling(strokeWidth: 0.13);
      final copy = base.copyWith(strokeWidth: 0.5);
      expect(identical(base, copy), isFalse);
      expect(base.strokeWidth, 0.13); // original untouched
    });
  });

  group('scale-free boundary on GlyphElement', () {
    test('a glyph carries the SMUFL identity and scale-free styling only', () {
      final element = GlyphElement(
        const NodeTransform.identity(),
        Glyph.fourStringTabClef,
        styling: const Styling(fillColor: Color(0xFFFF0000)),
      );
      expect(element.glyph, Glyph.fourStringTabClef);
      expect(element.styling.fillColor, const Color(0xFFFF0000));
    });
  });
}

Path _unitPath() {
  final p = Path()..moveTo(0, 0)..lineTo(1, 0)..lineTo(1, 1)..close();
  return p;
}
