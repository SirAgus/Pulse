#!/bin/bash

# Configuration
APP_NAME="DynamicIsland"
BUILD_DIR=".build/debug"
APP_BUNDLE="$APP_NAME.app"
DMG_NAME="$APP_NAME.dmg"
VOL_NAME="$APP_NAME Installer"

# 1. Build the project
echo "🔨 Building project..."
swift build -c debug

if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi

# 2. Create App Bundle
echo "📦 Creating App Bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.agus.DynamicIsland</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSCalendarUsageDescription</key>
    <string>Necesitamos acceso al calendario para mostrar tu próximo evento.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Necesitamos ejecutar scripts para controlar el volumen y la música.</string>
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>Necesitamos acceso a Bluetooth para listar tus dispositivos.</string>
</dict>
</plist>
EOF

# 3. Create DMG
echo "📀 Creating DMG..."
rm -f "$DMG_NAME"

# Create a temporary directory for the DMG content
mkdir -p "dmg_content"
cp -R "$APP_BUNDLE" "dmg_content/"
ln -s /Applications "dmg_content/Applications"

hdiutil create -volname "$VOL_NAME" -srcfolder "dmg_content" -ov -format UDZO "$DMG_NAME"

# Clean up
rm -rf "dmg_content"

echo "✅ DMG created: $DMG_NAME"
echo "🚀 You can now share $DMG_NAME"
