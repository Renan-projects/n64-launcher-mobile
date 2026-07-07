import 'package:flutter/services.dart';
import '../models/pad_button.dart';
import '../models/save_slot.dart';

enum EmulatorStatus { idle, loading, running, paused, missingCore, error }

class EmulatorService {
  EmulatorService._();
  static final EmulatorService instance = EmulatorService._();

  static const MethodChannel _channel =
      MethodChannel('org.renanprojects.n64/emulator');

  static const String viewType = 'org.renanprojects.n64/surface';

  Future<bool> isCoreAvailable() async {
    final ok = await _channel.invokeMethod<bool>('isCoreAvailable');
    return ok ?? false;
  }

  Future<EmulatorStatus> start(String romPath) async {
    final result = await _channel.invokeMethod<String>('start', {
      'rom': romPath,
    });
    return _statusFrom(result);
  }

  Future<void> stop() => _channel.invokeMethod('stop');

  Future<void> pause() => _channel.invokeMethod('pause');

  Future<void> resume() => _channel.invokeMethod('resume');

  Future<void> reset() => _channel.invokeMethod('reset');

  Future<void> sendInput(PadState state) => _channel.invokeMethod('input', {
        'buttons': state.buttons,
        'stickX': state.stickX,
        'stickY': state.stickY,
      });

  Future<void> saveState(int slot) =>
      _channel.invokeMethod('saveState', {'slot': slot});

  Future<EmulatorStatus> loadState(int slot) async {
    final result =
        await _channel.invokeMethod<String>('loadState', {'slot': slot});
    return _statusFrom(result);
  }

  Future<List<SaveSlot>> listSaveSlots(String romPath) async {
    final raw = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
      'saveSlots',
      {'rom': romPath},
    );
    if (raw == null) return const [];
    return raw
        .map((m) => SaveSlot.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  Future<void> deleteSaveSlot(String romPath, int slot) =>
      _channel.invokeMethod('deleteSaveSlot', {'rom': romPath, 'slot': slot});

  EmulatorStatus _statusFrom(String? value) {
    switch (value) {
      case 'running':
        return EmulatorStatus.running;
      case 'paused':
        return EmulatorStatus.paused;
      case 'loading':
        return EmulatorStatus.loading;
      case 'missingCore':
        return EmulatorStatus.missingCore;
      case 'error':
        return EmulatorStatus.error;
      default:
        return EmulatorStatus.idle;
    }
  }
}
