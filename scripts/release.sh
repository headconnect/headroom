#!/bin/sh
# Builds a signed app, packs it into a DMG, and notarizes it.
#   VERSION         app version, e.g. 1.2; defaults to the one in Resources/Info.plist
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

VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "build/Range Anxiety.app/Contents/Info.plist")
DMG="build/range-anxiety-$VERSION.dmg"
STAGING=build/dmg
RW=build/range-anxiety-rw.dmg
rm -rf "$STAGING" "$DMG" "$RW"
mkdir -p "$STAGING/.background"
cp -R "build/Range Anxiety.app" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
cp Resources/dmg-background.tiff "$STAGING/.background/background.tiff"
cp Resources/range-anxiety.icns "$STAGING/.VolumeIcon.icns"
hdiutil create -quiet -volname "Range Anxiety" -srcfolder "$STAGING" -format UDRW -ov "$RW"
rm -rf "$STAGING"

# Mount it and let Finder lay out the window (background, icon positions) into its .DS_Store.
MOUNT=$(hdiutil attach -readwrite -noverify -noautoopen -nobrowse "$RW" | sed -n 's|.*\(/Volumes/.*\)|\1|p')
SetFile -a C "$MOUNT"
sleep 1
osascript scripts/dmg-layout.applescript "$(basename "$MOUNT")" || echo "warning: Finder layout failed; DMG will use the default window"
sync
hdiutil detach -quiet "$MOUNT"
hdiutil convert -quiet -format UDZO -o "$DMG" "$RW"
rm -f "$RW"

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
# The ticket can take a moment to propagate after acceptance; retry the staple.
for attempt in 1 2 3 4 5 6; do
    xcrun stapler staple "$DMG" && break
    [ "$attempt" = 6 ] && exit 1
    sleep 10
done
spctl -a -t open --context context:primary-signature -v "$DMG"
echo "Built $DMG (signed and notarized)"
