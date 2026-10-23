#!/bin/bash
# Run only after UI acceptance. This publishes the separately signed Helper,
# never a main-app archive or an App Store submission package.
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
[[ $# == 1 && "$1" =~ ^helper-v[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo "Usage: $0 helper-vVERSION" >&2; exit 2;
}
release_tag="$1"
package="$project_dir/dist/helper-release/PulseBar-Helper.pkg"
[[ -s "$package" && ! -f dist/helper-release/LOCAL-ONLY.txt ]] || {
    echo 'A signed, notarized production Helper installer is required.' >&2; exit 1;
}
python3 scripts/verify-helper-installer.py "$package"
python3 - "$package" "$release_tag" <<'PY'
import pathlib, re, subprocess, sys, tempfile
import xml.etree.ElementTree as ET
package, tag = sys.argv[1:]
signature = subprocess.check_output(['pkgutil', '--check-signature', package], text=True)
assert re.search(r'Developer ID Installer: .*\(45Y6A23PTN\)', signature), 'Unexpected installer signer'
with tempfile.TemporaryDirectory(prefix='pulsebar-publish-') as directory:
    expanded = pathlib.Path(directory) / 'package'
    subprocess.run(['pkgutil', '--expand', package, str(expanded)], check=True)
    reference = ET.parse(expanded / 'Distribution').find('pkg-ref[@version]')
    assert tag == 'helper-v' + reference.get('version'), 'Tag and installer versions differ'
PY
xcrun stapler validate "$package"
spctl --assess --type install "$package"
git rev-parse --verify "refs/tags/$release_tag"
[[ "$(git rev-list -n 1 "$release_tag")" == "$(git rev-parse HEAD)" ]] || {
    echo 'The helper tag must identify this checkout.' >&2; exit 1;
}
git diff --quiet
git diff --cached --quiet
notes="docs/releases/$release_tag.md"
[[ -s "$notes" ]] || { echo "Missing release notes: $notes" >&2; exit 1; }
# gh refuses to replace an existing release. Historical app downloads/feed stay intact.
gh release create "$release_tag" --repo monaco-io/PulseBar --verify-tag --draft \
    --title "PulseBar Helper ${release_tag#helper-v}" --notes-file "$notes" "$package"
gh release edit "$release_tag" --repo monaco-io/PulseBar --draft=false --latest=false
