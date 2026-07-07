// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class L10nFr extends L10n {
  L10nFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'N64 Launcher';

  @override
  String get libraryTitle => 'Jeux';

  @override
  String get emptyLibraryTitle => 'Aucun jeu';

  @override
  String get emptyLibraryBody =>
      'Ajoute un fichier ROM (.z64, .n64, .v64, .zip) pour commencer à jouer.';

  @override
  String get addGame => 'Ajouter un jeu';

  @override
  String get play => 'Jouer';

  @override
  String get loadState => 'Charger une sauvegarde';

  @override
  String get removeFromLibrary => 'Retirer de la bibliothèque';

  @override
  String get deleteFile => 'Supprimer le fichier';

  @override
  String get settings => 'Réglages';

  @override
  String get help => 'Aide';

  @override
  String get cancel => 'Annuler';

  @override
  String get delete => 'Supprimer';

  @override
  String get remove => 'Retirer';

  @override
  String get confirmRemoveTitle => 'Retirer le jeu';

  @override
  String confirmRemoveBody(String name) {
    return 'Retirer « $name » de la bibliothèque ? Le fichier ROM est conservé.';
  }

  @override
  String get confirmDeleteTitle => 'Supprimer le fichier';

  @override
  String confirmDeleteBody(String name) {
    return 'Supprimer définitivement le fichier ROM de « $name » ?';
  }

  @override
  String sizeMegabytes(String value) {
    return '$value Mo';
  }

  @override
  String get saveSlots => 'Emplacements de sauvegarde';

  @override
  String get autoSlot => 'Auto (dernier point)';

  @override
  String slotNumber(int number) {
    return 'Emplacement $number';
  }

  @override
  String get emptySlot => 'Vide';

  @override
  String get noSaveStates => 'Aucune sauvegarde d\'état pour ce jeu.';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get settingsLanguageSystem => 'Langue du système';

  @override
  String get settingsAppearance => 'Apparence';

  @override
  String get settingsControls => 'Commandes à l\'écran';

  @override
  String get settingsShowControls => 'Afficher les commandes tactiles';

  @override
  String get settingsShowControlsSubtitle =>
      'Masquées automatiquement quand une manette physique est connectée.';

  @override
  String get settingsControlsOpacity => 'Opacité des commandes';

  @override
  String get settingsHaptics => 'Retour haptique';

  @override
  String get settingsVideo => 'Vidéo';

  @override
  String get settingsIntegerScaling => 'Mise à l\'échelle entière';

  @override
  String get settingsAbout => 'À propos';

  @override
  String get controllerConnected => 'Manette connectée';

  @override
  String get controllerDisconnected => 'Manette déconnectée';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Reprendre';

  @override
  String get quitGame => 'Quitter le jeu';

  @override
  String get quitGameConfirm => 'Quitter et revenir à la bibliothèque ?';

  @override
  String get saveState => 'Sauvegarder l\'état';

  @override
  String stateSaved(int number) {
    return 'État sauvegardé dans l\'emplacement $number';
  }

  @override
  String stateLoaded(int number) {
    return 'État chargé depuis l\'emplacement $number';
  }

  @override
  String get loadingCore => 'Chargement du cœur d\'émulation...';

  @override
  String get coreMissingTitle => 'Cœur d\'émulation manquant';

  @override
  String get coreMissingBody =>
      'Le cœur N64 n\'est pas installé. Télécharge-le depuis les réglages pour jouer.';

  @override
  String get helpControlsTitle => 'Commandes';

  @override
  String get helpControlsBody =>
      'Utilise les boutons à l\'écran pour jouer. Connecte une manette Bluetooth ou USB et les commandes tactiles disparaissent automatiquement.';

  @override
  String get helpSavesTitle => 'Sauvegardes';

  @override
  String get helpSavesBody =>
      'Les sauvegardes en jeu et les sauvegardes d\'état sont stockées sur l\'appareil. Utilise le menu des emplacements pour garder plusieurs points par jeu.';

  @override
  String get helpRomsTitle => 'Jeux';

  @override
  String get helpRomsBody =>
      'Ajoute tes propres fichiers ROM .z64, .n64, .v64 ou .zip. Cette application ne contient aucun jeu.';
}
