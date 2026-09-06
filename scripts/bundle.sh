#!/bin/sh
# Builds a release binary and wraps it in build/UsageWidget.app.
# SIGN_IDENTITY selects the codesign identity; default "-" is ad-hoc.
set -eu
cd "$(dirname "$0")/.."

swift build -c release --product UsageWidget
APP=build/UsageWidget.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/UsageWidget "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"

IDENTITY="${SIGN_IDENTITY:--}"
if [ "$IDENTITY" = "-" ]; then
    codesign --force --sign - "$APP"
else
    # Hardened runtime and a timestamp are required for notarization.
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
fi
echo "Built $APP (signed: $IDENTITY)"
