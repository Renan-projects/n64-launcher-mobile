import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/control_element.dart';
import '../state/app_state.dart';

class LayoutEditor extends StatefulWidget {
  const LayoutEditor({super.key});

  @override
  State<LayoutEditor> createState() => _LayoutEditorState();
}

class _LayoutEditorState extends State<LayoutEditor> {
  static const double _minSize = 0.05;
  final Map<String, Rect> _rects = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final overrides = AppState.of(context).settings.controlLayout;
    for (final e in ControlLayout.landscape.withOverrides(overrides).elements) {
      _rects[e.id] = e.rect;
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  void _reset() {
    setState(() {
      _rects.clear();
      for (final e in ControlLayout.landscape.elements) {
        _rects[e.id] = e.rect;
      }
    });
  }

  Future<void> _save() async {
    final state = AppState.of(context);
    final overrides = <String, List<double>>{
      for (final entry in _rects.entries)
        entry.key: [
          entry.value.left,
          entry.value.top,
          entry.value.width,
          entry.value.height,
        ],
    };
    await state.updateSettings(
      state.settings.copyWith(controlLayout: overrides),
    );
    if (mounted) Navigator.of(context).pop();
  }

  void _move(String id, double dx, double dy, Size size) {
    final r = _rects[id]!;
    final nx = (r.left + dx / size.width).clamp(0.0, 1.0 - r.width);
    final ny = (r.top + dy / size.height).clamp(0.0, 1.0 - r.height);
    setState(() => _rects[id] = Rect.fromLTWH(nx, ny, r.width, r.height));
  }

  void _resize(String id, double dx, double dy, Size size) {
    final r = _rects[id]!;
    final nw =
        (r.width + dx / size.width).clamp(_minSize, 1.0 - r.left);
    final nh =
        (r.height + dy / size.height).clamp(_minSize, 1.0 - r.top);
    setState(() => _rects[id] = Rect.fromLTWH(r.left, r.top, nw, nh));
  }

  String _label(ControlElement e) {
    if (e.label != null) return e.label!;
    if (e.shape == ControlShape.stick) return 'Stick';
    if (e.shape == ControlShape.dpad) return 'D-Pad';
    return e.id;
  }

  @override
  Widget build(BuildContext context) {
    final elements = ControlLayout.landscape.elements;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F13),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            return Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: _GridPainter())),
                for (final e in elements)
                  _EditableBox(
                    key: ValueKey(e.id),
                    rect: _rects[e.id]!,
                    size: size,
                    label: _label(e),
                    onMove: (dx, dy) => _move(e.id, dx, dy, size),
                    onResize: (dx, dy) => _resize(e.id, dx, dy, size),
                  ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Row(
                    children: [
                      _bar(Icons.close, 'Close',
                          () => Navigator.of(context).pop()),
                      const Spacer(),
                      const Text(
                        'Drag to move · corner to resize',
                        style:
                            TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const Spacer(),
                      _bar(Icons.restart_alt, 'Reset', _reset),
                      const SizedBox(width: 8),
                      _bar(Icons.save, 'Save', _save, primary: true),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _bar(IconData icon, String label, VoidCallback onTap,
      {bool primary = false}) {
    return Material(
      color: primary ? const Color(0xFF3DA9FC) : const Color(0xCC1B242C),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 18,
                  color: primary ? Colors.white : Colors.white70),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: primary ? Colors.white : Colors.white70,
                      fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditableBox extends StatelessWidget {
  const _EditableBox({
    super.key,
    required this.rect,
    required this.size,
    required this.label,
    required this.onMove,
    required this.onResize,
  });

  final Rect rect;
  final Size size;
  final String label;
  final void Function(double dx, double dy) onMove;
  final void Function(double dx, double dy) onResize;

  @override
  Widget build(BuildContext context) {
    final left = rect.left * size.width;
    final top = rect.top * size.height;
    final w = rect.width * size.width;
    final h = rect.height * size.height;
    return Positioned(
      left: left,
      top: top,
      width: w,
      height: h,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) => onMove(d.delta.dx, d.delta.dy),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0x553DA9FC),
                border: Border.all(color: const Color(0xFF3DA9FC), width: 1.5),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ),
            Positioned(
              right: -10,
              bottom: -10,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (d) => onResize(d.delta.dx, d.delta.dy),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: Color(0xFF3DA9FC),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.open_in_full,
                      size: 15, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x14FFFFFF)
      ..strokeWidth = 1;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}
