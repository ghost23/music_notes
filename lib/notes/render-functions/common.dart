import '../music-line.dart';

double getLineSpacing(double fontSize) => fontSize / 4;

/// Get the y position for a staff system. The given staffNumber should be a number starting at 1.
double staffYPos(DrawingContext drawC, int staffNumber) => (drawC.staffHeight + drawC.staffsSpacing)*(staffNumber-1);