#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
local_build=false
configuration=release
for argument in "$@"; do
    case "$argument" in
        --local) local_build=true ;;
        --debug) configuration=debug ;;
        *) echo "Usage: $0 [--local] [--debug]" >&2; exit 2 ;;
    esac
done
if ! "$local_build"; then
    [[ "$configuration" == release ]] || { echo 'Distribution requires release configuration.' >&2; exit 1; }
    : "${APP_STORE_APPLICATION_IDENTITY:?Mac App Store application signing identity required}"
    : "${APP_STORE_INSTALLER_IDENTITY:?Mac Installer Distribution signing identity required}"
    : "${DEVELOPER_ID_APPLICATION_IDENTITY:?Developer ID Application signing identity required for the helper}"
    : "${APP_STORE_PROFILE:?Path to the Mac App Store provisioning profile required}"
fi
export PULSEBAR_DISTRIBUTION=app-store
scratch="${PULSEBAR_STORE_SCRATCH_PATH:-$project_dir/.build/store-$configuration}"
binary_dirs=()
architectures=(arm64 x86_64)
if [[ "$configuration" == debug ]]; then architectures=("$(uname -m)"); fi
for cpu_arch in "${architectures[@]}"; do
    build_flags=(--build-system native --scratch-path "$scratch" -c "$configuration" --triple "$cpu_arch-apple-macosx13.0" --jobs 4)
    ./scripts/swift-local.sh build "${build_flags[@]}"
    binary_dirs+=("$(./scripts/swift-local.sh build "${build_flags[@]}" --show-bin-path)")
done
output="$project_dir/dist/app-store-$configuration"
mkdir -p "$output"
stage_dir="$(mktemp -d /tmp/pulsebar-store.XXXXXX)"
trap 'rm -rf "$stage_dir"' EXIT
app_dir="$stage_dir/PulseBar.app"
helper_dir="$stage_dir/PulseBar Helper.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
mkdir -p "$helper_dir/Contents/MacOS" "$helper_dir/Contents/Resources" "$helper_dir/Contents/Library/LaunchAgents"
for product in PulseBar PulseBarHelper PulseBarHelperService; do
    destination="$helper_dir/Contents/MacOS/$product"
    [[ "$product" != PulseBar ]] || destination="$app_dir/Contents/MacOS/PulseBar"
    inputs=()
    for binary_dir in "${binary_dirs[@]}"; do inputs+=("$binary_dir/$product"); done
    if [[ ${#inputs[@]} == 1 ]]; then cp "${inputs[0]}" "$destination"
    else lipo -create "${inputs[@]}" -output "$destination"; fi
done
for bundle in "$app_dir" "$helper_dir"; do
    ditto --norsrc --noextattr "${binary_dirs[0]}/PulseBar_SpeedCore.bundle" "$bundle/Contents/Resources/PulseBar_SpeedCore.bundle"
    cp Resources/AppStore/PrivacyInfo.xcprivacy "$bundle/Contents/Resources/PrivacyInfo.xcprivacy"
done
for localization in Resources/*.lproj; do
    ditto --norsrc --noextattr "$localization" "$app_dir/Contents/Resources/$(basename "$localization")"
done
cp Resources/Helper/*.plist "$helper_dir/Contents/Library/LaunchAgents/"
python3 - "$app_dir" "$helper_dir" <<'PY'
import pathlib, plistlib, sys
app, helper = map(pathlib.Path, sys.argv[1:])
base = plistlib.loads(pathlib.Path('Resources/Info.plist').read_bytes())
base = {k:v for k,v in base.items() if not k.startswith('SU') and k != 'PulseBarReleasesURL'}
base.update(CFBundleIdentifier='io.github.monaco-io.PulseBar',
            CFBundleSupportedPlatforms=['MacOSX'], ITSAppUsesNonExemptEncryption=False,
            NSHumanReadableCopyright='Copyright © 2026 Xuze Lu')
(app/'Contents/Info.plist').write_bytes(plistlib.dumps(base))
# SwiftPM only supplies the development region for this resource-only bundle.
# App Store validation still requires its own bundle identifier (ITMS-90276).
resource_info = app/'Contents/Resources/PulseBar_SpeedCore.bundle/Info.plist'
resource = plistlib.loads(resource_info.read_bytes())
resource.update(CFBundleIdentifier=base['CFBundleIdentifier'] + '.SpeedCoreResources',
                CFBundlePackageType='BNDL', CFBundleVersion='1', CFBundleShortVersionString='1.0')
resource_info.write_bytes(plistlib.dumps(resource))
base.update(CFBundleIdentifier='io.github.monaco-io.PulseBar.Helper', CFBundleName='PulseBar Helper',
            CFBundleDisplayName='PulseBar Helper', CFBundleExecutable='PulseBarHelper',
            CFBundleShortVersionString='1.0.1', CFBundleVersion='2', LSUIElement=False)
(helper/'Contents/Info.plist').write_bytes(plistlib.dumps(base))
PY
icon_command=(swift)
if [[ -f "$project_dir/.build/toolchain-compat/overlay.json" ]]; then
    icon_command+=(-vfsoverlay "$project_dir/.build/toolchain-compat/overlay.json")
fi
"${icon_command[@]}" scripts/make-icon.swift "$stage_dir/AppIcon.iconset"
iconutil -c icns "$stage_dir/AppIcon.iconset" -o "$stage_dir/AppIcon.icns"
cp "$stage_dir/AppIcon.icns" "$app_dir/Contents/Resources/AppIcon.icns"
cp "$stage_dir/AppIcon.icns" "$helper_dir/Contents/Resources/AppIcon.icns"
entitlements="$stage_dir/PulseBar.entitlements"
cp Resources/AppStore/PulseBar.entitlements "$entitlements"
if ! "$local_build"; then
    cp "$APP_STORE_PROFILE" "$app_dir/Contents/embedded.provisionprofile"
    security cms -D -i "$APP_STORE_PROFILE" > "$stage_dir/profile.plist"
    python3 - "$stage_dir/profile.plist" "$entitlements" <<'PY'
import datetime, pathlib, plistlib, sys
profile = plistlib.loads(pathlib.Path(sys.argv[1]).read_bytes())
assert profile['ExpirationDate'] > datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None), 'Expired provisioning profile'
assert '45Y6A23PTN' in profile['TeamIdentifier'], 'Unexpected developer team'
assert not profile.get('ProvisionedDevices'), 'Use a Mac App Store distribution profile'
p = pathlib.Path(sys.argv[2]); ent = plistlib.loads(p.read_bytes())
source = profile['Entitlements']
assert source.get('com.apple.application-identifier') == '45Y6A23PTN.io.github.monaco-io.PulseBar', 'Incorrect App ID'
for key in ('com.apple.application-identifier', 'com.apple.developer.team-identifier'):
    ent[key] = source[key]
if source.get('beta-reports-active'):
    ent['beta-reports-active'] = True
p.write_bytes(plistlib.dumps(ent))
PY
fi
xattr -cr "$app_dir" "$helper_dir"
if "$local_build"; then
    codesign --force --sign - --identifier io.github.monaco-io.PulseBar.HelperService "$helper_dir/Contents/MacOS/PulseBarHelperService"
    codesign --force --sign - "$helper_dir"
    codesign --force --sign - --entitlements "$entitlements" "$app_dir"
else
    codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION_IDENTITY" --identifier io.github.monaco-io.PulseBar.HelperService "$helper_dir/Contents/MacOS/PulseBarHelperService"
    codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION_IDENTITY" "$helper_dir"
    codesign --force --options runtime --timestamp --sign "$APP_STORE_APPLICATION_IDENTITY" --entitlements "$entitlements" "$app_dir"
    productbuild --component "$app_dir" /Applications --sign "$APP_STORE_INSTALLER_IDENTITY" "$stage_dir/PulseBar-AppStore.pkg"
fi
codesign --verify --deep --strict "$app_dir"
codesign --verify --deep --strict "$helper_dir"
python3 scripts/verify-store-build.py "$app_dir" "$helper_dir" "$configuration"
for name in PulseBar.app 'PulseBar Helper.app'; do
    rm -rf "$output/$name"
    ditto --norsrc --noextattr "$stage_dir/$name" "$output/$name"
done
if "$local_build"; then
    printf 'LOCAL TEST BUILD ONLY. No App Store upload or notarization performed.\n' > "$output/LOCAL-ONLY.txt"
else
    cp "$stage_dir/PulseBar-AppStore.pkg" "$output/"
    rm -f "$output/LOCAL-ONLY.txt"
fi
printf 'Built store app and companion: %s\n' "$output"
