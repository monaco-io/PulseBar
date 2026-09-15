#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
version="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)"
release_tag="${1:-v$version}"
[[ "$release_tag" == "v$version" ]] || { echo "Tag must match Info.plist: v$version" >&2; exit 1; }
[[ "${SKIP_BUILD:-0}" == 1 ]] || ./scripts/build-app.sh
release_dir="$project_dir/dist/release"
stage_dir="$(mktemp -d /tmp/pulsebar-release.XXXXXX)"
trap 'rm -rf "$stage_dir"' EXIT
mkdir -p "$stage_dir/image" "$stage_dir/updates" "$release_dir"
app_dir="$stage_dir/image/PulseBar.app"
ditto --norsrc --noextattr dist/PulseBar.app "$app_dir"
# Optional Developer ID notarization, after signing and before making the final archives.
if [[ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
    [[ -n "${CODE_SIGN_IDENTITY:-}" ]] || { echo 'Notarization requires CODE_SIGN_IDENTITY' >&2; exit 1; }
    ditto --norsrc --noextattr -c -k --keepParent "$app_dir" "$stage_dir/notarize.zip"
    xcrun notarytool submit "$stage_dir/notarize.zip" --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" --wait
    xcrun stapler staple "$app_dir"
    xcrun stapler validate "$app_dir"
fi
codesign --verify --deep --strict "$app_dir"
lipo "$app_dir/Contents/MacOS/PulseBar" -verify_arch arm64 x86_64
ditto --norsrc --noextattr -c -k --keepParent "$app_dir" "$stage_dir/updates/PulseBar.zip"
notes="$project_dir/docs/releases/$release_tag.md"
[[ -s "$notes" ]] || { echo "Release notes missing: $notes" >&2; exit 1; }
cp "$notes" "$stage_dir/updates/PulseBar.md"
sparkle_tools=("$project_dir"/.build/artifacts/*/Sparkle/bin)
[[ ${#sparkle_tools[@]} == 1 ]] || { echo 'Expected exactly one Sparkle tools directory' >&2; exit 1; }
sparkle_bin="${sparkle_tools[0]}"
signing_flags=(--account monaco-io.PulseBar)
if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
    # Keep the key off command lines, release artifacts and logs.
    umask 077
    printf '%s' "$SPARKLE_PRIVATE_KEY" > "$stage_dir/signing-key"
    unset SPARKLE_PRIVATE_KEY
    signing_flags=(--ed-key-file "$stage_dir/signing-key")
fi
"$sparkle_bin/generate_appcast" "${signing_flags[@]}" \
    --download-url-prefix "https://github.com/monaco-io/PulseBar/releases/download/$release_tag/" \
    --link 'https://github.com/monaco-io/PulseBar' \
    --embed-release-notes --maximum-deltas 0 "$stage_dir/updates"
"$sparkle_bin/sign_update" "${signing_flags[@]}" --verify "$stage_dir/updates/appcast.xml"
archive_signature="$(python3 - "$stage_dir/updates/appcast.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
print(ET.parse(sys.argv[1]).find('channel/item/enclosure').attrib['{http://www.andymatuschak.org/xml-namespaces/sparkle}edSignature'])
PY
)"
"$sparkle_bin/sign_update" "${signing_flags[@]}" --verify "$stage_dir/updates/PulseBar.zip" "$archive_signature"
ln -s /Applications "$stage_dir/image/Applications"
cp docs/INSTALL.txt "$stage_dir/image/安装说明 - Installation.txt"
hdiutil create -quiet -volname "PulseBar $version" -srcfolder "$stage_dir/image" \
    -format UDZO -ov "$release_dir/PulseBar.dmg"
cp "$stage_dir/updates/PulseBar.zip" "$release_dir/PulseBar.zip"
cp "$stage_dir/updates/appcast.xml" "$release_dir/appcast.xml"
cp docs/INSTALL.txt "$release_dir/INSTALL.txt"
cp "$notes" "$release_dir/RELEASE_NOTES.md"
(
    cd "$release_dir"
    shasum -a 256 PulseBar.dmg PulseBar.zip appcast.xml INSTALL.txt RELEASE_NOTES.md > SHA256SUMS.txt
)
python3 scripts/verify-release.py "$release_dir" "$release_tag"
printf 'Release ready: %s\n' "$release_dir"
