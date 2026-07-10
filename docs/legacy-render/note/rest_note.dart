import '../../../musicXML/data.dart';
import '../../generated/glyph_range_definitions.dart';
import '../drawing_context.dart';
import '../glyph.dart';

double durationToRestLengthIndex(DrawingContext drawC, int duration) {
  return ((drawC.latestAttributes.divisions! * 4) / duration) / 2;
}

paintRestNote(DrawingContext drawC, RestNote note, {bool noAdvance = false}) {
  drawC.canvas.translate(0, (drawC.staffHeight + drawC.staffsSpacing) * (note.staff - 1));

  var restGlyph = glyphRangeMap[GlyphRange.rests]!
      .glyphs[durationToRestLengthIndex(drawC, note.duration).round() + 3]; // whole rest begins at index 3

  paintGlyph(drawC, restGlyph, noAdvance: noAdvance);

  drawC.canvas.translate(0, -(drawC.staffHeight + drawC.staffsSpacing) * (note.staff - 1));
}
