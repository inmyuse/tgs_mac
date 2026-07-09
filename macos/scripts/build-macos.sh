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

ICONSET="$ROOT/TGSPlayer/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$ICONSET"
cat > "$ICONSET/Contents.json" <<'JSON'
{
  "images": [
    { "idiom": "mac", "size": "16x16", "scale": "1x", "filename": "icon_16x16.png" },
    { "idiom": "mac", "size": "16x16", "scale": "2x", "filename": "icon_16x16@2x.png" },
    { "idiom": "mac", "size": "32x32", "scale": "1x", "filename": "icon_32x32.png" },
    { "idiom": "mac", "size": "32x32", "scale": "2x", "filename": "icon_32x32@2x.png" },
    { "idiom": "mac", "size": "128x128", "scale": "1x", "filename": "icon_128x128.png" },
    { "idiom": "mac", "size": "128x128", "scale": "2x", "filename": "icon_128x128@2x.png" },
    { "idiom": "mac", "size": "256x256", "scale": "1x", "filename": "icon_256x256.png" },
    { "idiom": "mac", "size": "256x256", "scale": "2x", "filename": "icon_256x256@2x.png" },
    { "idiom": "mac", "size": "512x512", "scale": "1x", "filename": "icon_512x512.png" },
    { "idiom": "mac", "size": "512x512", "scale": "2x", "filename": "icon_512x512@2x.png" }
  ],
  "info": { "author": "xcode", "version": 1 }
}
JSON

sips -z 16 16 "$ROOT/TGSPlayer/Resources/logo.png" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 "$ROOT/TGSPlayer/Resources/logo.png" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ROOT/TGSPlayer/Resources/logo.png" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64 "$ROOT/TGSPlayer/Resources/logo.png" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ROOT/TGSPlayer/Resources/logo.png" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$ROOT/TGSPlayer/Resources/logo.png" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ROOT/TGSPlayer/Resources/logo.png" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$ROOT/TGSPlayer/Resources/logo.png" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ROOT/TGSPlayer/Resources/logo.png" --out "$ICONSET/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$ROOT/TGSPlayer/Resources/logo.png" --out "$ICONSET/icon_512x512@2x.png" >/dev/null

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

DMG_ROOT="$BUILD/dmg-root"
rm -rf "$DMG_ROOT"
mkdir -p "$DMG_ROOT"
cp -R "$DIST/TGSPlayer.app" "$DMG_ROOT/TGSPlayer.app"
ln -s /Applications "$DMG_ROOT/Applications"

hdiutil create \
  -volname "TGSPlayer" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$DIST/TGSPlayer.dmg"

echo "Built $DIST/TGSPlayer.dmg"
echo "After install, refresh Quick Look cache if needed:"
echo "  qlmanage -r cache && qlmanage -r"
