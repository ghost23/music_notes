import 'package:flutter_test/flutter_test.dart';
import 'package:music_notes_2/graphics/render/render_scale.dart';

/// Unit tests for the single render scaling measure ([RenderScale]).
///
/// These pin the conversions as correct functions of the measure —
/// independent of any real canvas — and the validation contract. The
/// scale-the-canvas-once strategy means the renderer applies
/// [RenderScale.pixelsPerStaffSpace] as one root canvas scale and draws glyphs
/// at the staff-space em size; these tests assert the numeric relationships
/// that conversion rests on.
void main() {
  group('RenderScale definition', () {
    test('1 em = 4 staff spaces, stated once', () {
      expect(RenderScale.staffSpacesPerEm, 4);
    });

    test('pixelsPerStaffSpace round-trips the constructor value', () {
      const pixelsPerStaffSpace = 9.5;
      expect(
          RenderScale(pixelsPerStaffSpace).pixelsPerStaffSpace, pixelsPerStaffSpace);
    });
  });

  group('staff-space → pixel conversions scale correctly with the measure', () {
    test('toPixels is linear in the measure (doubling doubles the pixels)', () {
      const staffSpaceWidth = 0.12; // e.g. a stem thickness
      final smallScale = RenderScale(4);
      final largeScale = RenderScale(8);

      expect(smallScale.toPixels(staffSpaceWidth), staffSpaceWidth * 4);
      expect(largeScale.toPixels(staffSpaceWidth), staffSpaceWidth * 8);
      // Doubling the measure doubles the pixel value for a fixed staff-space
      // input — the core "scaling is a function of the measure" property.
      expect(largeScale.toPixels(staffSpaceWidth),
          2 * smallScale.toPixels(staffSpaceWidth));
    });

    test('toPixels scales linearly in the staff-space input too', () {
      final renderScale = RenderScale(8);
      expect(renderScale.toPixels(0), 0);
      expect(renderScale.toPixels(1), 8);
      expect(renderScale.toPixels(2.5), 20);
    });

    test('pixelEmFontSize = 4 × pixelsPerStaffSpace (the em factor, once)', () {
      final renderScale = RenderScale(8);
      expect(renderScale.pixelEmFontSize, 4 * 8);
      expect(renderScale.pixelEmFontSize,
          RenderScale.staffSpacesPerEm * renderScale.pixelsPerStaffSpace);
    });

    test('doubling the measure doubles the glyph pixel font size', () {
      final smallScale = RenderScale(4);
      final largeScale = RenderScale(8);
      expect(largeScale.pixelEmFontSize, 2 * smallScale.pixelEmFontSize);
    });
  });

  group('copyWith', () {
    test('replaces pixelsPerStaffSpace and re-validates', () {
      final renderScale = RenderScale(8);
      expect(renderScale.copyWith(pixelsPerStaffSpace: 16).pixelsPerStaffSpace, 16);
      // Unchanged value kept.
      expect(renderScale.copyWith().pixelsPerStaffSpace, 8);
    });
  });

  group('validation — a non-positive or NaN measure throws', () {
    test('zero throws', () {
      expect(() => RenderScale(0), throwsArgumentError);
    });

    test('negative throws', () {
      expect(() => RenderScale(-2), throwsArgumentError);
    });

    test('NaN throws', () {
      expect(() => RenderScale(double.nan), throwsArgumentError);
    });
  });
}
