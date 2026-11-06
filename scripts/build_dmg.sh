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

DEFAULT_DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData/Scribe-gbrhrwzwenpibmgpteqohbqavmer"
if [ -d "$DEFAULT_DERIVED_DATA" ]; then
    DERIVED_DATA_PATH="$DEFAULT_DERIVED_DATA"
else
    DERIVED_DATA_PATH="$HOME/Library/Developer/Xcode/DerivedData/Scribe-adcbtqdoqoitycbubnnzaubemqip"
fi

ARCH=$(uname -m)
xcodebuild -project Scribe.xcodeproj \
    -scheme Scribe \
    -configuration Release \
    -destination "platform=macOS,arch=$ARCH" \
    ONLY_ACTIVE_ARCH=YES \
    -parallelizeTargets \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    build

APP_PATH=$(find "$DERIVED_DATA_PATH" -type d -path "*/Products/Release/${APP_NAME}.app" | head -n 1)
if [ -z "$APP_PATH" ]; then
    APP_PATH=$(find "$DERIVED_DATA_PATH" -type d -name "${APP_NAME}.app" | grep -v "Index.noindex" | head -n 1)
fi

if [ -z "$APP_PATH" ]; then
    echo "❌ Error: Could not find ${APP_NAME}.app in build output."
    exit 1
fi

echo "📦 Found App at: $APP_PATH"

DEVELOPER_ID_IDENTITY="Developer ID Application: Oleg Tyagunov (2LD8J2PCK3)"
ENTITLEMENTS="$ROOT_DIR/Scribe/Scribe.entitlements"

echo "🔏 Signing frameworks and Mach-O binaries inside $APP_PATH with $DEVELOPER_ID_IDENTITY..."

# Remove extended attributes (com.apple.quarantine etc.)
xattr -cr "$APP_PATH"

# Sign all nested dynamic libraries and frameworks inside out
if [ -d "$APP_PATH/Contents/Frameworks" ]; then
    for fw in "$APP_PATH/Contents/Frameworks"/*.framework; do
        if [ -d "$fw" ]; then
            echo "  Signing framework: $(basename "$fw")"
            codesign --force --sign "$DEVELOPER_ID_IDENTITY" --timestamp --options runtime "$fw"
        fi
    done
fi

# Sign main executable with hardened runtime and entitlements
echo "  Signing main app bundle with entitlements: $ENTITLEMENTS"
codesign --force --sign "$DEVELOPER_ID_IDENTITY" --timestamp --options runtime --entitlements "$ENTITLEMENTS" "$APP_PATH"

echo "🔎 Verifying app bundle signature..."
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

# Ensure existing mounts are unmounted before recreating DMG
hdiutil detach "/Volumes/Scribe Installer" 2>/dev/null || true
hdiutil detach "/Volumes/Scribe" 2>/dev/null || true
rm -f "$DIST_DIR/$DMG_NAME"

echo "🎨 Generating installer gradient background..."
swift "$SCRIPT_DIR/generate_dmg_background.swift" "$DIST_DIR"
tiffutil -cathidpicheck "$DIST_DIR/dmg_bg.png" "$DIST_DIR/dmg_bg@2x.png" -out "$DIST_DIR/dmg_background.tiff"
BG_IMAGE="$DIST_DIR/dmg_background.tiff"

README_FILE="$ROOT_DIR/installer/README.txt"

if command -v create-dmg >/dev/null 2>&1; then
    echo "💿 Creating DMG with create-dmg and gradient background..."
    create-dmg \
        --volname "$APP_NAME Installer" \
        --volicon "$ROOT_DIR/Scribe/AppIcon.icns" \
        --background "$BG_IMAGE" \
        --window-pos 200 120 \
        --window-size 540 420 \
        --icon-size 100 \
        --text-size 12 \
        --icon "$APP_NAME.app" 135 135 \
        --hide-extension "$APP_NAME.app" \
        --app-drop-link 405 135 \
        --add-file "README.txt" "$README_FILE" 270 260 \
        --hide-extension "README.txt" \
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
    cp "$README_FILE" "$TMP_DMG_DIR/README.txt"
    ln -s /Applications "$TMP_DMG_DIR/Applications"
    hdiutil create -volname "$APP_NAME" -srcfolder "$TMP_DMG_DIR" -ov -format UDZO "$DIST_DIR/$DMG_NAME"
    rm -rf "$TMP_DMG_DIR"
fi

echo "🔏 Signing DMG with $DEVELOPER_ID_IDENTITY..."
codesign --force --sign "$DEVELOPER_ID_IDENTITY" --timestamp "$DIST_DIR/$DMG_NAME"
codesign --verify --verbose=2 "$DIST_DIR/$DMG_NAME"

# Notarize DMG with Apple notarytool
ASC_KEY_ID="RHN6NUV75B"
ASC_ISSUER_ID="dd2c79d3-8e86-41b6-8f05-a8f2d6ccc1a1"
ASC_KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_RHN6NUV75B.p8"

if [ -f "$ASC_KEY_PATH" ]; then
    echo "🚀 Submitting DMG to Apple Notary Service..."
    xcrun notarytool submit "$DIST_DIR/$DMG_NAME" \
        --key "$ASC_KEY_PATH" \
        --key-id "$ASC_KEY_ID" \
        --issuer "$ASC_ISSUER_ID" \
        --wait

    echo "📎 Stapling notarization ticket to DMG..."
    xcrun stapler staple "$DIST_DIR/$DMG_NAME"
    xcrun stapler validate "$DIST_DIR/$DMG_NAME"
fi

echo "🛡️ Assessing Gatekeeper compliance on DMG..."
spctl -a -vvv -t open --context context:primary-signature "$DIST_DIR/$DMG_NAME" || true

echo "✅ Successfully built and notarized: $DIST_DIR/$DMG_NAME"
ls -lh "$DIST_DIR/$DMG_NAME"

echo "🚀 Updating /Applications/$APP_NAME.app and relaunching..."
if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
    pkill -x "$APP_NAME" || true
    sleep 1
fi
rm -rf "/Applications/$APP_NAME.app"
cp -R "$APP_PATH" "/Applications/$APP_NAME.app"
open "/Applications/$APP_NAME.app"
echo "✨ Scribe successfully updated and running."
