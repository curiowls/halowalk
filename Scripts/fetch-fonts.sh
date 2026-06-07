#!/usr/bin/env bash
# Download the Google Fonts the Sketch theme depends on into Resources/Fonts.
# Run once after cloning. The fonts are already declared in project.yml's
# UIAppFonts so Xcode will register them automatically once the .ttf files
# are present.
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p Resources/Fonts
cd Resources/Fonts

base="https://github.com/google/fonts/raw/main/ofl"

# {github-path-under-ofl}|{output-filename}
declare -a files=(
  "kalam/Kalam-Light.ttf|Kalam-Light.ttf"
  "kalam/Kalam-Regular.ttf|Kalam-Regular.ttf"
  "kalam/Kalam-Bold.ttf|Kalam-Bold.ttf"
  "caveat/Caveat%5Bwght%5D.ttf|Caveat-Regular.ttf"
  "architectsdaughter/ArchitectsDaughter-Regular.ttf|ArchitectsDaughter-Regular.ttf"
)

for entry in "${files[@]}"; do
  src="${entry%|*}"
  out="${entry#*|}"
  if [ -f "$out" ]; then
    echo "✓ $out (already present)"
  else
    echo "↓ $out"
    curl -fsSL "$base/$src" -o "$out"
  fi
done

# Caveat ships as a variable font — alias it as Caveat-Bold so the project's
# UIAppFonts entry resolves. SwiftUI will pick up weights from the variable axis.
if [ -f "Caveat-Regular.ttf" ] && [ ! -f "Caveat-Bold.ttf" ]; then
  cp Caveat-Regular.ttf Caveat-Bold.ttf
  echo "✓ Caveat-Bold.ttf (aliased to variable font)"
fi

echo ""
echo "Done. Re-run xcodegen if you haven't already."
