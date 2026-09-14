#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
tools_dir="$(xcode-select -p)"
compat_dir="$project_dir/.build/toolchain-compat"
manifest_dir="$tools_dir/usr/lib/swift/pm/ManifestAPI"
extra_flags=()

# Isolate leftovers from partially upgraded Command Line Tools in this
# project's build directory. The installed toolchain is never modified.
if [[ -f "$tools_dir/usr/include/swift/module.modulemap" && -f "$tools_dir/usr/include/swift/bridging.modulemap" ]]; then
    mkdir -p "$compat_dir"
    printf '// Empty compatibility overlay.\n' > "$compat_dir/empty.modulemap"
    /usr/bin/python3 - "$compat_dir" "$tools_dir" <<'PY'
import json, pathlib, sys
root, toolchain = map(pathlib.Path, sys.argv[1:])
overlay = {"version": 0, "roots": [{"type": "file", "name": str(toolchain / "usr/include/swift/module.modulemap"), "external-contents": str(root / "empty.modulemap")} ]}
(root / "overlay.json").write_text(json.dumps(overlay))
PY
    extra_flags=(-Xswiftc -vfsoverlay -Xswiftc "$compat_dir/overlay.json")
fi

if [[ -d "$manifest_dir" ]] && /usr/bin/grep -q 'public enum SwiftVersion' "$manifest_dir/PackageDescription.swiftmodule/arm64-apple-macos.private.swiftinterface" 2>/dev/null \
    && /usr/bin/grep -q 'public enum SwiftLanguageMode' "$manifest_dir/PackageDescription.swiftmodule/arm64-apple-macos.swiftinterface"; then
    mkdir -p "$compat_dir/ManifestAPI"
    cp -R "$manifest_dir/." "$compat_dir/ManifestAPI/"
    for interface in "$compat_dir"/ManifestAPI/*.swiftmodule/*.swiftinterface; do
        [[ "$interface" == *.private.swiftinterface ]] && continue
        private_interface="${interface%.swiftinterface}.private.swiftinterface"
        if [[ -f "$private_interface" ]]; then cp "$interface" "$private_interface"; fi
    done
    export SWIFTPM_CUSTOM_LIBS_DIR="$compat_dir"
fi

if [[ ${#extra_flags[@]} -gt 0 ]]; then
    exec swift "$@" "${extra_flags[@]}"
else
    exec swift "$@"
fi
