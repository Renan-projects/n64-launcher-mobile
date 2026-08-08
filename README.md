# N64 Launcher (mobile)

A Nintendo 64 launcher and player for Android and iOS, built with Flutter. It
scans your own ROM files, runs them through an embedded libretro core, and draws
a translucent on-screen controller that disappears automatically when a physical
gamepad is connected.

**Languages:** English | [Français](docs/README.fr.md)

This is the mobile companion to the desktop [n64-launcher](../n64-launcher) and
the [n64-launcher-tv](../n64-launcher-tv) Android TV frontend. Unlike those two,
which drive an external emulator, the mobile app embeds the core so it can render
its own touch controls on top of the game and run on iOS.

## Features

- **Game library.** Add `.z64`, `.n64`, `.v64` or `.zip` ROM files. The app ships
  with no games.
- **Embedded emulation.** A libretro core (mupen64plus-next) runs inside the app
  and renders into an embedded surface.
- **Translucent touch controller.** A full N64 pad (stick, D-pad, A/B, four C
  buttons, L/R, Z, Start) drawn as a single overlay with adjustable opacity and
  haptics.
- **Automatic hiding.** When a Bluetooth or USB controller is connected, the
  touch overlay is hidden and physical input is used instead.
- **Save states.** Ten slots per game, saved on the device.
- **Localised.** English and French in the box; more can be added from ARB files.

## Saves

Two different things are saved, side by side:

| What | File | Written by |
| --- | --- | --- |
| In-game save (SRAM, EEPROM, Flash, Controller Pak) | `saves/<rom name>.srm` | the app, from the core's save RAM |
| Save state (10 slots) | `states/<rom name>.state0` … `.state9` | `retro_serialize` |

The `.srm` layout and naming match RetroArch's mupen64plus-next, so save files
can be moved between the two. It is written when it changes (every 5 s at most),
when the game is paused and when it is closed.

On Android the folders live in `/sdcard/N64Launcher/`, reachable from any file
manager; the app falls back to `Android/data/<package>/files` and then to
internal storage if storage access is denied, and moves existing saves along
when a better folder becomes available. On iOS they are in the app's `Documents`
folder, exposed to the Files app.

**Settings → Saves** shows the exact folder, opens it in the file manager and
imports an existing `.srm`.

## Architecture

```
lib/
  models/        rom, save slot, pad buttons, control layout, settings
  services/      settings store, rom library, emulator channel, controller monitor
  state/         app state (library + settings)
  ui/            home, settings, help, game screen, touch controls, save slots
  l10n/          app_en.arb, app_fr.arb
android/app/src/main/
  kotlin/.../    method channel bridge, platform view, controller observer
  cpp/           libretro host (JNI, dlopen + retro_run loop)
```

The Flutter layer is platform-agnostic. Native work is reached through two
channels:

- `org.renanprojects.n64/emulator` (method channel) — start/stop, pause/resume,
  input, save/load state, save-slot listing, core availability.
- `org.renanprojects.n64/controllers` (event channel) — the number of connected
  physical controllers, streamed as it changes.

The game surface is a platform view (`AndroidView` / `UiKitView`) with the touch
overlay composited on top of it in Flutter.

## Emulator core

The app loads a libretro core at runtime instead of bundling one. On Android the
native host (`android/app/src/main/cpp/n64host.c`) `dlopen`s the first `.so` found
in the app's `files/cores` directory, resolves the `retro_*` entry points, and
runs the core on a background thread. Input is fed from the Flutter overlay
through the method channel.

To play, place a `mupen64plus_next_libretro_android.so` (matching the device ABI)
in the app's `files/cores` directory. Until a core is present, the library and
controls work but starting a game reports the core as missing.

Video and audio output are wired as libretro callbacks; connecting them to the
embedded GL surface and an audio sink is the remaining native step and is where a
device is needed to iterate.

## Build

```bash
flutter pub get
flutter build apk --debug
```

Requirements: Flutter 3.44+, Android SDK 36, the Android NDK (for the native
host). The iOS project is generated but its native host is not implemented yet;
building it needs macOS and Xcode.

## License

See [LICENSE](LICENSE).
