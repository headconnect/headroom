#!/bin/sh
# Regenerates Resources/rations.icns and Resources/dmg-background.tiff from scripts/artwork.swift.
set -eu
cd "$(dirname "$0")/.."
WORK=build/artwork
rm -rf "$WORK"
swift scripts/artwork.swift "$WORK"
mkdir -p "$WORK/rations.iconset"
mv "$WORK"/icon_*.png "$WORK/rations.iconset/"
iconutil -c icns "$WORK/rations.iconset" -o Resources/rations.icns
tiffutil -cathidpicheck "$WORK/dmg-background.png" "$WORK/dmg-background@2x.png" -out Resources/dmg-background.tiff
echo "Wrote Resources/rations.icns and Resources/dmg-background.tiff"
