#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash tool/prepare.sh
flutter analyze
flutter test
flutter build apk --release
printf '\nAPK: %s/build/app/outputs/flutter-apk/app-release.apk\n' "$PWD"
