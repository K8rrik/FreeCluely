#!/bin/bash

APP_NAME="FreeCluely"
SOURCE_DIR="FreeCluely"
BUILD_DIR="$SOURCE_DIR/.build/release"
OUTPUT_DIR="Build"

# Ensure clean slate
echo "Cleaning previous build..."
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Build
echo "Building $APP_NAME..."
cd "$SOURCE_DIR"
swift build -c release
if [ $? -ne 0 ]; then
    echo "Build failed."
    exit 1
fi
cd ..

# Create App Bundle Structure
APP_BUNDLE="$OUTPUT_DIR/$APP_NAME.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy Binary
echo "Packaging app..."
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

# Create Info.plist
cat <<EOF > "$APP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.kerrik.$APP_NAME</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Handle .env
if [ -f "$SOURCE_DIR/.env" ]; then
    echo "Found .env file. Copying to App Bundle Resources..."
    cp "$SOURCE_DIR/.env" "$APP_BUNDLE/Contents/Resources/"
    echo "WARNING: Your .env file is now packaged inside the app. Do not share this app bundle publicly if it contains secrets."
else
    echo "No .env file found in $SOURCE_DIR. The app might not work correctly without it."
fi

echo "------------------------------------------------"
echo "Build Successful!"
echo "App located at: $APP_BUNDLE"
echo "To run: open $APP_BUNDLE"
echo "------------------------------------------------"
