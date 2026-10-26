#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
stage_dir="$(mktemp -d /tmp/pulsebar-native-icon.XXXXXX)"
trap 'rm -rf "$stage_dir"' EXIT

# Commit the compiled catalog so Command Line Tools-only builds can also ship
# the native icon. Re-run this script with Xcode 26+ after editing AppIcon.icon.
xcrun actool "$project_dir/Resources/AppIcon.icon" \
    --compile "$stage_dir" --app-icon AppIcon --platform macosx \
    --minimum-deployment-target 13.0 --target-device mac \
    --output-partial-info-plist "$stage_dir/icon-info.plist"
test -s "$stage_dir/Assets.car"
cp "$stage_dir/Assets.car" "$project_dir/Resources/Assets.car"
