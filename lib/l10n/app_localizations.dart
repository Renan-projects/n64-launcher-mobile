import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L10n
/// returned by `L10n.of(context)`.
///
/// Applications need to include `L10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L10n.localizationsDelegates,
///   supportedLocales: L10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L10n.supportedLocales
/// property.
abstract class L10n {
  L10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L10n of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n)!;
  }

  static const LocalizationsDelegate<L10n> delegate = _L10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'N64 Launcher'**
  String get appTitle;

  /// No description provided for @libraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get libraryTitle;

  /// No description provided for @emptyLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'No games yet'**
  String get emptyLibraryTitle;

  /// No description provided for @emptyLibraryBody.
  ///
  /// In en, this message translates to:
  /// **'Add a ROM file (.z64, .n64, .v64, .zip) to start playing.'**
  String get emptyLibraryBody;

  /// No description provided for @addGame.
  ///
  /// In en, this message translates to:
  /// **'Add game'**
  String get addGame;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @loadState.
  ///
  /// In en, this message translates to:
  /// **'Load save'**
  String get loadState;

  /// No description provided for @removeFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Remove from library'**
  String get removeFromLibrary;

  /// No description provided for @deleteFile.
  ///
  /// In en, this message translates to:
  /// **'Delete file'**
  String get deleteFile;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @confirmRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove game'**
  String get confirmRemoveTitle;

  /// No description provided for @confirmRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{name}\" from the library? The ROM file is kept.'**
  String confirmRemoveBody(String name);

  /// No description provided for @confirmDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete file'**
  String get confirmDeleteTitle;

  /// No description provided for @confirmDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete the ROM file for \"{name}\"?'**
  String confirmDeleteBody(String name);

  /// No description provided for @sizeMegabytes.
  ///
  /// In en, this message translates to:
  /// **'{value} MB'**
  String sizeMegabytes(String value);

  /// No description provided for @saveSlots.
  ///
  /// In en, this message translates to:
  /// **'Save slots'**
  String get saveSlots;

  /// No description provided for @autoSlot.
  ///
  /// In en, this message translates to:
  /// **'Auto (last point)'**
  String get autoSlot;

  /// No description provided for @slotNumber.
  ///
  /// In en, this message translates to:
  /// **'Slot {number}'**
  String slotNumber(int number);

  /// No description provided for @emptySlot.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get emptySlot;

  /// No description provided for @noSaveStates.
  ///
  /// In en, this message translates to:
  /// **'No save states for this game.'**
  String get noSaveStates;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsControls.
  ///
  /// In en, this message translates to:
  /// **'On-screen controls'**
  String get settingsControls;

  /// No description provided for @settingsShowControls.
  ///
  /// In en, this message translates to:
  /// **'Show touch controls'**
  String get settingsShowControls;

  /// No description provided for @settingsShowControlsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hidden automatically when a physical controller is connected.'**
  String get settingsShowControlsSubtitle;

  /// No description provided for @settingsControlsOpacity.
  ///
  /// In en, this message translates to:
  /// **'Controls opacity'**
  String get settingsControlsOpacity;

  /// No description provided for @settingsHaptics.
  ///
  /// In en, this message translates to:
  /// **'Haptic feedback'**
  String get settingsHaptics;

  /// No description provided for @settingsVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get settingsVideo;

  /// No description provided for @settingsIntegerScaling.
  ///
  /// In en, this message translates to:
  /// **'Integer scaling'**
  String get settingsIntegerScaling;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsSaves.
  ///
  /// In en, this message translates to:
  /// **'Saves'**
  String get settingsSaves;

  /// No description provided for @savesFolder.
  ///
  /// In en, this message translates to:
  /// **'Saves folder'**
  String get savesFolder;

  /// No description provided for @savesOpenFolder.
  ///
  /// In en, this message translates to:
  /// **'Open the folder'**
  String get savesOpenFolder;

  /// No description provided for @savesCopyPath.
  ///
  /// In en, this message translates to:
  /// **'Copy path'**
  String get savesCopyPath;

  /// No description provided for @savesPathCopied.
  ///
  /// In en, this message translates to:
  /// **'Path copied'**
  String get savesPathCopied;

  /// No description provided for @savesNoFileManager.
  ///
  /// In en, this message translates to:
  /// **'No file manager could open the folder. Copy the path and browse to it.'**
  String get savesNoFileManager;

  /// No description provided for @savesImport.
  ///
  /// In en, this message translates to:
  /// **'Import a save (.srm)'**
  String get savesImport;

  /// No description provided for @savesImportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The file must carry the exact name of the ROM.'**
  String get savesImportSubtitle;

  /// No description provided for @savesImported.
  ///
  /// In en, this message translates to:
  /// **'{name} imported'**
  String savesImported(String name);

  /// No description provided for @savesImportWrongType.
  ///
  /// In en, this message translates to:
  /// **'Pick a .srm file.'**
  String get savesImportWrongType;

  /// No description provided for @savesImportFailed.
  ///
  /// In en, this message translates to:
  /// **'The save could not be copied.'**
  String get savesImportFailed;

  /// No description provided for @savesGrantAccess.
  ///
  /// In en, this message translates to:
  /// **'Allow storage access'**
  String get savesGrantAccess;

  /// No description provided for @savesGrantAccessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Needed to keep saves in a folder a file manager can reach.'**
  String get savesGrantAccessSubtitle;

  /// No description provided for @savesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The saves folder is not available on this platform.'**
  String get savesUnavailable;

  /// No description provided for @controllerConnected.
  ///
  /// In en, this message translates to:
  /// **'Controller connected'**
  String get controllerConnected;

  /// No description provided for @controllerDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Controller disconnected'**
  String get controllerDisconnected;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @quitGame.
  ///
  /// In en, this message translates to:
  /// **'Quit game'**
  String get quitGame;

  /// No description provided for @quitGameConfirm.
  ///
  /// In en, this message translates to:
  /// **'Quit and return to the library?'**
  String get quitGameConfirm;

  /// No description provided for @saveState.
  ///
  /// In en, this message translates to:
  /// **'Save state'**
  String get saveState;

  /// No description provided for @stateSaved.
  ///
  /// In en, this message translates to:
  /// **'State saved to slot {number}'**
  String stateSaved(int number);

  /// No description provided for @stateLoaded.
  ///
  /// In en, this message translates to:
  /// **'State loaded from slot {number}'**
  String stateLoaded(int number);

  /// No description provided for @loadingCore.
  ///
  /// In en, this message translates to:
  /// **'Loading emulator core...'**
  String get loadingCore;

  /// No description provided for @coreMissingTitle.
  ///
  /// In en, this message translates to:
  /// **'Emulator core missing'**
  String get coreMissingTitle;

  /// No description provided for @coreMissingBody.
  ///
  /// In en, this message translates to:
  /// **'The N64 core is not installed. Download it from Settings to play.'**
  String get coreMissingBody;

  /// No description provided for @helpControlsTitle.
  ///
  /// In en, this message translates to:
  /// **'Controls'**
  String get helpControlsTitle;

  /// No description provided for @helpControlsBody.
  ///
  /// In en, this message translates to:
  /// **'Use the on-screen buttons to play. Connect a Bluetooth or USB controller and the touch controls disappear automatically.'**
  String get helpControlsBody;

  /// No description provided for @helpSavesTitle.
  ///
  /// In en, this message translates to:
  /// **'Saves'**
  String get helpSavesTitle;

  /// No description provided for @helpSavesBody.
  ///
  /// In en, this message translates to:
  /// **'In-game saves are written to a .srm file named after the ROM, next to the ten save-state slots. Settings shows the folder, opens it in a file manager and imports an existing .srm.'**
  String get helpSavesBody;

  /// No description provided for @helpRomsTitle.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get helpRomsTitle;

  /// No description provided for @helpRomsBody.
  ///
  /// In en, this message translates to:
  /// **'Add your own .z64, .n64, .v64 or .zip ROM files. This app does not include any games.'**
  String get helpRomsBody;
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  Future<L10n> load(Locale locale) {
    return SynchronousFuture<L10n>(lookupL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_L10nDelegate old) => false;
}

L10n lookupL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return L10nEn();
    case 'fr':
      return L10nFr();
  }

  throw FlutterError(
    'L10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
