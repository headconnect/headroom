#!/bin/sh
# Builds a release binary and wraps it in "build/Range Anxiety.app".
# SIGN_IDENTITY selects the codesign identity; default "-" is ad-hoc.
# VERSION overrides CFBundleShortVersionString/CFBundleVersion from Resources/Info.plist.
set -eu
cd "$(dirname "$0")/.."

swift build -c release --product range-anxiety
APP="build/Range Anxiety.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/range-anxiety "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
cp Resources/range-anxiety.icns "$APP/Contents/Resources/"
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
