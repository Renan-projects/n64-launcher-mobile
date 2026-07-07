import 'package:flutter/material.dart';
import '../models/app_settings.dart';
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
