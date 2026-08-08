import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../models/app_settings.dart';
import '../models/saves_info.dart';
import '../services/emulator_service.dart';
import '../state/app_state.dart';
import 'l10n_ext.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const List<String> _languages = ['en', 'fr'];

  @override
  Widget build(BuildContext context) {
    final state = AppState.of(context);
    final settings = state.settings;
    final l10n = context.l10n;

    void update(AppSettings next) => state.updateSettings(next);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          _SectionHeader(l10n.settingsLanguage),
          RadioGroup<String?>(
            groupValue: settings.localeCode,
            onChanged: (value) => update(
              value == null
                  ? settings.copyWith(clearLocale: true)
                  : settings.copyWith(localeCode: value),
            ),
            child: Column(
              children: [
                RadioListTile<String?>(
                  value: null,
                  title: Text(l10n.settingsLanguageSystem),
                ),
                for (final code in _languages)
                  RadioListTile<String?>(
                    value: code,
                    title: Text(_languageName(code)),
                  ),
              ],
            ),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsAppearance),
          SwitchListTile(
            title: Text(l10n.settingsAppearance),
            value: settings.themeMode == ThemeMode.dark,
            onChanged: (dark) => update(settings.copyWith(
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            )),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsControls),
          SwitchListTile(
            title: Text(l10n.settingsShowControls),
            subtitle: Text(l10n.settingsShowControlsSubtitle),
            value: settings.showTouchControls,
            onChanged: (value) =>
                update(settings.copyWith(showTouchControls: value)),
          ),
          ListTile(
            title: Text(l10n.settingsControlsOpacity),
            subtitle: Slider(
              value: settings.controlsOpacity,
              min: 0.2,
              max: 1.0,
              divisions: 8,
              label: '${(settings.controlsOpacity * 100).round()}%',
              onChanged: (value) =>
                  update(settings.copyWith(controlsOpacity: value)),
            ),
          ),
          SwitchListTile(
            title: Text(l10n.settingsHaptics),
            value: settings.haptics,
            onChanged: (value) => update(settings.copyWith(haptics: value)),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsVideo),
          SwitchListTile(
            title: Text(l10n.settingsIntegerScaling),
            value: settings.integerScaling,
            onChanged: (value) =>
                update(settings.copyWith(integerScaling: value)),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsSaves),
          const _SavesSection(),
        ],
      ),
    );
  }

  String _languageName(String code) {
    switch (code) {
      case 'fr':
        return 'Français';
      case 'en':
        return 'English';
      default:
        return code;
    }
  }
}

/// Shows where saves live, opens that folder, and imports a `.srm` into it.
class _SavesSection extends StatefulWidget {
  const _SavesSection();

  @override
  State<_SavesSection> createState() => _SavesSectionState();
}

class _SavesSectionState extends State<_SavesSection> with WidgetsBindingObserver {
  SavesInfo _info = SavesInfo.unknown;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the permission screen can change where saves live.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final info = await EmulatorService.instance.savesInfo();
    if (mounted) setState(() => _info = info);
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _open() async {
    final l10n = context.l10n;
    final result = await EmulatorService.instance.openSavesFolder();
    if (result != OpenFolderResult.opened) _snack(l10n.savesNoFileManager);
  }

  Future<void> _copyPath() async {
    final l10n = context.l10n;
    await Clipboard.setData(ClipboardData(text: _info.savesDir));
    _snack(l10n.savesPathCopied);
  }

  Future<void> _requestAccess() async {
    await EmulatorService.instance.requestSavesAccess();
    await _refresh();
  }

  Future<void> _import() async {
    final l10n = context.l10n;
    final picked = await FilePicker.platform.pickFiles(type: FileType.any);
    final source = picked?.files.single.path;
    if (source == null) return;

    final name = p.basename(source);
    if (!name.toLowerCase().endsWith('.srm')) {
      _snack(l10n.savesImportWrongType);
      return;
    }
    try {
      final target = p.join(_info.savesDir, name);
      if (p.normalize(source) != p.normalize(target)) {
        await File(source).copy(target);
      }
      _snack(l10n.savesImported(name));
    } on FileSystemException {
      _snack(l10n.savesImportFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (!_info.isKnown) {
      return ListTile(subtitle: Text(l10n.savesUnavailable));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          title: Text(l10n.savesFolder),
          subtitle: SelectableText(_info.savesDir),
          trailing: IconButton(
            icon: const Icon(Icons.copy),
            tooltip: l10n.savesCopyPath,
            onPressed: _copyPath,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.folder_open),
          title: Text(l10n.savesOpenFolder),
          onTap: _open,
        ),
        ListTile(
          leading: const Icon(Icons.file_download),
          title: Text(l10n.savesImport),
          subtitle: Text(l10n.savesImportSubtitle),
          onTap: _import,
        ),
        if (!_info.isShared)
          ListTile(
            leading: const Icon(Icons.lock_open),
            title: Text(l10n.savesGrantAccess),
            subtitle: Text(l10n.savesGrantAccessSubtitle),
            onTap: _requestAccess,
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 1.1,
              ),
        ),
      );
}
