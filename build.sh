#!/bin/bash

# Configuration
EXECUTABLE_NAME="DynamicIsland"
APP_DISPLAY_NAME="PULSE"
BUILD_DIR=".build/debug"
APP_BUNDLE="$APP_DISPLAY_NAME.app"
DMG_NAME="$APP_DISPLAY_NAME.dmg"
VOL_NAME="$APP_DISPLAY_NAME Installer"

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
    <string>1.0</string>
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
