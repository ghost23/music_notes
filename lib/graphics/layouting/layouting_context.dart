import 'dart:ui';

import '../../musicXML/data.dart';
import '../music_line.dart';
import '../render_functions/common.dart';

class LayoutingContext extends MusicLineOptions {
  LayoutingContext(
    super.score,
    super.staffHeight,
    super.topMargin,
    this.size,
    this.staffsSpacing,
  );

  final Size size;
  final double staffsSpacing;
  Offset drawPos = Offset.zero;

  get lS => getLineSpacing(staffHeight);

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
