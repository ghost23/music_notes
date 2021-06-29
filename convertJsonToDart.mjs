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
`const GLYPH_FONTCODE_MAP = <Glyph, String>{
${Object.keys(glyphNames).map(convertGlyphToDartField).join('')}
};`;

    const glyphSourceCode =
`${glyphEnumDart}

${glyphNamesDart}
`

    await fs.writeFile('./lib/notes/generated/glyph-definitions.dart', glyphSourceCode);



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
    final String range_start;
    final String range_end;
    final List<Glyph> glyphs;
}

const GLYPHRANGE_MAP = <GlyphRange, GlyphRangeData>{
${Object.keys(ranges).map(convertRangeDataToDartField).join('')}
};`;

    const glyphRangeSourceCode =
`import 'glyph-definitions.dart';

${glyphRangeEnumDart}

${glyphRangeDataDart}
`

    await fs.writeFile('./lib/notes/generated/glyph-range-definitions.dart', glyphRangeSourceCode);



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
        `const GLYPH_CLASSES_MAP = <GlyphClass, List<Glyph>>{
${Object.keys(glyphClasses).map(convertGlyphClassToDartField).join('')}
};`;

    const glyphClassesSourceCode =
`import 'glyph-definitions.dart';
        
${glyphClassEnumDart}

${glyphClassesDart}
`

    await fs.writeFile('./lib/notes/generated/glyph-classes-definitions.dart', glyphClassesSourceCode);




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

const ENGRAVING_DEFAULTS = EngravingDefaults();
`

    await fs.writeFile('./lib/notes/generated/engraving-defaults.dart', engravingDefaults);


    function convertAdvanceToDart(glyphKey, index, list) {
        return `   Glyph.${glyphKey}: ${bravuraMetaData.glyphAdvanceWidths[glyphKey]}${index < list.length-1 ? ',\n':''}`
    }

    const advanceToGlyphWidthsMap =
`import 'glyph-definitions.dart';

const GLYPH_ADVANCE_WIDTHS = <Glyph, double>{
${Object.keys(glyphNames).filter(g=>bravuraMetaData.glyphAdvanceWidths.hasOwnProperty(g)).map(convertAdvanceToDart).join('')}
};`;

    await fs.writeFile('./lib/notes/generated/glyph-advance-widths.dart', advanceToGlyphWidthsMap);

    function convertBBoxDataToDart(glyphKey, index, list) {
        const bbox = bravuraMetaData.glyphBBoxes[glyphKey];
        return `   Glyph.${glyphKey}: GlyphBBox(Offset(${bbox.bBoxNE[0]}, ${-bbox.bBoxNE[1]}), Offset(${bbox.bBoxSW[0]}, ${-bbox.bBoxSW[1]}))${index < list.length-1 ? ',\n':''}`;
    }

    const glyphBBoxesDart =
`import 'dart:ui';
import 'glyph-definitions.dart';

class GlyphBBox {
    
    const GlyphBBox(this.northEast, this.southWest);
    
    final Offset northEast;
    final Offset southWest;
}

const GLYPH_BBOXES = <Glyph, GlyphBBox>{
${Object.keys(glyphNames).filter(g=>bravuraMetaData.glyphBBoxes.hasOwnProperty(g)).map(convertBBoxDataToDart).join('')}
};
`;

    await fs.writeFile('./lib/notes/generated/glyph-bboxes.dart', glyphBBoxesDart);

    function convertAnchorsToDart(glyphKey, index, list) {
        const glyphAnchor = bravuraMetaData.glyphsWithAnchors[glyphKey];

        return `   Glyph.${glyphKey}: GlyphAnchor(${Object.keys(glyphAnchor).map(elmt=>`${elmt}: Offset(${glyphAnchor[elmt][0]}, ${-glyphAnchor[elmt][1]})`).join(', ')})${index < list.length-1 ? ',\n':''}`;
    }

    const glyphsWithAnchorsDart =
`import 'dart:ui';
import 'glyph-definitions.dart';

class GlyphAnchor {

    const GlyphAnchor({
        this.splitStemUpSE = const Offset(0,0),
        this.splitStemUpSW = const Offset(0,0),
        this.splitStemDownNE = const Offset(0,0),
        this.splitStemDownNW = const Offset(0,0),
        this.stemUpSE = const Offset(0,0),
        this.stemDownNW = const Offset(0,0),
        this.stemUpNW = const Offset(0,0),
        this.stemDownSW = const Offset(0,0),
        this.nominalWidth = const Offset(0,0),
        this.numeralTop = const Offset(0,0),
        this.numeralBottom = const Offset(0,0),
        this.cutOutNE = const Offset(0,0),
        this.cutOutSE = const Offset(0,0),
        this.cutOutSW = const Offset(0,0),
        this.cutOutNW = const Offset(0,0),
        this.graceNoteSlashSW = const Offset(0,0),
        this.graceNoteSlashNE = const Offset(0,0),
        this.graceNoteSlashNW = const Offset(0,0),
        this.graceNoteSlashSE = const Offset(0,0),
        this.repeatOffset = const Offset(0,0),
        this.noteheadOrigin = const Offset(0,0),
        this.opticalCenter = const Offset(0,0)
    }); 

    final Offset splitStemUpSE;
    final Offset splitStemUpSW;
    final Offset splitStemDownNE;
    final Offset splitStemDownNW;
    final Offset stemUpSE;
    final Offset stemDownNW;
    final Offset stemUpNW;
    final Offset stemDownSW;
    final Offset nominalWidth;
    final Offset numeralTop;
    final Offset numeralBottom;
    final Offset cutOutNE;
    final Offset cutOutSE;
    final Offset cutOutSW;
    final Offset cutOutNW;
    final Offset graceNoteSlashSW;
    final Offset graceNoteSlashNE;
    final Offset graceNoteSlashNW;
    final Offset graceNoteSlashSE;
    final Offset repeatOffset;
    final Offset noteheadOrigin;
    final Offset opticalCenter;

    GlyphAnchor translate(Offset offset) {
       return GlyphAnchor(
           splitStemUpSE: this.splitStemUpSE + offset,
           splitStemUpSW: this.splitStemUpSW + offset,
           splitStemDownNE: this.splitStemDownNE + offset,
           splitStemDownNW: this.splitStemDownNW + offset,
           stemUpSE: this.stemUpSE + offset,
           stemDownNW: this.stemDownNW + offset,
           stemUpNW: this.stemUpNW + offset,
           stemDownSW: this.stemDownSW + offset,
           nominalWidth: this.nominalWidth + offset,
           numeralTop: this.numeralTop + offset,
           numeralBottom: this.numeralBottom + offset,
           cutOutNE: this.cutOutNE + offset,
           cutOutSE: this.cutOutSE + offset,
           cutOutSW: this.cutOutSW + offset,
           cutOutNW: this.cutOutNW + offset,
           graceNoteSlashSW: this.graceNoteSlashSW + offset,
           graceNoteSlashNE: this.graceNoteSlashNE + offset,
           graceNoteSlashNW: this.graceNoteSlashNW + offset,
           graceNoteSlashSE: this.graceNoteSlashSE + offset,
           repeatOffset: this.repeatOffset + offset,
           noteheadOrigin: this.noteheadOrigin + offset,
           opticalCenter: this.opticalCenter + offset,
       );
    }
}

const GLYPH_ANCHORS = <Glyph, GlyphAnchor>{
${Object.keys(glyphNames).filter(g=>bravuraMetaData.glyphsWithAnchors.hasOwnProperty(g)).map(convertAnchorsToDart).join('')}
};
`;

    await fs.writeFile('./lib/notes/generated/glyph-anchors.dart', glyphsWithAnchorsDart);
}

exec();