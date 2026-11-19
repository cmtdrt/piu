#!/usr/bin/env bash
# Usage: ./scripts/build.sh [--install | --release]
#   --release builds a universal (Apple silicon + Intel) app and zips it for a GitHub release.
set -euo pipefail
cd "$(dirname "$0")/.."

# With Command Line Tools only, the default SDK can be newer than the Swift compiler:
# fall back to the newest compatible SDK.
if [[ -z "${SDKROOT:-}" ]] && ! echo 'import Foundation' | swiftc -typecheck - >/dev/null 2>&1; then
  for sdk in $(ls -d "$(dirname "$(xcrun --show-sdk-path)")"/MacOSX[0-9]*.sdk 2>/dev/null | sort -rV); do
    if echo 'import Foundation' | SDKROOT="$sdk" swiftc -typecheck - >/dev/null 2>&1; then
      export SDKROOT="$sdk"
      echo "→ Using SDK: $(basename "$sdk")"
      break
    fi
  done
fi

NAME="PIU"
APP="build/$NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

ARCHS=("$(uname -m)")
[[ "${1:-}" == "--release" ]] && ARCHS=(arm64 x86_64)

# Plain swiftc rather than `swift build`, which breaks on partially updated Command Line Tools.
echo "→ Building (${ARCHS[*]})…"
BINARIES=()
for arch in "${ARCHS[@]}"; do
  swiftc -O -parse-as-library \
    -target "$arch-apple-macos14.0" \
    Sources/PIU/*.swift \
    -o "build/PIU-$arch"
  BINARIES+=("build/PIU-$arch")
done
lipo -create "${BINARIES[@]}" -output "$APP/Contents/MacOS/PIU"
rm -f "${BINARIES[@]}"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/MenuBarIcon.svg "$APP/Contents/Resources/MenuBarIcon.svg"

echo "→ Generating icon…"
ICONSET=build/AppIcon.iconset
rm -rf "$ICONSET"
swift scripts/make-icon.swift assets/piu.svg "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

codesign --force --sign - "$APP" >/dev/null
echo "✓ Built $APP"

if [[ "${1:-}" == "--install" ]]; then
  pkill -x PIU 2>/dev/null || true
  while pgrep -x PIU >/dev/null; do sleep 0.2; done
  rm -rf "/Applications/$NAME.app"
  cp -R "$APP" /Applications/
  open "/Applications/$NAME.app"
  echo "✓ Installed to /Applications and launched"
fi

if [[ "${1:-}" == "--release" ]]; then
  VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
  ZIP="build/piu-$VERSION.zip"
  rm -f "$ZIP"
  ditto -c -k --keepParent "$APP" "$ZIP"
  echo "✓ $ZIP"
fi
