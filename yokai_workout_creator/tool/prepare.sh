#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
project_dir="$PWD"
command -v flutter >/dev/null || { echo 'Flutter non trovato: consulta LEGGIMI.md.'; exit 1; }
setup_dir="$(mktemp -d)"
trap 'rm -rf "$setup_dir"' EXIT
flutter create --empty --no-pub --platforms=android --org=it.yokai --project-name=yokai_workout_creator "$setup_dir/scaffold"
for relative in gradlew gradlew.bat gradle/wrapper/gradle-wrapper.jar; do
  mkdir -p "$(dirname "$project_dir/android/$relative")"
  cp "$setup_dir/scaffold/android/$relative" "$project_dir/android/$relative"
done
if [ -f "$setup_dir/scaffold/android/local.properties" ]; then
  cp "$setup_dir/scaffold/android/local.properties" "$project_dir/android/local.properties"
fi
chmod +x android/gradlew
flutter pub get
