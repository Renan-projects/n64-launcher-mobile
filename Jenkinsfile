pipeline {
  agent none
  options {
    timestamps()
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '20'))
  }
  stages {
    stage('Build') {
      parallel {
        stage('Android') {
          agent { label 'android' }
          steps {
            sh '''#!/usr/bin/env bash
set -euo pipefail
if ! command -v flutter >/dev/null 2>&1; then
  export FLUTTER_HOME="${WORKSPACE}/.flutter"
  if [ ! -x "${FLUTTER_HOME}/bin/flutter" ]; then
    git clone --depth 1 -b stable https://github.com/flutter/flutter.git "${FLUTTER_HOME}"
  fi
  export PATH="${FLUTTER_HOME}/bin:${PATH}"
fi
git config --global --add safe.directory '*' || true
flutter config --no-analytics >/dev/null 2>&1 || true
yes | flutter doctor --android-licenses >/dev/null 2>&1 || true
flutter pub get
flutter build apk --release
'''
            archiveArtifacts artifacts: 'build/app/outputs/flutter-apk/app-release.apk', fingerprint: true
          }
        }
        stage('iOS') {
          agent { label 'mac-arm64' }
          steps {
            sh '''#!/usr/bin/env bash
set -euo pipefail
if ! command -v flutter >/dev/null 2>&1; then
  export FLUTTER_HOME="${WORKSPACE}/.flutter"
  if [ ! -x "${FLUTTER_HOME}/bin/flutter" ]; then
    git clone --depth 1 -b stable https://github.com/flutter/flutter.git "${FLUTTER_HOME}"
  fi
  export PATH="${FLUTTER_HOME}/bin:${PATH}"
fi
git config --global --add safe.directory '*' || true
flutter config --no-analytics >/dev/null 2>&1 || true
flutter pub get
mkdir -p ios/Runner/cores
if [ ! -f ios/Runner/cores/mupen64plus_next.dylib ]; then
  curl -fSL -o /tmp/core-ios.zip "https://buildbot.libretro.com/nightly/apple/ios-arm64/latest/mupen64plus_next_libretro_ios.dylib.zip"
  unzip -o -q /tmp/core-ios.zip -d /tmp/core-ios
  cp /tmp/core-ios/*.dylib ios/Runner/cores/mupen64plus_next.dylib
fi
flutter build ios --release --no-codesign
rm -rf build/ipa-work
mkdir -p build/ipa-work/Payload
cp -R build/ios/iphoneos/Runner.app build/ipa-work/Payload/
( cd build/ipa-work && zip -qr ../n64-launcher-mobile-unsigned.ipa Payload )
'''
            archiveArtifacts artifacts: 'build/n64-launcher-mobile-unsigned.ipa', allowEmptyArchive: false, fingerprint: true
          }
        }
      }
    }
  }
}
