import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/control_element.dart';
import '../models/rom.dart';
import '../services/controller_monitor.dart';
import '../services/emulator_service.dart';
import '../state/app_state.dart';
import 'l10n_ext.dart';
import 'layout_editor.dart';
import 'widgets/emulator_view.dart';
import 'widgets/touch_controls.dart';
import 'widgets/save_slots_sheet.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.rom,
    required this.controllers,
  });

  final Rom rom;
  final ControllerMonitor controllers;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final EmulatorService _emulator = EmulatorService.instance;
  EmulatorStatus _status = EmulatorStatus.loading;
  bool _menuOpen = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    widget.controllers.addListener(_onControllers);
    _boot();
  }

  @override
  void dispose() {
    widget.controllers.removeListener(_onControllers);
    _emulator.stop();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  void _onControllers() => setState(() {});

  Future<void> _boot() async {
    final status = await _emulator.start(widget.rom.path);
    if (mounted) setState(() => _status = status);
  }

  Future<void> _toggleMenu() async {
    setState(() => _menuOpen = !_menuOpen);
    if (_menuOpen) {
      await _emulator.pause();
    } else {
      await _emulator.resume();
    }
  }

  Future<void> _quit() async {
    await _emulator.stop();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _openLayoutEditor() async {
    await _emulator.pause();
    setState(() => _menuOpen = false);
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LayoutEditor()),
    );
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await _emulator.resume();
    if (mounted) setState(() {});
  }

  Future<void> _openSaveSlots() async {
    final slot = await showSaveSlotsSheet(context, widget.rom);
    if (slot == null || !mounted) return;
    final l10n = context.l10n;
    if (slot.action == SlotAction.save) {
      await _emulator.saveState(slot.index);
      _snack(l10n.stateSaved(slot.index));
    } else {
      await _emulator.loadState(slot.index);
      _snack(l10n.stateLoaded(slot.index));
      await _toggleMenu();
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppState.of(context).settings;
    final showControls = settings.showTouchControls &&
        !widget.controllers.hasPhysicalController &&
        _status == EmulatorStatus.running;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const EmulatorView(),
          if (_status == EmulatorStatus.loading)
            _CenterMessage(text: context.l10n.loadingCore),
          if (_status == EmulatorStatus.missingCore)
            _CenterMessage(text: context.l10n.coreMissingBody),
          if (showControls)
            TouchControls(
              layout:
                  ControlLayout.landscape.withOverrides(settings.controlLayout),
              opacity: settings.controlsOpacity,
              haptics: settings.haptics,
              onChanged: _emulator.sendInput,
            ),
          Positioned(
            top: 8,
            right: 8,
            child: SafeArea(
              child: IconButton.filledTonal(
                icon: Icon(_menuOpen ? Icons.close : Icons.menu),
                onPressed: _toggleMenu,
              ),
            ),
          ),
          if (_menuOpen) _buildMenu(context),
        ],
      ),
    );
  }

  Widget _buildMenu(BuildContext context) {
    final l10n = context.l10n;
    return Positioned.fill(
      child: GestureDetector(
        onTap: _toggleMenu,
        child: Container(
          color: Colors.black54,
          alignment: Alignment.center,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.play_arrow),
                    title: Text(l10n.resume),
                    onTap: _toggleMenu,
                  ),
                  ListTile(
                    leading: const Icon(Icons.save),
                    title: Text(l10n.saveSlots),
                    onTap: _openSaveSlots,
                  ),
                  ListTile(
                    leading: const Icon(Icons.refresh),
                    title: Text('Reset'),
                    onTap: () {
                      _emulator.reset();
                      _toggleMenu();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.gamepad),
                    title: const Text('Customize buttons'),
                    onTap: _openLayoutEditor,
                  ),
                  ListTile(
                    leading: const Icon(Icons.exit_to_app),
                    title: Text(l10n.quitGame),
                    onTap: _quit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CenterMessage extends StatelessWidget {
  const _CenterMessage({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      );
}
