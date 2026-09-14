#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
./scripts/swift-local.sh build -c release --product PulseBar
binary_dir="$(./scripts/swift-local.sh build -c release --show-bin-path)"
stage_dir="$(mktemp -d /tmp/pulsebar-build.XXXXXX)"
trap 'rm -rf "$stage_dir"' EXIT
app_dir="$stage_dir/PulseBar.app"
mkdir -p "$project_dir/dist"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/PulseBar" "$app_dir/Contents/MacOS/PulseBar"
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
for resource_bundle in "$binary_dir"/PulseBar_*.bundle; do
    [[ -d "$resource_bundle" ]] || continue
    ditto --norsrc --noextattr "$resource_bundle" "$app_dir/Contents/Resources/$(basename "$resource_bundle")"
done
for localization in Resources/*.lproj; do
    [[ -d "$localization" ]] || continue
    ditto --norsrc --noextattr "$localization" "$app_dir/Contents/Resources/$(basename "$localization")"
done
icon_flags=()
if [[ -f "$project_dir/.build/toolchain-compat/overlay.json" ]]; then
    icon_flags=(-vfsoverlay "$project_dir/.build/toolchain-compat/overlay.json")
fi
swift "${icon_flags[@]}" scripts/make-icon.swift "$stage_dir/AppIcon.iconset"
iconutil -c icns "$stage_dir/AppIcon.iconset" -o "$app_dir/Contents/Resources/AppIcon.icns"
xattr -cr "$app_dir"
codesign --force --sign - "$app_dir"
codesign --verify --strict "$app_dir"
# Sign outside synced folders, whose providers may add Finder metadata while
# codesign is reading the bundle. Also provide a metadata-free archive.
ditto --norsrc --noextattr "$app_dir" "$project_dir/dist/PulseBar.app"
ditto --norsrc --noextattr -c -k --keepParent "$app_dir" "$project_dir/dist/PulseBar.zip"
printf 'Built %s\n' "$project_dir/dist/PulseBar.app"
