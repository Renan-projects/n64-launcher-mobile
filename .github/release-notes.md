## Sauvegardes accessibles

- **Les sauvegardes en jeu sont enfin conservées.** Le host natif lit et écrit la
  save RAM du core (SRAM, EEPROM, Flash, Controller Pak) dans
  `<dossier>/<nom de la ROM>.srm`, au format RetroArch. Écriture automatique
  toutes les 5 s si le contenu a changé, à la pause et en quittant le jeu.
- **Nouveau dossier public** `/sdcard/N64Launcher/` (`saves/`, `states/`,
  `system/`), visible depuis n'importe quel gestionnaire de fichiers et en USB.
  Les sauvegardes déjà présentes dans le stockage interne y sont déplacées
  automatiquement au premier lancement.
- **Réglages → Sauvegardes** : chemin affiché et copiable, bouton pour ouvrir le
  dossier dans le gestionnaire de fichiers, import direct d'un `.srm`, et demande
  d'autorisation de stockage si nécessaire.
- iOS : dossier `Documents` exposé dans l'app Fichiers, mêmes sauvegardes `.srm`.

### Où poser un fichier .srm

`/sdcard/N64Launcher/saves/<nom exact de la ROM>.srm`
(par exemple `Mario Kart 64.z64` → `Mario Kart 64.srm`), ou via
**Réglages → Sauvegardes → Importer une sauvegarde**.

> ⚠️ Cette version est signée avec une nouvelle clé : désinstalle l'ancienne
> application avant d'installer l'APK. Les mises à jour suivantes s'installeront
> par-dessus sans rien perdre.
