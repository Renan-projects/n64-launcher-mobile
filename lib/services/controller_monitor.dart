import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ControllerMonitor extends ChangeNotifier {
  ControllerMonitor() {
    _subscribe();
  }

  static const EventChannel _events =
      EventChannel('org.renanprojects.n64/controllers');
  static const MethodChannel _methods =
      MethodChannel('org.renanprojects.n64/emulator');

  int _count = 0;
  bool _initialised = false;

  int get connectedCount => _count;
  bool get hasPhysicalController => _count > 0;

  Future<void> _subscribe() async {
    _events.receiveBroadcastStream().listen((event) {
      final next = (event is int) ? event : int.tryParse('$event') ?? 0;
      if (next != _count) {
        _count = next;
        notifyListeners();
      }
    }, onError: (_) {});

    if (_initialised) return;
    _initialised = true;
    try {
      final count = await _methods.invokeMethod<int>('controllerCount');
      if (count != null && count != _count) {
        _count = count;
        notifyListeners();
      }
    } catch (_) {}
  }
}
