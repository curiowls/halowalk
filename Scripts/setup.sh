#!/usr/bin/env bash
# One-shot project setup: fetch fonts, generate the Xcode project.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen not found. Install with:  brew install xcodegen"
  exit 1
fi

./Scripts/fetch-fonts.sh
xcodegen generate

echo ""
echo "Open HaloWalk.xcodeproj in Xcode, set your Apple Developer team on both"
echo "targets, then build & run."
