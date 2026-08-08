## Installation réparée + sauvegardes accessibles

- **L'app ciblait encore l'API 28**, ce qui déclenchait l'avertissement « conçue
  pour une version antérieure d'Android » et un refus d'installation sur les
  Android récents. Elle cible désormais l'API 36.
- **Les sauvegardes en jeu sont enfin conservées.** Le host natif lit et écrit la
  save RAM du cœur (SRAM, EEPROM, Flash, Controller Pak) dans
  `<dossier>/<nom de la ROM>.srm`, au format RetroArch. Écriture automatique
  toutes les 5 s si le contenu a changé, à la pause et en quittant le jeu.
- **Dossier public** `/sdcard/N64Launcher/` (`saves/`, `states/`, `system/`),
  visible depuis n'importe quel gestionnaire de fichiers et en USB. Les
  sauvegardes déjà présentes dans le stockage interne y sont déplacées
  automatiquement. Sur Android 11+, il faut accorder « Accès à tous les
  fichiers » depuis Réglages → Sauvegardes ; sans ça, l'app se replie sur son
  dossier privé et l'import de `.srm` reste disponible.
- **Réglages → Sauvegardes** : chemin affiché et copiable, bouton pour ouvrir le
  dossier dans le gestionnaire de fichiers, import direct d'un `.srm`.
- iOS : dossier `Documents` exposé dans l'app Fichiers, mêmes sauvegardes `.srm`.

### Où poser un fichier .srm

`/sdcard/N64Launcher/saves/<nom exact de la ROM>.srm`
(par exemple `Mario Kart 64.z64` → `Mario Kart 64.srm`), ou via
**Réglages → Sauvegardes → Importer une sauvegarde**.

> ⚠️ Signature différente des APK compilés par Jenkins : désinstalle l'ancienne
> application avant d'installer celle-ci. Les mises à jour suivantes
> s'installeront par-dessus sans rien perdre.
