import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/rom.dart';

class RomLibrary {
  static const String _key = 'library';

  Future<Directory> romsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'roms'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<List<Rom>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    final roms = <Rom>[];
    for (final entry in raw) {
      try {
        final rom = Rom.fromJson(jsonDecode(entry) as Map<String, dynamic>);
        if (rom.exists) roms.add(rom);
      } catch (_) {}
    }
    roms.sort((a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return roms;
  }

  Future<void> _persist(List<Rom> roms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      roms.map((r) => jsonEncode(r.toJson())).toList(),
    );
  }

  Future<List<Rom>> importFile(String sourcePath) async {
    final roms = await load();
    if (!isRomFile(sourcePath)) return roms;

    final dir = await romsDir();
    final target = File(p.join(dir.path, p.basename(sourcePath)));
    if (p.normalize(sourcePath) != p.normalize(target.path)) {
      await File(sourcePath).copy(target.path);
    }

    if (!roms.any((r) => p.equals(r.path, target.path))) {
      roms.add(Rom.fromFile(target));
      roms.sort((a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
      await _persist(roms);
    }
    return roms;
  }

  Future<List<Rom>> removeFromLibrary(Rom rom) async {
    final roms = await load();
    roms.removeWhere((r) => p.equals(r.path, rom.path));
    await _persist(roms);
    return roms;
  }

  Future<List<Rom>> deleteFile(Rom rom) async {
    final file = File(rom.path);
    if (file.existsSync()) {
      try {
        file.deleteSync();
      } catch (_) {}
    }
    return removeFromLibrary(rom);
  }
}
