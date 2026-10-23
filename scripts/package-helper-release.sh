#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
local_build=false
if [[ "${1:-}" == --local ]]; then local_build=true
elif [[ $# != 0 ]]; then echo "Usage: $0 [--local]" >&2; exit 2; fi
source_app="$project_dir/dist/app-store-release/PulseBar Helper.app"
[[ -d "$source_app" ]] || { echo 'Build the release distribution first.' >&2; exit 1; }
if ! "$local_build"; then
    : "${DEVELOPER_ID_APPLICATION_IDENTITY:?Developer ID Application identity required}"
    : "${DEVELOPER_ID_INSTALLER_IDENTITY:?Developer ID Installer identity required}"
    : "${NOTARY_KEYCHAIN_PROFILE:?Notarytool Keychain profile required}"
    [[ ! -f dist/app-store-release/LOCAL-ONLY.txt ]] || { echo 'Refusing to publish an ad-hoc build.' >&2; exit 1; }
fi
output="$project_dir/dist/helper-release"
mkdir -p "$output"
stage_dir="$(mktemp -d /tmp/pulsebar-helper-release.XXXXXX)"
trap 'rm -rf "$stage_dir"' EXIT
mkdir -p "$stage_dir/root/Applications"
helper_app="$stage_dir/root/Applications/PulseBar Helper.app"
ditto --norsrc --noextattr "$source_app" "$helper_app"
codesign --verify --deep --strict "$helper_app"
for executable in PulseBarHelper PulseBarHelperService; do
    architectures=" $(xcrun lipo -archs "$helper_app/Contents/MacOS/$executable") "
    [[ "$architectures" == *' arm64 '* && "$architectures" == *' x86_64 '* ]] || {
        echo "Helper is missing a required architecture: $executable" >&2; exit 1;
    }
done
if ! "$local_build"; then
    helper_signature="$(codesign -dv --verbose=4 "$helper_app" 2>&1)"
    [[ "$helper_signature" == *'TeamIdentifier=45Y6A23PTN'* ]]
    [[ "$helper_signature" == *'Authority=Developer ID Application:'* ]]
    ditto --norsrc --noextattr -c -k --keepParent "$helper_app" "$stage_dir/notarize.zip"
    xcrun notarytool submit "$stage_dir/notarize.zip" --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" \
        --wait --output-format json > "$output/app-notarization.json"
    python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["status"] == "Accepted"' "$output/app-notarization.json"
    xcrun stapler staple "$helper_app"
    xcrun stapler validate "$helper_app"
    spctl --assess --type execute "$helper_app"
fi
python3 scripts/create-helper-installer.py "$stage_dir" "$helper_app"
pkgbuild --root "$stage_dir/root" --install-location / \
    --component-plist "$stage_dir/components.plist" \
    --identifier io.github.monaco-io.PulseBar.Helper.pkg \
    --version "$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$helper_app/Contents/Info.plist")" \
    "$stage_dir/HelperComponent.pkg"
productbuild_command=(productbuild)
if ! "$local_build"; then productbuild_command+=(--sign "$DEVELOPER_ID_INSTALLER_IDENTITY" --timestamp); fi
"${productbuild_command[@]}" --distribution "$stage_dir/Distribution.xml" --resources Resources/HelperInstaller \
    --package-path "$stage_dir" "$stage_dir/PulseBar-Helper.pkg"
if "$local_build"; then
    printf 'LOCAL TEST BUILD ONLY. Not signed for public distribution or notarized.\n' > "$output/LOCAL-ONLY.txt"
else
    pkgutil --check-signature "$stage_dir/PulseBar-Helper.pkg"
    xcrun notarytool submit "$stage_dir/PulseBar-Helper.pkg" --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" \
        --wait --output-format json > "$output/pkg-notarization.json"
    python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["status"] == "Accepted"' "$output/pkg-notarization.json"
    xcrun stapler staple "$stage_dir/PulseBar-Helper.pkg"
    xcrun stapler validate "$stage_dir/PulseBar-Helper.pkg"
    spctl --assess --type install "$stage_dir/PulseBar-Helper.pkg"
    rm -f "$output/LOCAL-ONLY.txt"
fi
python3 scripts/verify-helper-installer.py "$stage_dir/PulseBar-Helper.pkg" "$helper_app"
cp "$stage_dir/PulseBar-Helper.pkg" "$output/PulseBar-Helper.pkg"
printf 'Helper installer: %s/PulseBar-Helper.pkg\n' "$output"
