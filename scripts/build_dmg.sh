#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="Scribe"
DMG_NAME="${APP_NAME}.dmg"

echo "🔨 Building Scribe (Release)..."
cd "$ROOT_DIR"

mkdir -p "$BUILD_DIR"
mkdir -p "$DIST_DIR"

ARCH=$(uname -m)
xcodebuild -project Scribe.xcodeproj \
    -scheme Scribe \
    -configuration Release \
    -destination "platform=macOS,arch=$ARCH" \
    ONLY_ACTIVE_ARCH=YES \
    -parallelizeTargets \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    build

APP_PATH=$(find "$BUILD_DIR/DerivedData" -type d -name "${APP_NAME}.app" | grep -v "Index.noindex" | head -n 1)

if [ -z "$APP_PATH" ]; then
    echo "❌ Error: Could not find ${APP_NAME}.app in build output."
    exit 1
fi

echo "📦 Found App at: $APP_PATH"

CODE_SIGN_IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | grep "Apple Development" | head -n 1 | awk -F'"' '{print $2}')
if [ -n "$CODE_SIGN_IDENTITY" ]; then
    echo "🔏 Signing app with identity: $CODE_SIGN_IDENTITY"
    codesign --force --deep --sign "$CODE_SIGN_IDENTITY" "$APP_PATH"
else
    echo "🔏 Signing app ad-hoc with stable bundle identifier..."
    codesign --force --deep --identifier "com.aleksei.scribe" --sign - "$APP_PATH"
fi

rm -f "$DIST_DIR/$DMG_NAME"

echo "🎨 Generating installer gradient background..."
swift "$SCRIPT_DIR/generate_dmg_background.swift" "$DIST_DIR"
tiffutil -cathidpicheck "$DIST_DIR/dmg_bg.png" "$DIST_DIR/dmg_bg@2x.png" -out "$DIST_DIR/dmg_background.tiff"
BG_IMAGE="$DIST_DIR/dmg_background.tiff"

if command -v create-dmg >/dev/null 2>&1; then
    echo "💿 Creating DMG with create-dmg and gradient background..."
    create-dmg \
        --volname "$APP_NAME Installer" \
        --volicon "$ROOT_DIR/Scribe/AppIcon.icns" \
        --background "$BG_IMAGE" \
        --window-pos 200 120 \
        --window-size 540 360 \
        --icon-size 128 \
        --text-size 13 \
        --icon "$APP_NAME.app" 140 170 \
        --hide-extension "$APP_NAME.app" \
        --app-drop-link 400 170 \
        --no-internet-enable \
        --applescript-sleep-duration 6 \
        --overwrite \
        "$DIST_DIR/$DMG_NAME" \
        "$APP_PATH" || true
fi

# Fallback if create-dmg didn't produce the DMG
if [ ! -f "$DIST_DIR/$DMG_NAME" ]; then
    echo "💿 Creating DMG with hdiutil fallback..."
    TMP_DMG_DIR=$(mktemp -d /tmp/scribe-dmg.XXXXXX)
    cp -R "$APP_PATH" "$TMP_DMG_DIR/"
    ln -s /Applications "$TMP_DMG_DIR/Applications"
    hdiutil create -volname "$APP_NAME" -srcfolder "$TMP_DMG_DIR" -ov -format UDZO "$DIST_DIR/$DMG_NAME"
    rm -rf "$TMP_DMG_DIR"
fi

echo "✅ Successfully built: $DIST_DIR/$DMG_NAME"
ls -lh "$DIST_DIR/$DMG_NAME"
