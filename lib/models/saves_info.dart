/// Where the emulator keeps in-game saves and save states on this device.
class SavesInfo {
  const SavesInfo({
    required this.savesDir,
    required this.statesDir,
    required this.isShared,
    required this.canOpenFolder,
  });

  /// Folder holding the `.srm` files, one per ROM.
  final String savesDir;

  /// Folder holding the ten save-state slots per ROM.
  final String statesDir;

  /// True when the folder is reachable from a file manager.
  final bool isShared;

  /// True when the platform can show the folder to the user.
  final bool canOpenFolder;

  static const SavesInfo unknown = SavesInfo(
    savesDir: '',
    statesDir: '',
    isShared: false,
    canOpenFolder: false,
  );

  bool get isKnown => savesDir.isNotEmpty;

  factory SavesInfo.fromJson(Map<String, dynamic> json) => SavesInfo(
        savesDir: json['savesDir'] as String? ?? '',
        statesDir: json['statesDir'] as String? ?? '',
        isShared: json['isShared'] as bool? ?? false,
        canOpenFolder: json['canOpenFolder'] as bool? ?? false,
      );
}

/// Outcome of asking the platform to reveal the saves folder.
enum OpenFolderResult { opened, noFileManager, unsupported }
