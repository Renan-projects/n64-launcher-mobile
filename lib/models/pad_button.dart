enum PadButton {
  dpadUp(1 << 0),
  dpadDown(1 << 1),
  dpadLeft(1 << 2),
  dpadRight(1 << 3),
  start(1 << 4),
  z(1 << 5),
  b(1 << 6),
  a(1 << 7),
  cUp(1 << 8),
  cDown(1 << 9),
  cLeft(1 << 10),
  cRight(1 << 11),
  l(1 << 12),
  r(1 << 13);

  const PadButton(this.mask);

  final int mask;
}

class PadState {
  PadState({
    this.buttons = 0,
    this.stickX = 0,
    this.stickY = 0,
  });

  final int buttons;
  final double stickX;
  final double stickY;

  bool isPressed(PadButton button) => (buttons & button.mask) != 0;

  PadState copyWith({int? buttons, double? stickX, double? stickY}) => PadState(
        buttons: buttons ?? this.buttons,
        stickX: stickX ?? this.stickX,
        stickY: stickY ?? this.stickY,
      );
}
