import 'package:flutter/material.dart';
import 'package:music_notes_2/graphics/graphics_model/measure.dart';

import '../../musicXML/data.dart';
import '../music_line.dart';
import 'beam.dart';
import 'common.dart';

class DrawingContext extends MusicLineOptions {
  DrawingContext(
    super.score,
    super.staffHeight,
    super.topMargin,
    this.canvas,
    this.size,
    this.staffsSpacing,
  )   : _currentAttributes = score.parts.first.measures.first.attributes!,
        measuresPerPart = List.filled(score.parts.length, List.empty(growable: true), growable: false);

  final Canvas canvas;
  final Size size;
  final double staffsSpacing;

  get lS => getLineSpacing(staffHeight);
  int currentPart = 0;
  int _currentMeasure = 0;

  int get currentMeasure => _currentMeasure;

  set currentMeasure(int newMeasure) {
    _currentMeasure = newMeasure;
    final newMeasureAttributes = score.parts[currentPart].measures.elementAt(newMeasure).attributes;
    if (newMeasureAttributes != null) {
      _currentAttributes = _currentAttributes.copyWithObject(newMeasureAttributes);
    }
  }

  Attributes _currentAttributes;

  Attributes get latestAttributes => _currentAttributes;
  Map<int, Map<int, List<BeamPoint>>> currentBeamPointsPerID = {};
  final List<List<MeasureGeometry>> measuresPerPart;

  Offset getTranslation() {
    final transform = canvas.getTransform();
    return Offset(transform[12], transform[13]);
  }

  Offset localToGlobal(Offset local) {
    return getTranslation() + local;
  }

  Offset globalToLocal(Offset global) {
    return global - getTranslation();
  }

  void executeGlobally(VoidCallback command) {
    canvas.save();
    canvas.translate(-getTranslation().dx, -getTranslation().dy);
    command();
    canvas.restore();
  }

  void debugDrawBB(Rect boundingBox) {
    executeGlobally(() {
      canvas.drawRect(boundingBox, debugPaint(Colors.red));
    });
  }

  DrawingContext copyWith(
      {Score? score, double? staffHeight, double? topMargin, Canvas? canvas, Size? size, double? staffsSpacing}) {
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
