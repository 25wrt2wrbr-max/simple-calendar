#!/bin/bash
# Builds "Simple Calendar.app" using only the Command Line Tools (no Xcode needed).
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Simple Calendar"
EXEC="SimpleCalendar"
APP="$PWD/dist/$APP_NAME.app"
SDK="$(xcrun --show-sdk-path)"
MIN_MACOS="14.0"
ARCH="${ARCH:-$(uname -m)}"

mkdir -p build dist

echo "==> Compiling ($ARCH)"
swiftc \
  -O -whole-module-optimization \
  -swift-version 5 \
  -parse-as-library \
  -sdk "$SDK" \
  -target "$ARCH-apple-macosx$MIN_MACOS" \
  -o "build/$EXEC" \
  Sources/SimpleCalendar/*.swift

echo "==> Building icon"
if [ ! -f "build/AppIcon.icns" ]; then
  rm -rf build/AppIcon.iconset
  mkdir -p build/AppIcon.iconset
  swift scripts/make-icon.swift build/AppIcon-1024.png
  for spec in "16 16x16" "32 16x16@2x" "32 32x32" "64 32x32@2x" "128 128x128" \
              "256 128x128@2x" "256 256x256" "512 256x256@2x" "512 512x512" "1024 512x512@2x"; do
    set -- $spec
    sips -z "$1" "$1" build/AppIcon-1024.png --out "build/AppIcon.iconset/icon_$2.png" >/dev/null
  done
  iconutil -c icns build/AppIcon.iconset -o build/AppIcon.icns
fi

echo "==> Assembling bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "build/$EXEC" "$APP/Contents/MacOS/$EXEC"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "==> Signing (ad-hoc)"
codesign --force --sign - "$APP" >/dev/null 2>&1 || echo "    (ad-hoc signing skipped)"
touch "$APP"

echo "==> Done: $APP"

if [ "${1:-}" = "--run" ] || [ "${1:-}" = "run" ]; then
  open "$APP"
fi
