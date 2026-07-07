import 'package:flutter/widgets.dart';
import 'pad_button.dart';

enum ControlShape { circle, rectangle, dpad, stick }

class ControlElement {
  const ControlElement({
    required this.shape,
    required this.rect,
    this.button,
    this.label,
    this.floating = false,
  });

  final ControlShape shape;
  final Rect rect;
  final PadButton? button;
  final String? label;
  final bool floating;

  Rect resolve(Size size) => Rect.fromLTWH(
        rect.left * size.width,
        rect.top * size.height,
        rect.width * size.width,
        rect.height * size.height,
      );
}

class ControlLayout {
  const ControlLayout(this.elements);

  final List<ControlElement> elements;

  static const ControlLayout landscape = ControlLayout([
    ControlElement(
      shape: ControlShape.stick,
      rect: Rect.fromLTWH(0.05, 0.45, 0.22, 0.42),
      floating: true,
    ),
    ControlElement(
      shape: ControlShape.dpad,
      rect: Rect.fromLTWH(0.06, 0.12, 0.16, 0.30),
    ),
    ControlElement(
      shape: ControlShape.circle,
      rect: Rect.fromLTWH(0.80, 0.58, 0.10, 0.19),
      button: PadButton.a,
      label: 'A',
    ),
    ControlElement(
      shape: ControlShape.circle,
      rect: Rect.fromLTWH(0.69, 0.72, 0.10, 0.19),
      button: PadButton.b,
      label: 'B',
    ),
    ControlElement(
      shape: ControlShape.circle,
      rect: Rect.fromLTWH(0.90, 0.36, 0.08, 0.15),
      button: PadButton.cUp,
      label: 'C▲',
    ),
    ControlElement(
      shape: ControlShape.circle,
      rect: Rect.fromLTWH(0.90, 0.66, 0.08, 0.15),
      button: PadButton.cDown,
      label: 'C▼',
    ),
    ControlElement(
      shape: ControlShape.circle,
      rect: Rect.fromLTWH(0.83, 0.51, 0.08, 0.15),
      button: PadButton.cLeft,
      label: 'C◀',
    ),
    ControlElement(
      shape: ControlShape.circle,
      rect: Rect.fromLTWH(0.97, 0.51, 0.08, 0.15),
      button: PadButton.cRight,
      label: 'C▶',
    ),
    ControlElement(
      shape: ControlShape.rectangle,
      rect: Rect.fromLTWH(0.05, 0.03, 0.12, 0.08),
      button: PadButton.l,
      label: 'L',
    ),
    ControlElement(
      shape: ControlShape.rectangle,
      rect: Rect.fromLTWH(0.83, 0.03, 0.12, 0.08),
      button: PadButton.r,
      label: 'R',
    ),
    ControlElement(
      shape: ControlShape.circle,
      rect: Rect.fromLTWH(0.44, 0.06, 0.12, 0.16),
      button: PadButton.z,
      label: 'Z',
    ),
    ControlElement(
      shape: ControlShape.rectangle,
      rect: Rect.fromLTWH(0.44, 0.86, 0.12, 0.09),
      button: PadButton.start,
      label: 'START',
    ),
  ]);
}
