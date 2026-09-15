#!/bin/bash
set -e

APP_IDENTIFIER="com.aleksei.scribe"

echo "🔄 Resetting macOS TCC permissions for Scribe ($APP_IDENTIFIER)..."

# Close any running instances under current user
if pgrep -x "Scribe" >/dev/null 2>&1; then
    echo "⏹️ Closing running Scribe instance..."
    pkill -x "Scribe" 2>/dev/null || true
    sleep 1
fi

# Reset all TCC services for Scribe
tccutil reset All "$APP_IDENTIFIER" 2>/dev/null || true
tccutil reset Accessibility "$APP_IDENTIFIER" 2>/dev/null || true
tccutil reset Microphone "$APP_IDENTIFIER" 2>/dev/null || true
tccutil reset AppleEvents "$APP_IDENTIFIER" 2>/dev/null || true
tccutil reset SpeechRecognition "$APP_IDENTIFIER" 2>/dev/null || true

echo "✅ TCC permissions cache successfully reset for $APP_IDENTIFIER."
echo "💡 When Scribe relaunches, macOS will prompt for fresh permissions that will be permanently retained."
