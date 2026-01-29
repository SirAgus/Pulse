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
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
EOF

# 3. Create DMG
echo "📀 Creating DMG..."
rm -f "$DMG_NAME"

# Create a temporary directory for the DMG content
DMG_TEMP="dmg_content"
rm -rf "$DMG_TEMP"
mkdir -p "$DMG_TEMP/.background"
cp -R "$APP_BUNDLE" "$DMG_TEMP/"

# Place the black pixel as background
cp Resources/black.png "$DMG_TEMP/.background/background.png"

# Create read-write DMG
hdiutil create -volname "$VOL_NAME" -srcfolder "$DMG_TEMP" -ov -format UDRW -fs HFS+ "temp_$DMG_NAME"

# Mount and customize
MOUNT_POINT="/Volumes/$VOL_NAME"
hdiutil attach "temp_$DMG_NAME" -mountpoint "$MOUNT_POINT" -noautoopen

# Customize with AppleScript (Minimal)
sleep 2
osascript <<EOF
tell application "Finder"
    set volName to "$VOL_NAME"
    set diskObj to disk volName
    open diskObj
    
    tell container window of diskObj
        set current view to icon view
        set toolbar visible to false
        set statusbar visible to false
        set bounds to {400, 200, 1000, 600}
        
        -- Create Applications alias
        if not (exists item "Applications" of diskObj) then
            make new alias file at diskObj to (POSIX file "/Applications") with properties {name:"Applications"}
        end if
        
        -- Set background picture
        try
            set background picture of icon view options to file ".background:background.png" of diskObj
        end try
        
        -- Positioning
        set position of item "$APP_DISPLAY_NAME.app" of diskObj to {180, 200}
        set position of item "Applications" of diskObj to {420, 200}
        
        update diskObj
    end tell
    
    delay 2
    close container window of diskObj
end tell
EOF

# Eject and convert
sync
sleep 2
echo "Ejecting disk..."
hdiutil detach "$MOUNT_POINT" -force 2>/dev/null
sleep 2

# Final conversion
if hdiutil convert "temp_$DMG_NAME" -format UDZO -o "$DMG_NAME" 2>/dev/null; then
    rm -f "temp_$DMG_NAME"
else
    mv "temp_$DMG_NAME" "$DMG_NAME"
fi

# Clean up
rm -rf "$DMG_TEMP"
rm -rf Resources/AppIcon.iconset

echo "✅ DMG created: $DMG_NAME"
echo "🚀 You can now share $DMG_NAME"
