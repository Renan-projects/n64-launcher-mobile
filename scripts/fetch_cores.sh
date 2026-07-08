#!/usr/bin/env bash
set -euo pipefail

CORE="mupen64plus_next_gles3_libretro_android.so"
BASE="https://buildbot.libretro.com/nightly/android/latest"
DEST="android/app/src/main/assets/cores"

for abi in arm64-v8a armeabi-v7a; do
  mkdir -p "$DEST/$abi"
  tmp="$(mktemp)"
  curl -fSL -o "$tmp" "$BASE/$abi/$CORE.zip"
  unzip -o -q "$tmp" -d "$DEST/$abi"
  rm -f "$tmp"
  echo "installed $abi/$CORE"
done

mkdir -p ios/Runner/cores
tmp="$(mktemp)"
curl -fSL -o "$tmp" "https://buildbot.libretro.com/nightly/apple/ios-arm64/latest/mupen64plus_next_libretro_ios.dylib.zip"
unzip -o -q "$tmp" -d /tmp/core-ios
cp /tmp/core-ios/*.dylib ios/Runner/cores/mupen64plus_next.dylib
rm -f "$tmp"
echo "installed ios core"
