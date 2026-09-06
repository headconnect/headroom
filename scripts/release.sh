#!/bin/sh
# Builds a signed app, packs it into a DMG, and notarizes it.
#   SIGN_IDENTITY   "Developer ID Application: Name (TEAMID)"; defaults to the one in your keychain, else ad-hoc
#   NOTARY_PROFILE  notarytool keychain profile name, or
#   NOTARY_APPLE_ID + NOTARY_PASSWORD + NOTARY_TEAM_ID for CI; notarization is skipped if neither is set
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

if [ -n "${NOTARY_PROFILE:-}" ]; then
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
elif [ -n "${NOTARY_APPLE_ID:-}" ]; then
    xcrun notarytool submit "$DMG" --apple-id "$NOTARY_APPLE_ID" --team-id "$NOTARY_TEAM_ID" --password "$NOTARY_PASSWORD" --wait
else
    echo "Built $DMG (signed, not notarized; set NOTARY_PROFILE to notarize)"
    exit 0
fi
xcrun stapler staple "$DMG"
spctl -a -t open --context context:primary-signature -v "$DMG"
echo "Built $DMG (signed and notarized)"
