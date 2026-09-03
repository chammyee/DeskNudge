#!/bin/bash
# Builds DeskNudge.app (release) into ./dist
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="DeskNudge"
BUNDLE_ID="com.desknudge.app"
VERSION="${VERSION:-1.0.0}"
BUILD="${BUILD:-1}"

CONFIG=release
echo "▸ swift build -c $CONFIG"
swift build -c "$CONFIG"

BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"
DIST="dist"
APP="$DIST/$APP_NAME.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Frameworks" "$APP/Contents/Resources"

cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"

# Bundle the Lottie dynamic framework.
if [ -d "$BIN_DIR/Lottie.framework" ]; then
  cp -R "$BIN_DIR/Lottie.framework" "$APP/Contents/Frameworks/"
fi

# SwiftPM resource bundle (menu-bar icons etc.) — Bundle.module looks here.
for b in "$BIN_DIR"/*.bundle; do
  [ -d "$b" ] && cp -R "$b" "$APP/Contents/Resources/"
done

# Make the executable look in Contents/Frameworks.
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/$APP_NAME" 2>/dev/null || true

# App icon (optional): scripts/AppIcon.icns
if [ -f "scripts/AppIcon.icns" ]; then
  cp "scripts/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
  ICON_KEY="<key>CFBundleIconFile</key><string>AppIcon</string>"
else
  ICON_KEY=""
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$BUILD</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSHumanReadableCopyright</key><string>DeskNudge</string>
    $ICON_KEY
</dict>
</plist>
PLIST

# Ad-hoc code signing (needed for SMAppService / login-item registration).
echo "▸ codesign (ad-hoc)"
if [ -d "$APP/Contents/Frameworks/Lottie.framework" ]; then
  codesign --force --sign - --timestamp=none "$APP/Contents/Frameworks/Lottie.framework"
fi
codesign --force --deep --sign - --timestamp=none \
  --options runtime --entitlements /dev/null "$APP" 2>/dev/null \
  || codesign --force --deep --sign - "$APP"

echo "✓ Built $APP"
echo "  Install:  cp -R \"$APP\" /Applications/"
