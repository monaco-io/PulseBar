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
    : "${NOTARY_KEYCHAIN_PROFILE:?Notarytool Keychain profile required}"
    [[ ! -f dist/app-store-release/LOCAL-ONLY.txt ]] || { echo 'Refusing to publish an ad-hoc build.' >&2; exit 1; }
fi
output="$project_dir/dist/helper-release"
mkdir -p "$output"
stage_dir="$(mktemp -d /tmp/pulsebar-helper-release.XXXXXX)"
trap 'rm -rf "$stage_dir"' EXIT
mkdir -p "$stage_dir/image"
helper_app="$stage_dir/image/PulseBar Helper.app"
ditto --norsrc --noextattr "$source_app" "$helper_app"
codesign --verify --deep --strict "$helper_app"
lipo "$helper_app/Contents/MacOS/PulseBarHelper" -verify_arch arm64 x86_64
lipo "$helper_app/Contents/MacOS/PulseBarHelperService" -verify_arch arm64 x86_64
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
ln -s /Applications "$stage_dir/image/Applications"
cp Resources/DMG/HelperFinderLayout.dsstore "$stage_dir/image/.DS_Store"
hdiutil create -quiet -volname 'PulseBar Helper' -srcfolder "$stage_dir/image" -format UDZO \
    "$stage_dir/PulseBar-Helper.dmg"
if "$local_build"; then
    printf 'LOCAL TEST BUILD ONLY. Not signed for public distribution or notarized.\n' > "$output/LOCAL-ONLY.txt"
else
    codesign --sign "$DEVELOPER_ID_APPLICATION_IDENTITY" --timestamp "$stage_dir/PulseBar-Helper.dmg"
    xcrun notarytool submit "$stage_dir/PulseBar-Helper.dmg" --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" \
        --wait --output-format json > "$output/dmg-notarization.json"
    python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["status"] == "Accepted"' "$output/dmg-notarization.json"
    xcrun stapler staple "$stage_dir/PulseBar-Helper.dmg"
    xcrun stapler validate "$stage_dir/PulseBar-Helper.dmg"
    rm -f "$output/LOCAL-ONLY.txt"
fi
hdiutil verify -quiet "$stage_dir/PulseBar-Helper.dmg"
cp "$stage_dir/PulseBar-Helper.dmg" "$output/PulseBar-Helper.dmg"
printf 'Helper disk image: %s/PulseBar-Helper.dmg\n' "$output"
