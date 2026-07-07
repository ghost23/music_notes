import fs from "fs/promises";

async function exec() {
    const glyphNames = JSON.parse(await fs.readFile('./glyphnames.json', {encoding: "utf8"}));

    function convertGlyphToDartEnumEntry(glyphKey, index, list) {

        return `    ${glyphKey}${index < list.length-1 ? ',\n':''}`;
    }

    const glyphEnumDart =
`enum Glyph {
${Object.keys(glyphNames).map(convertGlyphToDartEnumEntry).join('')}
}`;

    function convertGlyphToDartField(glyphKey, index, list) {

        return `    Glyph.${glyphKey}: "\\u${glyphNames[glyphKey].codepoint.substring(2)}"${index < list.length-1 ? ',\n':''}`;
    }

    const glyphNamesDart =
`const glyphFontCodeMap = <Glyph, String>{
${Object.keys(glyphNames).map(convertGlyphToDartField).join('')}
};`;

    const glyphSourceCode =
`${glyphEnumDart}

${glyphNamesDart}
`

    await fs.writeFile('./lib/graphics/generated/glyph_definitions.dart', glyphSourceCode);



    const ranges = JSON.parse(await fs.readFile('./ranges.json', {encoding: "utf8"}));

    function convertRangeNameToDartEnumEntry(rangeKey, index, list) {

        return `    ${rangeKey}${index < list.length-1 ? ',\n':''}`;
    }

    const glyphRangeEnumDart =
        `enum GlyphRange {
${Object.keys(ranges).map(convertRangeNameToDartEnumEntry).join('')}
}`;

    function convertRangeDataToDartField(rangeKey, index, list) {
        const glyphData = ranges[rangeKey];
        return (
`    GlyphRange.${rangeKey}: GlyphRangeData("${glyphData.description}", "${glyphData.range_start}", "${glyphData.range_end}", [${glyphData.glyphs.map(g => `Glyph.${g}`).join(', ')}])${index < list.length-1 ? ',\n':''}`);
    }

    const glyphRangeDataDart =
`class GlyphRangeData {

    const GlyphRangeData(this.description, this.range_start, this.range_end, this.glyphs);
  
    final String description;
    final String rangeStart;
    final String rangeEnd;
    final List<Glyph> glyphs;
}

const glyphRangeMap = <GlyphRange, GlyphRangeData>{
${Object.keys(ranges).map(convertRangeDataToDartField).join('')}
};`;

    const glyphRangeSourceCode =
`import 'glyph_definitions.dart';

${glyphRangeEnumDart}

${glyphRangeDataDart}
`

    await fs.writeFile('./lib/graphics/generated/glyph_range_definitions.dart', glyphRangeSourceCode);



    const glyphClasses = JSON.parse(await fs.readFile('./classes.json', {encoding: "utf8"}));

    function convertClassNameToDartEnumEntry(rangeKey, index, list) {

        return `    ${rangeKey}${index < list.length-1 ? ',\n':''}`;
    }

    const glyphClassEnumDart =
        `enum GlyphClass {
${Object.keys(glyphClasses).map(convertRangeNameToDartEnumEntry).join('')}
}`;

    function convertGlyphClassToDartField(glyphKey, index, list) {

        return `    GlyphClass.${glyphKey}: [${glyphClasses[glyphKey].map(g => `Glyph.${g}`).join(', ')}]${index < list.length-1 ? ',\n':''}`;
    }

    const glyphClassesDart =
        `const glyphClassesMap = <GlyphClass, List<Glyph>>{
${Object.keys(glyphClasses).map(convertGlyphClassToDartField).join('')}
};`;

    const glyphClassesSourceCode =
`import 'glyph_definitions.dart';
        
${glyphClassEnumDart}

${glyphClassesDart}
`

    await fs.writeFile('./lib/graphics/generated/glyph_classes_definitions.dart', glyphClassesSourceCode);




    const bravuraMetaData = JSON.parse(await fs.readFile('./bravura_metadata.json', {encoding: "utf8"}));

    const engravingDefaults =
`class EngravingDefaults {

  const EngravingDefaults();

  final List<String> textFontFamily = const [${bravuraMetaData.engravingDefaults.textFontFamily.map(g=>`"${g}"`).join(', ')}];
  final double staffLineThickness = ${bravuraMetaData.engravingDefaults.staffLineThickness || 0};
  final double stemThickness = ${bravuraMetaData.engravingDefaults.stemThickness || 0};
  final double beamThickness = ${bravuraMetaData.engravingDefaults.beamThickness || 0};
  final double beamSpacing = ${bravuraMetaData.engravingDefaults.beamSpacing || 0};
  final double legerLineThickness = ${bravuraMetaData.engravingDefaults.legerLineThickness || 0};
  final double legerLineExtension = ${bravuraMetaData.engravingDefaults.legerLineExtension || 0};
  final double slurEndpointThickness = ${bravuraMetaData.engravingDefaults.slurEndpointThickness || 0};
  final double slurMidpointThickness = ${bravuraMetaData.engravingDefaults.slurMidpointThickness || 0};
  final double tieEndpointThickness = ${bravuraMetaData.engravingDefaults.tieEndpointThickness || 0};
  final double tieMidpointThickness = ${bravuraMetaData.engravingDefaults.tieMidpointThickness || 0};
  final double thinBarlineThickness = ${bravuraMetaData.engravingDefaults.thinBarlineThickness || 0};
  final double thickBarlineThickness = ${bravuraMetaData.engravingDefaults.thickBarlineThickness || 0};
  final double dashedBarlineThickness = ${bravuraMetaData.engravingDefaults.dashedBarlineThickness || 0};
  final double dashedBarlineDashLength = ${bravuraMetaData.engravingDefaults.dashedBarlineDashLength || 0};
  final double dashedBarlineGapLength = ${bravuraMetaData.engravingDefaults.dashedBarlineGapLength || 0};
  final double barlineSeparation = ${bravuraMetaData.engravingDefaults.barlineSeparation || 0};
  final double thinThickBarlineSeparation = ${bravuraMetaData.engravingDefaults.thinThickBarlineSeparation || 0};
  final double repeatBarlineDotSeparation = ${bravuraMetaData.engravingDefaults.repeatBarlineDotSeparation || 0};
  final double bracketThickness = ${bravuraMetaData.engravingDefaults.bracketThickness || 0};
  final double subBracketThickness = ${bravuraMetaData.engravingDefaults.subBracketThickness || 0};
  final double hairpinThickness = ${bravuraMetaData.engravingDefaults.hairpinThickness || 0};
  final double octaveLineThickness = ${bravuraMetaData.engravingDefaults.octaveLineThickness || 0};
  final double pedalLineThickness = ${bravuraMetaData.engravingDefaults.pedalLineThickness || 0};
  final double repeatEndingLineThickness = ${bravuraMetaData.engravingDefaults.repeatEndingLineThickness || 0};
  final double arrowShaftThickness = ${bravuraMetaData.engravingDefaults.arrowShaftThickness || 0};
  final double lyricLineThickness = ${bravuraMetaData.engravingDefaults.lyricLineThickness || 0};
  final double textEnclosureThickness = ${bravuraMetaData.engravingDefaults.textEnclosureThickness || 0};
  final double tupletBracketThickness = ${bravuraMetaData.engravingDefaults.tupletBracketThickness || 0};
  final double hBarThickness = ${bravuraMetaData.engravingDefaults.hBarThickness || 0};
}

const engravingDefaults = EngravingDefaults();
`

    await fs.writeFile('./lib/graphics/generated/engraving_defaults.dart', engravingDefaults);


    function convertAdvanceToDart(glyphKey, index, list) {
        return `   Glyph.${glyphKey}: ${bravuraMetaData.glyphAdvanceWidths[glyphKey]}${index < list.length-1 ? ',\n':''}`
    }

    const advanceToGlyphWidthsMap =
`import 'glyph_definitions.dart';

const glyphAdvanceWidths = <Glyph, double>{
${Object.keys(glyphNames).filter(g=>bravuraMetaData.glyphAdvanceWidths.hasOwnProperty(g)).map(convertAdvanceToDart).join('')}
};`;

    await fs.writeFile('./lib/graphics/generated/glyph_advance_widths.dart', advanceToGlyphWidthsMap);

    function convertBBoxDataToDart(glyphKey, index, list) {
        const bbox = bravuraMetaData.glyphBBoxes[glyphKey];
        return `   Glyph.${glyphKey}: GlyphBBox(Offset(${bbox.bBoxNE[0]}, ${-bbox.bBoxNE[1]}), Offset(${bbox.bBoxSW[0]}, ${-bbox.bBoxSW[1]}))${index < list.length-1 ? ',\n':''}`;
    }

    const glyphBBoxesDart =
`import 'dart:ui';
import 'glyph_definitions.dart';

class GlyphBBox {
    
    const GlyphBBox(this.northEast, this.southWest);
    
    final Offset northEast;
    final Offset southWest;
}

const glyphBBoxes = <Glyph, GlyphBBox>{
${Object.keys(glyphNames).filter(g=>bravuraMetaData.glyphBBoxes.hasOwnProperty(g)).map(convertBBoxDataToDart).join('')}
};
`;

    await fs.writeFile('./lib/graphics/generated/glyph_bboxes.dart', glyphBBoxesDart);

    function convertAnchorsToDart(glyphKey, index, list) {
        const glyphAnchor = bravuraMetaData.glyphsWithAnchors[glyphKey];

        return `   Glyph.${glyphKey}: GlyphAnchor(${Object.keys(glyphAnchor).map(elmt=>`${elmt}: Offset(${glyphAnchor[elmt][0]}, ${-glyphAnchor[elmt][1]})`).join(', ')})${index < list.length-1 ? ',\n':''}`;
    }

    const glyphsWithAnchorsDart =
`import 'dart:ui';

import '../glyph_anchor.dart';
import 'glyph_definitions.dart';

// The GlyphAnchor class is hand-written in lib/graphics/glyph_anchor.dart
// (it carries the nullable-presence logic and the translate helper).
// This generated file holds only the per-glyph anchor DATA map and imports
// the class. Do not add hand-written logic here — it would be lost on the
// next regeneration (see docs/code-principle.md).

const glyphAnchors = <Glyph, GlyphAnchor>{
${Object.keys(glyphNames).filter(g=>bravuraMetaData.glyphsWithAnchors.hasOwnProperty(g)).map(convertAnchorsToDart).join('')}
};
`;

    await fs.writeFile('./lib/graphics/generated/glyph_anchors.dart', glyphsWithAnchorsDart);
}

exec();