#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"

target_arch="${CODEXPEEK_ARCH:-universal}"
case "$target_arch" in
    universal) architectures=(arm64 x86_64) ;;
    arm64|x86_64) architectures=("$target_arch") ;;
    *) echo "CODEXPEEK_ARCH must be universal, arm64 or x86_64" >&2; exit 1 ;;
esac
binaries=()
for architecture in "${architectures[@]}"; do
    swift build -c release --product CodexPeek --arch "$architecture"
    binary_dir="$(swift build -c release --product CodexPeek --arch "$architecture" --show-bin-path)"
    binaries+=("$binary_dir/CodexPeek")
done
app_dir="$project_root/dist/CodexPeek.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
swift scripts/generate-icon.swift .build/app-icon
iconutil -c icns .build/app-icon/AppIcon.iconset -o .build/app-icon/AppIcon.icns
cp .build/app-icon/AppIcon.icns "$app_dir/Contents/Resources/AppIcon.icns"
cp .build/app-icon/AppIcon.png "$project_root/dist/CodexPeek-icon.png"
if [[ "${#binaries[@]}" -eq 2 ]]; then
    lipo -create "${binaries[@]}" -output "$app_dir/Contents/MacOS/CodexPeek"
else
    cp "${binaries[0]}" "$app_dir/Contents/MacOS/CodexPeek"
fi
cp packaging/Info.plist "$app_dir/Contents/Info.plist"
plutil -lint "$app_dir/Contents/Info.plist"
codesign --force --sign - "$app_dir"
codesign --verify --strict "$app_dir"
ditto -c -k --keepParent "$app_dir" "$project_root/dist/CodexPeek.zip"
echo "Built: $app_dir"
