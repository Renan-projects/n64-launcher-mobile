import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/rom.dart';
import '../services/controller_monitor.dart';
import '../state/app_state.dart';
import 'game_screen.dart';
import 'help_screen.dart';
import 'l10n_ext.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controllers});

  final ControllerMonitor controllers;

  Future<void> _addGame(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path == null || !isRomFile(path)) return;
    if (context.mounted) await AppState.of(context).importRom(path);
  }

  void _play(BuildContext context, Rom rom) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GameScreen(rom: rom, controllers: controllers),
    ));
  }

  Future<void> _manage(BuildContext context, Rom rom) async {
    final l10n = context.l10n;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: Text(l10n.play),
              onTap: () => Navigator.pop(context, 'play'),
            ),
            ListTile(
              leading: const Icon(Icons.playlist_remove),
              title: Text(l10n.removeFromLibrary),
              onTap: () => Navigator.pop(context, 'remove'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(l10n.deleteFile),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case 'play':
        _play(context, rom);
        break;
      case 'remove':
        await AppState.of(context).removeFromLibrary(rom);
        break;
      case 'delete':
        final confirmed = await _confirm(
          context,
          l10n.confirmDeleteTitle,
          l10n.confirmDeleteBody(rom.displayName),
          l10n.delete,
        );
        if (confirmed && context.mounted) {
          await AppState.of(context).deleteRom(rom);
        }
        break;
    }
  }

  Future<bool> _confirm(
    BuildContext context,
    String title,
    String body,
    String confirmLabel,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.of(context);
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.libraryTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HelpScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addGame(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.addGame),
      ),
      body: state.loadingLibrary
          ? const Center(child: CircularProgressIndicator())
          : state.roms.isEmpty
              ? _EmptyLibrary(l10n: l10n)
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: state.roms.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final rom = state.roms[index];
                    return ListTile(
                      leading: const Icon(Icons.videogame_asset, size: 32),
                      title: Text(rom.displayName),
                      subtitle: Text(
                        '${rom.format} · '
                        '${l10n.sizeMegabytes(rom.sizeMegabytes.toStringAsFixed(1))}',
                      ),
                      onTap: () => _play(context, rom),
                      onLongPress: () => _manage(context, rom),
                    );
                  },
                ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.l10n});
  final L10n l10n;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videogame_asset_off, size: 64),
              const SizedBox(height: 16),
              Text(
                l10n.emptyLibraryTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.emptyLibraryBody,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
}
