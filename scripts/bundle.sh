#!/bin/sh
# Builds a release binary and wraps it in build/UsageWidget.app.
# SIGN_IDENTITY selects the codesign identity; default "-" is ad-hoc.
# VERSION overrides CFBundleShortVersionString/CFBundleVersion from Resources/Info.plist.
set -eu
cd "$(dirname "$0")/.."

swift build -c release --product UsageWidget
APP=build/UsageWidget.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/UsageWidget "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
if [ -n "${VERSION:-}" ]; then
    /usr/libexec/PlistBuddy -c "Set CFBundleShortVersionString $VERSION" -c "Set CFBundleVersion $VERSION" "$APP/Contents/Info.plist"
fi

IDENTITY="${SIGN_IDENTITY:--}"
if [ "$IDENTITY" = "-" ]; then
    codesign --force --sign - "$APP"
else
    # Hardened runtime and a timestamp are required for notarization.
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
fi
echo "Built $APP (signed: $IDENTITY)"
