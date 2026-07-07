import 'package:flutter/widgets.dart';
import '../models/app_settings.dart';
import '../models/rom.dart';
import '../services/rom_library.dart';
import '../services/settings_store.dart';

class AppState extends ChangeNotifier {
  AppState(this._settings);

  final SettingsStore _settingsStore = SettingsStore();
  final RomLibrary _library = RomLibrary();

  AppSettings _settings;
  List<Rom> _roms = const [];
  bool _loadingLibrary = true;

  AppSettings get settings => _settings;
  List<Rom> get roms => _roms;
  bool get loadingLibrary => _loadingLibrary;

  static Future<AppState> create() async {
    final settings = await SettingsStore().load();
    final state = AppState(settings);
    await state.refreshLibrary();
    return state;
  }

  Future<void> refreshLibrary() async {
    _loadingLibrary = true;
    notifyListeners();
    _roms = await _library.load();
    _loadingLibrary = false;
    notifyListeners();
  }

  Future<void> importRom(String path) async {
    _roms = await _library.importFile(path);
    notifyListeners();
  }

  Future<void> removeFromLibrary(Rom rom) async {
    _roms = await _library.removeFromLibrary(rom);
    notifyListeners();
  }

  Future<void> deleteRom(Rom rom) async {
    _roms = await _library.deleteFile(rom);
    notifyListeners();
  }

  Future<void> updateSettings(AppSettings settings) async {
    _settings = settings;
    notifyListeners();
    await _settingsStore.save(settings);
  }

  static AppState of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_AppStateScope>();
    assert(scope != null, 'AppState.of() called outside AppScope');
    return scope!.notifier!;
  }
}

class AppScope extends StatelessWidget {
  const AppScope({super.key, required this.state, required this.child});

  final AppState state;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      _AppStateScope(notifier: state, child: child);
}

class _AppStateScope extends InheritedNotifier<AppState> {
  const _AppStateScope({required super.notifier, required super.child});
}
