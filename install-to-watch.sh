#!/bin/bash
# Builds + installs Guardian to BOTH the iPhone and Apple Watch.
set -e

PROJECT="ElderlyPrincetonHacks.xcodeproj"
WATCH_SCHEME="GuardianWatch Watch App"
PHONE_SCHEME="ElderlyPrincetonHacks"
WATCH_DEVICE_ID="00008310-000313222698A01E"
PHONE_DEVICE_ID="EF4631FA-820B-588A-BF49-110285251BC0"
DERIVED="$HOME/Library/Developer/Xcode/DerivedData/ElderlyPrincetonHacks-ebcienvpbkwwhmahbqnkdapdhutl"
WATCH_APP="$DERIVED/Build/Products/Debug-watchos/GuardianWatch Watch App.app"
PHONE_APP="$DERIVED/Build/Products/Debug-iphoneos/ElderlyPrincetonHacks.app"

filter='(error:|BUILD SUCCEEDED|BUILD FAILED)'

echo "==> Building watch app..."
xcodebuild -project "$PROJECT" -scheme "$WATCH_SCHEME" \
  -destination "platform=watchOS,id=$WATCH_DEVICE_ID" \
  -configuration Debug -allowProvisioningUpdates build 2>&1 \
  | grep -E "$filter" | grep -v deprecated

echo "==> Building iOS app..."
xcodebuild -project "$PROJECT" -scheme "$PHONE_SCHEME" \
  -destination "platform=iOS,id=$PHONE_DEVICE_ID" \
  -configuration Debug -allowProvisioningUpdates build 2>&1 \
  | grep -E "$filter" | grep -v deprecated

[ -d "$WATCH_APP" ] || { echo "ERROR: missing $WATCH_APP"; exit 1; }
[ -d "$PHONE_APP" ] || { echo "ERROR: missing $PHONE_APP"; exit 1; }

echo "==> Installing on iPhone..."
xcrun devicectl device install app --device "$PHONE_DEVICE_ID" "$PHONE_APP"

echo "==> Installing on Apple Watch..."
xcrun devicectl device install app --device "$WATCH_DEVICE_ID" "$WATCH_APP"

echo "==> Done. Launch Guardian from your iPhone home screen and the watch app grid."
