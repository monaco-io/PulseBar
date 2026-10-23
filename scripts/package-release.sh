#!/bin/bash
set -euo pipefail
echo 'PulseBar is distributed through the Mac App Store. GitHub releases are reserved for PulseBar Helper.' >&2
echo 'Use scripts/build-store-distribution.sh for the app and scripts/package-helper-release.sh for the helper.' >&2
exit 1
