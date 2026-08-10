#!/bin/bash
echo "Building Scribe..."
xcodebuild -project Scribe.xcodeproj -scheme Scribe build | xcpretty || xcodebuild -project Scribe.xcodeproj -scheme Scribe build || exit 1

APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -type d -path "*/Build/Products/Debug/Scribe.app" | grep -v "Index.noindex" | head -n 1)

if [ -n "$APP_PATH" ]; then
    echo "Killing existing instances..."
    killall Scribe 2>/dev/null
    echo "Launching $APP_PATH with settings and permissions..."
    open -n "$APP_PATH" --args --settings --permissions
    echo "Launched successfully!"
else
    echo "Could not find Scribe.app in DerivedData."
fi
