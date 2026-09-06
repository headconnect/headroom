#!/bin/sh
# Builds a signed app, packs it into a DMG, and notarizes it.
#   SIGN_IDENTITY   "Developer ID Application: Name (TEAMID)"; defaults to the one in your keychain, else ad-hoc
#   NOTARY_PROFILE  notarytool keychain profile name; skip notarization if unset
set -eu
cd "$(dirname "$0")/.."

if [ -z "${SIGN_IDENTITY:-}" ]; then
    SIGN_IDENTITY=$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p' | head -1)
fi
export SIGN_IDENTITY="${SIGN_IDENTITY:--}"
scripts/bundle.sh

VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)
DMG="build/UsageWidget-$VERSION.dmg"
STAGING=build/dmg
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R build/UsageWidget.app "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -quiet -volname "Usage Widget" -srcfolder "$STAGING" -format UDZO "$DMG"
rm -rf "$STAGING"

if [ "$SIGN_IDENTITY" = "-" ]; then
    echo "Built $DMG (ad-hoc signed, not notarized; Gatekeeper will block it on other Macs)"
    exit 0
fi
codesign --sign "$SIGN_IDENTITY" --timestamp "$DMG"

if [ -z "${NOTARY_PROFILE:-}" ]; then
    echo "Built $DMG (signed, not notarized; set NOTARY_PROFILE to notarize)"
    exit 0
fi
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
spctl -a -t open --context context:primary-signature -v "$DMG"
echo "Built $DMG (signed and notarized)"
