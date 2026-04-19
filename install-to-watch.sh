#!/bin/bash
# Builds + installs Guardian to your paired iPhone and Apple Watch.
#
# Auto-detects connected devices via `xcrun devicectl list devices`. If you
# have multiple iPhones or Watches plugged in, set these env vars to pick:
#
#   PHONE_DEVICE_ID=<udid> WATCH_DEVICE_ID=<udid> ./install-to-watch.sh
#
# Both apps must build successfully first. If signing fails, open the project
# in Xcode once, pick your team under Signing & Capabilities for each target,
# then run this script.
set -e

PROJECT="ElderlyPrincetonHacks.xcodeproj"
WATCH_SCHEME="GuardianWatch Watch App"
PHONE_SCHEME="ElderlyPrincetonHacks"

# --- Discover devices if not already provided -------------------------------

extract_udid() {
  awk '{
    for (i=1; i<=NF; i++) {
      if ($i ~ /^[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}$/) {
        print $i; exit
      }
    }
  }'
}

if [ -z "$PHONE_DEVICE_ID" ] || [ -z "$WATCH_DEVICE_ID" ]; then
  echo "==> Looking for paired iPhone + Apple Watch..."
  DEVICE_LIST=$(xcrun devicectl list devices 2>/dev/null || true)

  if [ -z "$PHONE_DEVICE_ID" ]; then
    PHONE_DEVICE_ID=$(echo "$DEVICE_LIST" | grep -iE "iPhone|iPad" | grep -v "Apple Watch" | extract_udid)
  fi
  if [ -z "$WATCH_DEVICE_ID" ]; then
    WATCH_DEVICE_ID=$(echo "$DEVICE_LIST" | grep "Apple Watch" | extract_udid)
  fi
fi

if [ -z "$PHONE_DEVICE_ID" ]; then
  echo "ERROR: No connected iPhone found. Plug it in, unlock it, trust this Mac."
  exit 1
fi
if [ -z "$WATCH_DEVICE_ID" ]; then
  echo "ERROR: No paired Apple Watch found. Make sure it's paired with the iPhone."
  exit 1
fi

echo "    iPhone:      $PHONE_DEVICE_ID"
echo "    Apple Watch: $WATCH_DEVICE_ID"

# --- Locate DerivedData (Xcode hashes the path differently per Mac) ---------

DERIVED=$(xcodebuild -project "$PROJECT" -showBuildSettings -scheme "$PHONE_SCHEME" 2>/dev/null \
  | awk -F' = ' '/^[[:space:]]*BUILD_DIR =/ {print $2; exit}' \
  | sed 's|/Build/Products$||')

if [ -z "$DERIVED" ]; then
  echo "ERROR: Could not resolve DerivedData path. Open the project in Xcode once."
  exit 1
fi

WATCH_APP="$DERIVED/Build/Products/Debug-watchos/GuardianWatch Watch App.app"
PHONE_APP="$DERIVED/Build/Products/Debug-iphoneos/ElderlyPrincetonHacks.app"

# --- Build ------------------------------------------------------------------

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

[ -d "$WATCH_APP" ] || { echo "ERROR: missing build product: $WATCH_APP"; exit 1; }
[ -d "$PHONE_APP" ] || { echo "ERROR: missing build product: $PHONE_APP"; exit 1; }

# --- Install ----------------------------------------------------------------

echo "==> Installing on iPhone..."
xcrun devicectl device install app --device "$PHONE_DEVICE_ID" "$PHONE_APP"

echo "==> Installing on Apple Watch..."
xcrun devicectl device install app --device "$WATCH_DEVICE_ID" "$WATCH_APP"

echo "==> Done. Launch Guardian from your iPhone home screen and the watch app grid."
