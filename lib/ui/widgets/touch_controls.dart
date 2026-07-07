import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/control_element.dart';
import '../../models/pad_button.dart';

const Color _accent = Color(0xFF3DA9FC);
const Color _idle = Color(0xFF24303A);
const Color _base = Color(0xFF1B242C);
const Color _outline = Color(0xFF3A4A57);
const Color _knob = Color(0xFF7886A0);

class TouchControls extends StatefulWidget {
  const TouchControls({
    super.key,
    required this.layout,
    required this.opacity,
    required this.haptics,
    required this.onChanged,
  });

  final ControlLayout layout;
  final double opacity;
  final bool haptics;
  final ValueChanged<PadState> onChanged;

  @override
  State<TouchControls> createState() => _TouchControlsState();
}

class _Touch {
  _Touch(this.kind, {this.element, this.stickBase});
  final _TouchKind kind;
  final ControlElement? element;
  Offset? stickBase;
  Offset current = Offset.zero;
}

enum _TouchKind { button, stick }

class _TouchControlsState extends State<TouchControls> {
  final Map<int, _Touch> _touches = {};
  Size _size = Size.zero;
  int _buttons = 0;
  double _stickX = 0;
  double _stickY = 0;
  final Map<ControlElement, Offset> _stickKnobs = {};

  void _emit() {
    widget.onChanged(PadState(
      buttons: _buttons,
      stickX: _stickX,
      stickY: _stickY,
    ));
  }

  void _down(int pointer, Offset pos) {
    for (final e in widget.layout.elements) {
      final r = e.resolve(_size);
      if (e.shape == ControlShape.stick) continue;
      if (_hit(e, r, pos)) {
        _touches[pointer] = _Touch(_TouchKind.button, element: e);
        if (e.button != null) _buttons |= e.button!.mask;
        _haptic();
        _recompute();
        return;
      }
    }
    for (final e in widget.layout.elements) {
      if (e.shape != ControlShape.stick) continue;
      final r = e.resolve(_size);
      final margin = e.floating ? r.width * 1.2 : r.width * 0.3;
      if (r.inflate(margin).contains(pos)) {
        final base = e.floating ? pos : r.center;
        final touch = _Touch(_TouchKind.stick, element: e, stickBase: base)
          ..current = pos;
        _touches[pointer] = touch;
        _stickKnobs[e] = base;
        _updateStick(e, base, pos);
        _recompute();
        return;
      }
    }
  }

  void _move(int pointer, Offset pos) {
    final touch = _touches[pointer];
    if (touch == null) return;
    touch.current = pos;
    if (touch.kind == _TouchKind.stick && touch.element != null) {
      _updateStick(touch.element!, touch.stickBase!, pos);
      _recompute();
    }
  }

  void _up(int pointer) {
    final touch = _touches.remove(pointer);
    if (touch == null) return;
    if (touch.kind == _TouchKind.stick && touch.element != null) {
      _stickKnobs.remove(touch.element);
      _stickX = 0;
      _stickY = 0;
    }
    _recompute();
  }

  bool _hit(ControlElement e, Rect r, Offset pos) {
    if (e.shape == ControlShape.circle) {
      return (pos - r.center).distance <= r.width / 2;
    }
    return r.contains(pos);
  }

  void _updateStick(ControlElement e, Offset base, Offset pos) {
    final r = e.resolve(_size);
    final radius = min(r.width, r.height) / 2;
    var delta = pos - base;
    if (delta.distance > radius) {
      delta = delta * (radius / delta.distance);
    }
    _stickKnobs[e] = base + delta;
    _stickX = (delta.dx / radius).clamp(-1.0, 1.0);
    _stickY = (-delta.dy / radius).clamp(-1.0, 1.0);
  }

  void _recompute() {
    var buttons = 0;
    for (final touch in _touches.values) {
      if (touch.kind == _TouchKind.button &&
          touch.element?.button != null &&
          _hit(touch.element!, touch.element!.resolve(_size), touch.current)) {
        buttons |= touch.element!.button!.mask;
      }
    }
    if (buttons != _buttons) {
      if (buttons & ~_buttons != 0) _haptic();
      _buttons = buttons;
    }
    setState(() {});
    _emit();
  }

  void _haptic() {
    if (widget.haptics) HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = Size(constraints.maxWidth, constraints.maxHeight);
        return Opacity(
          opacity: widget.opacity,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) => _down(e.pointer, e.localPosition),
            onPointerMove: (e) => _move(e.pointer, e.localPosition),
            onPointerUp: (e) => _up(e.pointer),
            onPointerCancel: (e) => _up(e.pointer),
            child: CustomPaint(
              size: Size.infinite,
              painter: _ControlsPainter(
                elements: widget.layout.elements,
                buttons: _buttons,
                knobs: _stickKnobs,
                size: _size,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ControlsPainter extends CustomPainter {
  _ControlsPainter({
    required this.elements,
    required this.buttons,
    required this.knobs,
    required this.size,
  });

  final List<ControlElement> elements;
  final int buttons;
  final Map<ControlElement, Offset> knobs;
  final Size size;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    for (final e in elements) {
      final r = e.resolve(canvasSize);
      switch (e.shape) {
        case ControlShape.circle:
          _button(canvas, e, r, circle: true);
          break;
        case ControlShape.rectangle:
          _button(canvas, e, r, circle: false);
          break;
        case ControlShape.dpad:
          _dpad(canvas, r);
          break;
        case ControlShape.stick:
          _stick(canvas, e, r);
          break;
      }
    }
  }

  void _button(Canvas canvas, ControlElement e, Rect r, {required bool circle}) {
    final pressed = e.button != null && (buttons & e.button!.mask) != 0;
    _fill(canvas, r, pressed ? _accent : _idle, circle: circle);
    _stroke(canvas, r, circle: circle);
    if (e.label != null) {
      _text(canvas, e.label!, r.center, min(r.width, r.height) * 0.34);
    }
  }

  void _dpad(Canvas canvas, Rect r) {
    _fill(canvas, r, _base, circle: false, radius: 14);
    _stroke(canvas, r, circle: false, radius: 14);
    final cx = r.center.dx, cy = r.center.dy;
    final arm = min(r.width, r.height) * 0.30;
    final th = arm * 0.7;
    void arrow(PadButton b, Rect a) => _fill(
          canvas,
          a,
          (buttons & b.mask) != 0 ? _accent : _idle,
          circle: false,
          radius: 4,
        );
    arrow(PadButton.dpadUp,
        Rect.fromCenter(center: Offset(cx, cy - arm), width: th, height: arm));
    arrow(PadButton.dpadDown,
        Rect.fromCenter(center: Offset(cx, cy + arm), width: th, height: arm));
    arrow(PadButton.dpadLeft,
        Rect.fromCenter(center: Offset(cx - arm, cy), width: arm, height: th));
    arrow(PadButton.dpadRight,
        Rect.fromCenter(center: Offset(cx + arm, cy), width: arm, height: th));
  }

  void _stick(Canvas canvas, ControlElement e, Rect r) {
    final radius = min(r.width, r.height) / 2;
    final knob = knobs[e];
    final base = knob == null && e.floating ? null : r.center;
    final active = knob != null;
    final center = active ? (base ?? knob) : r.center;
    final faint = e.floating && !active;
    final a = faint ? 0.5 : 1.0;
    canvas.drawCircle(center, radius, Paint()..color = _base.withValues(alpha: a));
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = _outline.withValues(alpha: a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      knob ?? center,
      radius * 0.45,
      Paint()..color = (active ? _accent : _knob).withValues(alpha: a),
    );
  }

  void _fill(Canvas canvas, Rect r, Color color,
      {required bool circle, double radius = 0}) {
    final paint = Paint()..color = color;
    if (circle) {
      canvas.drawCircle(r.center, r.width / 2, paint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(radius)),
        paint,
      );
    }
  }

  void _stroke(Canvas canvas, Rect r,
      {required bool circle, double radius = 0}) {
    final paint = Paint()
      ..color = _outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    if (circle) {
      canvas.drawCircle(r.center, r.width / 2, paint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(radius)),
        paint,
      );
    }
  }

  void _text(Canvas canvas, String text, Offset center, double fontSize) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_ControlsPainter old) =>
      old.buttons != buttons || old.knobs != knobs || old.size != size;
}
