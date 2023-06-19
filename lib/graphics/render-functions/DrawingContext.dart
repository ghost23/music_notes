import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:music_notes_2/graphics/graphics-model/measure.dart';

import 'common.dart';
import 'beam.dart';
import '../music-line.dart';
import '../../ExtendedCanvas.dart';
import '../../musicXML/data.dart';

class DrawingContext extends MusicLineOptions {

  DrawingContext(
      Score score,
      double staffHeight,
      double topMargin,
      this.canvas,
      this.size,
      this.staffsSpacing,
      ) : _currentAttributes = score.parts.first.measures.first.attributes!,
        measuresPerPart = List.filled(score.parts.length, List.empty(growable: true), growable: false),
        super(score, staffHeight, topMargin);

  final XCanvas canvas;
  final Size size;
  final double staffsSpacing;
  get lS => getLineSpacing(staffHeight);
  int currentPart = 0;
  int _currentMeasure = 0;
  int get currentMeasure => _currentMeasure;
  set currentMeasure(int newMeasure) {
    _currentMeasure = newMeasure;
    final newMeasureAttributes = score.parts[currentPart].measures.elementAt(newMeasure).attributes;
    if(newMeasureAttributes != null) {
      _currentAttributes = _currentAttributes.copyWithObject(newMeasureAttributes);
    }
  }
  Attributes _currentAttributes;
  Attributes get latestAttributes => _currentAttributes;
  Map<int, Map<int, List<BeamPoint>>> currentBeamPointsPerID = {};
  final List<List<MeasureGeometry>> measuresPerPart;

  void debugDrawBB(Rect boundingBox) {
    canvas.executeGlobally(() {
      canvas.drawRect(boundingBox, debugPaint(Colors.red));
    });
  }

  DrawingContext copyWith({Score? score, double? staffHeight, double? topMargin, XCanvas? canvas, Size? size, double? staffsSpacing}) {
    return DrawingContext(
      score ?? this.score,
      staffHeight ?? this.staffHeight,
      topMargin ?? this.topMargin,
      canvas ?? this.canvas,
      size ?? this.size,
      staffsSpacing ?? this.staffsSpacing,
    );
  }
}