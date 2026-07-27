#!/bin/bash

set -euo pipefail

# Configuration
VERSION="${1:-0.03.0}"
EXECUTABLE_NAME="DynamicIsland"
APP_DISPLAY_NAME="PULSE"
APP_BUNDLE="$APP_DISPLAY_NAME.app"
DMG_NAME="$APP_DISPLAY_NAME.dmg"
VOL_NAME="$APP_DISPLAY_NAME Installer"

# 1. Build the project
echo "🔨 Building PULSE $VERSION for release..."
swift build -c release
BUILD_DIR="$(swift build -c release --show-bin-path)"

# 2. Create App Bundle
echo "📦 Creating App Bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$EXECUTABLE_NAME" "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"

# Copy Resources (icons, images, etc.)
if [ -d "Resources" ]; then
    cp -R Resources/* "$APP_BUNDLE/Contents/Resources/"
    echo "📁 Resources copied"
fi

cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.agus.pulse</string>
    <key>CFBundleName</key>
    <string>$APP_DISPLAY_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_DISPLAY_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSCalendarUsageDescription</key>
    <string>PULSE necesita acceso al calendario para mostrar tu próximo evento.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>PULSE necesita ejecutar scripts para controlar el volumen y la música.</string>
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>PULSE necesita acceso a Bluetooth para listar tus dispositivos.</string>
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>PULSE necesita acceso a ubicación para mostrar el nombre de tu red WiFi.</string>
    <key>NSLocationUsageDescription</key>
    <string>PULSE necesita acceso a ubicación para mostrar el nombre de tu red WiFi.</string>
    <key>NSCameraUsageDescription</key>
    <string>PULSE necesita acceso a la cámara para mostrar la vista previa en la isla.</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>PULSE necesita acceso al micrófono para detectar niveles de audio (si es necesario).</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
EOF

# Apply an ad-hoc signature so the bundle has a consistent code signature.
# A Developer ID certificate is still required to notarize public releases.
codesign --force --deep --sign - \
    --entitlements "Contents/DynamicIsland.entitlements" \
    "$APP_BUNDLE"

# 3. Create DMG
echo "📀 Creating DMG..."
rm -f "$DMG_NAME"

# Create a temporary directory for the DMG content
DMG_TEMP="dmg_content"
rm -rf "$DMG_TEMP"
mkdir -p "$DMG_TEMP/.background"
cp -R "$APP_BUNDLE" "$DMG_TEMP/"
ln -s /Applications "$DMG_TEMP/Applications"

# Place the black pixel as background
cp Resources/black.png "$DMG_TEMP/.background/background.png"

# Create the compressed DMG directly. This avoids Finder automation, which can
# time out in CI or when Finder is not accepting Apple Events.
hdiutil create \
    -volname "$VOL_NAME" \
    -srcfolder "$DMG_TEMP" \
    -ov \
    -format UDZO \
    "$DMG_NAME"

# Clean up
rm -rf "$DMG_TEMP"
rm -f "temp_$DMG_NAME"
echo "✅ DMG created: $DMG_NAME ($(shasum -a 256 "$DMG_NAME" | awk '{print $1}'))"
echo "🚀 You can now share $DMG_NAME"
