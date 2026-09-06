#!/bin/sh
# Regenerates Resources/headroom.icns and Resources/dmg-background.tiff from scripts/artwork.swift.
set -eu
cd "$(dirname "$0")/.."
WORK=build/artwork
rm -rf "$WORK"
swift scripts/artwork.swift "$WORK"
mkdir -p "$WORK/headroom.iconset"
mv "$WORK"/icon_*.png "$WORK/headroom.iconset/"
iconutil -c icns "$WORK/headroom.iconset" -o Resources/headroom.icns
tiffutil -cathidpicheck "$WORK/dmg-background.png" "$WORK/dmg-background@2x.png" -out Resources/dmg-background.tiff
echo "Wrote Resources/headroom.icns and Resources/dmg-background.tiff"
