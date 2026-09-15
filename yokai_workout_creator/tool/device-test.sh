#!/usr/bin/env bash
set -euo pipefail
# Collect exports while the emulator is still running, including on test failure.
trap 'mkdir -p build/device-qa; adb pull /sdcard/Pictures/YOKAI build/device-qa || true' EXIT
flutter test integration_test/device_test.dart --reporter expanded
