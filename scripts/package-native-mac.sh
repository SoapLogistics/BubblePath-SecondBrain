#!/bin/zsh
set -euo pipefail

ROOT="/Users/millerm/Documents/Codex/2026-04-20-do-you-have-acess-to-any"
PACKAGE_DIR="$ROOT/NativeMac/BubblePathMac"
DIST_DIR="$ROOT/dist"
APP_DIR="$DIST_DIR/BubblePath.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
EXECUTABLE_NAME="BubblePathMac"
ICON_FILE="$ROOT/Assets/BubblePath.icns"

echo "Building BubblePath Mac app..."
cd "$PACKAGE_DIR"
swift build --product "$EXECUTABLE_NAME"

echo "Generating BubblePath icon..."
cd "$ROOT"
swift "$ROOT/scripts/generate-app-icon.swift"

echo "Packaging BubblePath.app..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$PACKAGE_DIR/.build/debug/$EXECUTABLE_NAME" "$MACOS_DIR/BubblePath"
chmod +x "$MACOS_DIR/BubblePath"
cp "$ICON_FILE" "$RESOURCES_DIR/BubblePath.icns"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>BubblePath</string>
  <key>CFBundleIdentifier</key>
  <string>local.bubblepath.mac</string>
  <key>CFBundleName</key>
  <string>BubblePath</string>
  <key>CFBundleDisplayName</key>
  <string>BubblePath</string>
  <key>CFBundleIconFile</key>
  <string>BubblePath</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

echo "Ready: $APP_DIR"
echo "Open it with: open \"$APP_DIR\""
