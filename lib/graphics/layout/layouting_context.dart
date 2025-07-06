import 'dart:ui';

import '../../musicXML/data.dart';
import '../music_line.dart';
import '../render/common.dart';

class LayoutingContext extends MusicLineOptions {
  LayoutingContext(
    super.score,
    super.staffHeight,
    super.topMargin,
    this.size,
    this.staffsSpacing,
  ) : currentPart = score.parts.first,
  _currentMeasure = score.parts.first.measures.first,
        _currentAttributes = score.parts.first.measures.first.attributes!;

  final Size size;
  final double staffsSpacing;
  Offset drawPos = Offset.zero;
  Part currentPart;
  Measure _currentMeasure;
  Attributes _currentAttributes;

  get lS => getLineSpacing(staffHeight);

  Measure get currentMeasure => _currentMeasure;
  set currentMeasure(Measure newMeasure) {
    _currentMeasure = newMeasure;
    final newMeasureAttributes = _currentMeasure.attributes;
    if (newMeasureAttributes != null) {
      _currentAttributes = _currentAttributes.copyWithObject(newMeasureAttributes);
    }
  }

  Attributes get latestAttributes => _currentAttributes;

  LayoutingContext copyWith({Score? score, double? staffHeight, double? topMargin, Size? size, double? staffsSpacing}) {
    return LayoutingContext(
      score ?? this.score,
      staffHeight ?? this.staffHeight,
      topMargin ?? this.topMargin,
      size ?? this.size,
      staffsSpacing ?? this.staffsSpacing,
    );
  }
}
