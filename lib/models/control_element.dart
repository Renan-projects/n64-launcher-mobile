import 'package:flutter/widgets.dart';
import 'pad_button.dart';

enum ControlShape { circle, rectangle, dpad, stick }

class ControlElement {
  const ControlElement({
    required this.id,
    required this.shape,
    required this.rect,
    this.button,
    this.label,
    this.floating = false,
  });

  final String id;
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

  ControlElement copyWith({Rect? rect}) => ControlElement(
        id: id,
        shape: shape,
        rect: rect ?? this.rect,
        button: button,
        label: label,
        floating: floating,
      );
}

class ControlLayout {
  const ControlLayout(this.elements);

  final List<ControlElement> elements;

  /// Returns a copy of this layout with per-element rect overrides applied.
  /// [overrides] maps element id to [x, y, w, h] (all relative 0..1).
  ControlLayout withOverrides(Map<String, List<double>> overrides) {
    if (overrides.isEmpty) return this;
    return ControlLayout([
      for (final e in elements)
        if (overrides[e.id] case final o? when o.length == 4)
          e.copyWith(rect: Rect.fromLTWH(o[0], o[1], o[2], o[3]))
        else
          e,
    ]);
  }

  static const ControlLayout landscape = ControlLayout([
    ControlElement(
      id: 'stick',
      shape: ControlShape.stick,
      rect: Rect.fromLTWH(0.05, 0.45, 0.22, 0.42),
      floating: true,
    ),
    ControlElement(
      id: 'dpad',
      shape: ControlShape.dpad,
      rect: Rect.fromLTWH(0.06, 0.12, 0.16, 0.30),
    ),
    ControlElement(
      id: 'a',
      shape: ControlShape.circle,
      rect: Rect.fromLTWH(0.73, 0.54, 0.10, 0.19),
      button: PadButton.a,
      label: 'A',
    ),
    ControlElement(
      id: 'b',
      shape: ControlShape.circle,
      rect: Rect.fromLTWH(0.63, 0.68, 0.09, 0.17),
      button: PadButton.b,
      label: 'B',
    ),
    ControlElement(
      id: 'cUp',
      shape: ControlShape.circle,
      rect: Rect.fromLTWH(0.885, 0.30, 0.06, 0.12),
      button: PadButton.cUp,
      label: 'C▲',
    ),
    ControlElement(
      id: 'cDown',
      shape: ControlShape.circle,
      rect: Rect.fromLTWH(0.885, 0.56, 0.06, 0.12),
      button: PadButton.cDown,
      label: 'C▼',
    ),
    ControlElement(
      id: 'cLeft',
      shape: ControlShape.circle,
      rect: Rect.fromLTWH(0.825, 0.43, 0.06, 0.12),
      button: PadButton.cLeft,
      label: 'C◀',
    ),
    ControlElement(
      id: 'cRight',
      shape: ControlShape.circle,
      rect: Rect.fromLTWH(0.925, 0.43, 0.06, 0.12),
      button: PadButton.cRight,
      label: 'C▶',
    ),
    ControlElement(
      id: 'l',
      shape: ControlShape.rectangle,
      rect: Rect.fromLTWH(0.05, 0.03, 0.12, 0.08),
      button: PadButton.l,
      label: 'L',
    ),
    ControlElement(
      id: 'r',
      shape: ControlShape.rectangle,
      rect: Rect.fromLTWH(0.83, 0.03, 0.12, 0.08),
      button: PadButton.r,
      label: 'R',
    ),
    ControlElement(
      id: 'z',
      shape: ControlShape.circle,
      rect: Rect.fromLTWH(0.44, 0.06, 0.12, 0.16),
      button: PadButton.z,
      label: 'Z',
    ),
    ControlElement(
      id: 'start',
      shape: ControlShape.rectangle,
      rect: Rect.fromLTWH(0.44, 0.86, 0.12, 0.09),
      button: PadButton.start,
      label: 'START',
    ),
  ]);
}
