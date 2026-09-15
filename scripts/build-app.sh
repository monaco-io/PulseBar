#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
# Build each architecture with SwiftPM's native build system. Multi-arch --arch
# selects XCBuild, which is unavailable on Command Line Tools-only Macs.
binary_dirs=()
for cpu_arch in arm64 x86_64; do
    build_flags=(-c release --triple "$cpu_arch-apple-macosx13.0")
    ./scripts/swift-local.sh build "${build_flags[@]}" --product PulseBar
    binary_dirs+=("$(./scripts/swift-local.sh build "${build_flags[@]}" --show-bin-path)")
done
binary_dir="${binary_dirs[0]}"
stage_dir="$(mktemp -d /tmp/pulsebar-build.XXXXXX)"
trap 'rm -rf "$stage_dir"' EXIT
app_dir="$stage_dir/PulseBar.app"
mkdir -p "$project_dir/dist"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources" "$app_dir/Contents/Frameworks"
lipo -create "${binary_dirs[0]}/PulseBar" "${binary_dirs[1]}/PulseBar" -output "$app_dir/Contents/MacOS/PulseBar"
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
for resource_bundle in "$binary_dir"/PulseBar_*.bundle; do
    [[ -d "$resource_bundle" ]] || continue
    ditto --norsrc --noextattr "$resource_bundle" "$app_dir/Contents/Resources/$(basename "$resource_bundle")"
done
for localization in Resources/*.lproj; do
    [[ -d "$localization" ]] || continue
    ditto --norsrc --noextattr "$localization" "$app_dir/Contents/Resources/$(basename "$localization")"
done
frameworks=("$project_dir"/.build/artifacts/*/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework)
[[ ${#frameworks[@]} == 1 ]] || { echo 'Expected exactly one Sparkle artifact' >&2; exit 1; }
sparkle_framework="${frameworks[0]}"
[[ -d "$sparkle_framework" ]] || { echo 'Sparkle framework is missing' >&2; exit 1; }
ditto --norsrc --noextattr "$sparkle_framework" "$app_dir/Contents/Frameworks/Sparkle.framework"
cp Resources/Sparkle-LICENSE.txt "$app_dir/Contents/Resources/Sparkle-LICENSE.txt"
icon_flags=()
if [[ -f "$project_dir/.build/toolchain-compat/overlay.json" ]]; then
    icon_flags=(-vfsoverlay "$project_dir/.build/toolchain-compat/overlay.json")
fi
swift "${icon_flags[@]}" scripts/make-icon.swift "$stage_dir/AppIcon.iconset"
iconutil -c icns "$stage_dir/AppIcon.iconset" -o "$app_dir/Contents/Resources/AppIcon.icns"
xattr -cr "$app_dir"
# Sparkle includes signed nested helpers. Re-sign inside out only for Developer ID builds.
if [[ -n "${CODE_SIGN_IDENTITY:-}" ]]; then
    framework="$app_dir/Contents/Frameworks/Sparkle.framework/Versions/B"
    for component in XPCServices/Downloader.xpc XPCServices/Installer.xpc Updater.app Autoupdate; do
        codesign --force --options runtime --timestamp --sign "$CODE_SIGN_IDENTITY" "$framework/$component"
    done
    codesign --force --options runtime --timestamp --sign "$CODE_SIGN_IDENTITY" "$app_dir/Contents/Frameworks/Sparkle.framework"
    codesign --force --options runtime --timestamp --sign "$CODE_SIGN_IDENTITY" "$app_dir"
else
    codesign --force --sign - "$app_dir"
fi
codesign --verify --deep --strict "$app_dir"
lipo "$app_dir/Contents/MacOS/PulseBar" -verify_arch arm64 x86_64
# Never merge into a previous app bundle: removed resources/frameworks must stay removed.
rm -rf "$project_dir/dist/PulseBar.app"
ditto --norsrc --noextattr "$app_dir" "$project_dir/dist/PulseBar.app"
ditto --norsrc --noextattr -c -k --keepParent "$app_dir" "$project_dir/dist/PulseBar.zip"
printf 'Built %s (arm64 + x86_64)\n' "$project_dir/dist/PulseBar.app"
