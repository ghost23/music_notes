import 'dart:ui';

sealed class LayoutElement {
  LayoutElement(this.paint);

  Paint paint;
}

class GroupLayoutElement extends LayoutElement {
  GroupLayoutElement(super.paint);
  
}