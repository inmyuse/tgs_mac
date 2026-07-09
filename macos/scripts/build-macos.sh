#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$ROOT/dist"
BUILD="$ROOT/build"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen is required. Install it on macOS with: brew install xcodegen" >&2
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild is required. Install Xcode and run: xcode-select --install" >&2
  exit 1
fi

cd "$ROOT"
rm -rf "$DIST" "$BUILD" "TGSPlayer.xcodeproj"
mkdir -p "$DIST" "$BUILD"

xcodegen generate --spec project.yml

xcodebuild \
  -project TGSPlayer.xcodeproj \
  -scheme TGSPlayer \
  -configuration Release \
  -derivedDataPath "$BUILD/DerivedData" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=YES \
  build

APP="$BUILD/DerivedData/Build/Products/Release/TGSPlayer.app"
cp -R "$APP" "$DIST/TGSPlayer.app"

codesign --force --deep --sign - "$DIST/TGSPlayer.app"

hdiutil create \
  -volname "TGSPlayer" \
  -srcfolder "$DIST/TGSPlayer.app" \
  -ov \
  -format UDZO \
  "$DIST/TGSPlayer.dmg"

echo "Built $DIST/TGSPlayer.dmg"
echo "After install, refresh Quick Look cache if needed:"
echo "  qlmanage -r cache && qlmanage -r"

