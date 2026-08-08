// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class L10nEn extends L10n {
  L10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'N64 Launcher';

  @override
  String get libraryTitle => 'Games';

  @override
  String get emptyLibraryTitle => 'No games yet';

  @override
  String get emptyLibraryBody =>
      'Add a ROM file (.z64, .n64, .v64, .zip) to start playing.';

  @override
  String get addGame => 'Add game';

  @override
  String get play => 'Play';

  @override
  String get loadState => 'Load save';

  @override
  String get removeFromLibrary => 'Remove from library';

  @override
  String get deleteFile => 'Delete file';

  @override
  String get settings => 'Settings';

  @override
  String get help => 'Help';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get remove => 'Remove';

  @override
  String get confirmRemoveTitle => 'Remove game';

  @override
  String confirmRemoveBody(String name) {
    return 'Remove \"$name\" from the library? The ROM file is kept.';
  }

  @override
  String get confirmDeleteTitle => 'Delete file';

  @override
  String confirmDeleteBody(String name) {
    return 'Permanently delete the ROM file for \"$name\"?';
  }

  @override
  String sizeMegabytes(String value) {
    return '$value MB';
  }

  @override
  String get saveSlots => 'Save slots';

  @override
  String get autoSlot => 'Auto (last point)';

  @override
  String slotNumber(int number) {
    return 'Slot $number';
  }

  @override
  String get emptySlot => 'Empty';

  @override
  String get noSaveStates => 'No save states for this game.';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System default';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsControls => 'On-screen controls';

  @override
  String get settingsShowControls => 'Show touch controls';

  @override
  String get settingsShowControlsSubtitle =>
      'Hidden automatically when a physical controller is connected.';

  @override
  String get settingsControlsOpacity => 'Controls opacity';

  @override
  String get settingsHaptics => 'Haptic feedback';

  @override
  String get settingsVideo => 'Video';

  @override
  String get settingsIntegerScaling => 'Integer scaling';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsSaves => 'Saves';

  @override
  String get savesFolder => 'Saves folder';

  @override
  String get savesOpenFolder => 'Open the folder';

  @override
  String get savesCopyPath => 'Copy path';

  @override
  String get savesPathCopied => 'Path copied';

  @override
  String get savesNoFileManager =>
      'No file manager could open the folder. Copy the path and browse to it.';

  @override
  String get savesImport => 'Import a save (.srm)';

  @override
  String get savesImportSubtitle => 'The file must carry the exact name of the ROM.';

  @override
  String savesImported(String name) {
    return '$name imported';
  }

  @override
  String get savesImportWrongType => 'Pick a .srm file.';

  @override
  String get savesImportFailed => 'The save could not be copied.';

  @override
  String get savesGrantAccess => 'Allow storage access';

  @override
  String get savesGrantAccessSubtitle =>
      'Needed to keep saves in a folder a file manager can reach.';

  @override
  String get savesUnavailable =>
      'The saves folder is not available on this platform.';

  @override
  String get controllerConnected => 'Controller connected';

  @override
  String get controllerDisconnected => 'Controller disconnected';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Resume';

  @override
  String get quitGame => 'Quit game';

  @override
  String get quitGameConfirm => 'Quit and return to the library?';

  @override
  String get saveState => 'Save state';

  @override
  String stateSaved(int number) {
    return 'State saved to slot $number';
  }

  @override
  String stateLoaded(int number) {
    return 'State loaded from slot $number';
  }

  @override
  String get loadingCore => 'Loading emulator core...';

  @override
  String get coreMissingTitle => 'Emulator core missing';

  @override
  String get coreMissingBody =>
      'The N64 core is not installed. Download it from Settings to play.';

  @override
  String get helpControlsTitle => 'Controls';

  @override
  String get helpControlsBody =>
      'Use the on-screen buttons to play. Connect a Bluetooth or USB controller and the touch controls disappear automatically.';

  @override
  String get helpSavesTitle => 'Saves';

  @override
  String get helpSavesBody =>
      'In-game saves are written to a .srm file named after the ROM, next to the ten save-state slots. Settings shows the folder, opens it in a file manager and imports an existing .srm.';

  @override
  String get helpRomsTitle => 'Games';

  @override
  String get helpRomsBody =>
      'Add your own .z64, .n64, .v64 or .zip ROM files. This app does not include any games.';
}
