#!/bin/sh
# Builds a release binary and wraps it in "build/Rations.app".
# SIGN_IDENTITY selects the codesign identity; default "-" is ad-hoc.
# VERSION sets CFBundleShortVersionString/CFBundleVersion; it defaults to `git describe`
# (the tag, e.g. 2.1.0, or 2.1.0-3-gabc1234 past it) and, outside a git checkout, to
# what Resources/Info.plist says.
set -eu
cd "$(dirname "$0")/.."

swift build -c release --product rations
APP="build/Rations.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/rations "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
cp Resources/rations.icns "$APP/Contents/Resources/"
VERSION="${VERSION:-$(git describe --tags --always 2>/dev/null | sed 's/^v//')}"
if [ -n "$VERSION" ]; then
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
