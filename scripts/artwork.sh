#!/bin/sh
# Regenerates Resources/range-anxiety.icns and Resources/dmg-background.tiff from scripts/artwork.swift.
set -eu
cd "$(dirname "$0")/.."
WORK=build/artwork
rm -rf "$WORK"
swift scripts/artwork.swift "$WORK"
mkdir -p "$WORK/range-anxiety.iconset"
mv "$WORK"/icon_*.png "$WORK/range-anxiety.iconset/"
iconutil -c icns "$WORK/range-anxiety.iconset" -o Resources/range-anxiety.icns
tiffutil -cathidpicheck "$WORK/dmg-background.png" "$WORK/dmg-background@2x.png" -out Resources/dmg-background.tiff
echo "Wrote Resources/range-anxiety.icns and Resources/dmg-background.tiff"
