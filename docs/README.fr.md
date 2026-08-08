# N64 Launcher (mobile)

Un lanceur et lecteur Nintendo 64 pour Android et iOS, développé avec Flutter. Il
liste tes propres fichiers ROM, les exécute via un cœur libretro intégré et
affiche une manette tactile translucide qui disparaît automatiquement quand une
manette physique est connectée.

**Langues :** [English](../README.md) | Français

C'est le pendant mobile du [n64-launcher](../../n64-launcher) pour ordinateur et
du frontend Android TV [n64-launcher-tv](../../n64-launcher-tv). Contrairement à
ces deux-là, qui pilotent un émulateur externe, l'app mobile intègre le cœur pour
pouvoir dessiner ses propres commandes tactiles par-dessus le jeu et tourner sur
iOS.

## Fonctionnalités

- **Bibliothèque de jeux.** Ajoute des fichiers ROM `.z64`, `.n64`, `.v64` ou
  `.zip`. L'application ne contient aucun jeu.
- **Émulation intégrée.** Un cœur libretro (mupen64plus-next) tourne dans l'app et
  rend dans une surface intégrée.
- **Manette tactile translucide.** Une manette N64 complète (stick, croix
  directionnelle, A/B, quatre boutons C, L/R, Z, Start) dessinée en un seul
  overlay, avec opacité réglable et retour haptique.
- **Masquage automatique.** Quand une manette Bluetooth ou USB est connectée,
  l'overlay tactile est masqué et l'entrée physique est utilisée.
- **Sauvegardes d'état.** Dix emplacements par jeu, stockés sur l'appareil.
- **Traduite.** Anglais et français inclus ; d'autres langues peuvent être
  ajoutées via les fichiers ARB.

## Sauvegardes

Deux choses différentes sont enregistrées, côte à côte :

| Quoi | Fichier | Écrit par |
| --- | --- | --- |
| Sauvegarde en jeu (SRAM, EEPROM, Flash, Controller Pak) | `saves/<nom de la rom>.srm` | l'app, depuis la save RAM du cœur |
| Sauvegarde d'état (10 emplacements) | `states/<nom de la rom>.state0` … `.state9` | `retro_serialize` |

Le format et le nommage du `.srm` sont ceux de mupen64plus-next dans RetroArch :
les fichiers passent de l'un à l'autre. L'écriture a lieu quand le contenu change
(au plus toutes les 5 s), à la pause et en quittant le jeu.

Sur Android les dossiers sont dans `/sdcard/N64Launcher/`, accessibles depuis
n'importe quel gestionnaire de fichiers ; l'app se replie sur
`Android/data/<paquet>/files` puis sur le stockage interne si l'accès est
refusé, et déplace les sauvegardes existantes dès qu'un meilleur dossier est
disponible. Sur iOS elles sont dans le dossier `Documents` de l'app, exposé à
l'application Fichiers.

**Réglages → Sauvegardes** affiche le dossier exact, l'ouvre dans le
gestionnaire de fichiers et importe un `.srm` existant.

## Architecture

```
lib/
  models/        rom, emplacement de sauvegarde, boutons, disposition, réglages
  services/      stockage réglages, bibliothèque rom, canal émulateur, manettes
  state/         état de l'app (bibliothèque + réglages)
  ui/            accueil, réglages, aide, écran de jeu, commandes tactiles
  l10n/          app_en.arb, app_fr.arb
android/app/src/main/
  kotlin/.../    pont method channel, platform view, observateur de manettes
  cpp/           hôte libretro (JNI, dlopen + boucle retro_run)
```

La couche Flutter est indépendante de la plateforme. Le natif est atteint via deux
canaux :

- `org.renanprojects.n64/emulator` (method channel) — démarrer/arrêter,
  pause/reprise, entrée, sauvegarde/chargement d'état, liste des emplacements,
  disponibilité du cœur.
- `org.renanprojects.n64/controllers` (event channel) — le nombre de manettes
  physiques connectées, diffusé à chaque changement.

La surface de jeu est une platform view (`AndroidView` / `UiKitView`) avec
l'overlay tactile composé par-dessus dans Flutter.

## Cœur d'émulation

L'app charge un cœur libretro à l'exécution au lieu d'en embarquer un. Sur Android
l'hôte natif (`android/app/src/main/cpp/n64host.c`) fait un `dlopen` du premier
`.so` trouvé dans le dossier `files/cores` de l'app, résout les points d'entrée
`retro_*` et exécute le cœur sur un thread d'arrière-plan. L'entrée provient de
l'overlay tactile via le method channel.

Pour jouer, place un `mupen64plus_next_libretro_android.so` (correspondant à l'ABI
de l'appareil) dans le dossier `files/cores` de l'app. Tant qu'aucun cœur n'est
présent, la bibliothèque et les commandes fonctionnent mais démarrer un jeu
signale que le cœur est manquant.

La sortie vidéo et audio est câblée en tant que callbacks libretro ; les relier à
la surface GL intégrée et à une sortie audio est l'étape native restante, et c'est
là qu'un appareil est nécessaire pour itérer.

## Compilation

```bash
flutter pub get
flutter build apk --debug
```

Prérequis : Flutter 3.44+, Android SDK 36, le NDK Android (pour l'hôte natif). Le
projet iOS est généré mais son hôte natif n'est pas encore implémenté ; le
compiler nécessite macOS et Xcode.

## Licence

Voir [LICENSE](../LICENSE).
