pipeline {
  agent none
  options {
    timestamps()
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '20'))
  }
  environment {
    APP_VERSION = '1.0.0'
    REPO = 'renan-projects/n64-launcher-mobile'
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
            stash name: 'android-apk', includes: 'build/app/outputs/flutter-apk/app-release.apk'
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
            archiveArtifacts artifacts: 'build/n64-launcher-mobile-unsigned.ipa', fingerprint: true
            stash name: 'ios-ipa', includes: 'build/n64-launcher-mobile-unsigned.ipa'
          }
        }
      }
    }
    stage('Release') {
      when { branch 'main' }
      agent { label 'android' }
      steps {
        unstash 'android-apk'
        unstash 'ios-ipa'
        sh '''#!/usr/bin/env bash
pip3 install --quiet "qrcode[pil]" 2>/dev/null \
  || pip3 install --quiet --break-system-packages "qrcode[pil]" 2>/dev/null \
  || true
'''
        catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE', message: 'Android release/QR step failed (missing renan-projects-gh-token credential or qrcode module)') {
          publishAndroidArtifact([
            apkPath:      'build/app/outputs/flutter-apk/app-release.apk',
            appName:      'N64 Launcher Mobile',
            version:      env.APP_VERSION,
            releaseNotes: "Automated build #${env.BUILD_NUMBER} — Android APK + iOS IPA (unsigned, install with SideStore).",
            githubToken:  'renan-projects-gh-token'
          ])
        }
        catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE', message: 'iOS IPA upload to the release failed') {
          withCredentials([string(credentialsId: 'renan-projects-gh-token', variable: 'GITHUB_TOKEN')]) {
            sh '''#!/usr/bin/env bash
set -euo pipefail
TAG="v${APP_VERSION}-build-${BUILD_NUMBER}"
gh release upload "$TAG" build/n64-launcher-mobile-unsigned.ipa --repo "$REPO" --clobber
'''
          }
        }
      }
    }
  }
}
