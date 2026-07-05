This goal for this project is to render music notation in flutter.
We are in a refactoring branch ("refactor-layouting"). The main branch contains a running version
of this library. That version had a rather simplistic approach:
- load a musicxml file that holds a musical piece
- parse the file (see lib/musicXML/parser.dart) into our own data model (see lib/musicXML/data.dart)
- feed the data model into our renderer (see lib/graphics/music_line.dart), which directly
  renders the data onto a Canvas in one pass

That approach worked well enough for some cases, but it ultimately had issues. The main issue
was rendering the data in one pass directly to the canvas. The issue with that is that a lot of
the symbols in music notation are context-specific. Take a legato line, for example. You cannot draw
the legato line before you know where its underlying notes are placed. So you need to be able to
create the legato line but be able to alter it once you have all the other symbols placed.

The solution to this problem is to separate the layout and render phases. The layout phase
will calculate the positions of all the symbols in the music notation, and the render phase will
use those positions to draw the symbols onto the canvas. This allows us to create the legato line
and other symbols before we know their final positions and then update them once we have all the
other symbols placed.

This puts more emphasis on the layout phase. It will involve a multi-pass process, because setting
layout properties for one symbol might affect the layout for another symbol we already touched.
The result of the layout phase will be a data structure that holds positions, scales, rotation,
and other layout information for the complete music notation. This data will then be fed into the
renderer, which will use it to draw the symbols and other graphics onto the canvas.

To achieve this, we will need to design a system that allows for the layout system to be 
modular enough so that it can be updated and refined as new layout rules are added or existing
ones are modified. The SMUFL standard defines certain positional anchors and standard widths
and margins, but that is not enough to build a complete layout. We need to be able to define
layout rules that specify how certain graphical elements should be positioned relative to each other
in the respective context. Ideally, these layout rules can be defined in isolation so that we can
add more rules step by step. We could look at Cascading Style Sheets on the Web for inspiration. A
CSS class is an isolated unit that can be reused and combined with other classes to create complex
styles. We can use a similar approach to define layout rules that can be reused and combined to
create complex layouts.

This approach is in fact more than just a refactor. It is essentially a rewrite of the current render
logic. I think we can still keep the musicXML parser and data structure. And we need to keep the
generated SMUFL glyph data.