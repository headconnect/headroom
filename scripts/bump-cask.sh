#!/bin/sh
# Updates the rations cask in the homebrew-tap checkout for a new release.
#   scripts/bump-cask.sh <tap checkout dir> <version> <dmg path>
set -eu
TAP=$1
VERSION=$2
SHA=$(shasum -a 256 "$3" | cut -d' ' -f1)
CASK="$TAP/Casks/rations.rb"
sed -i '' -e "s/^  version \".*\"/  version \"$VERSION\"/" -e "s/^  sha256 \".*\"/  sha256 \"$SHA\"/" "$CASK"
grep -q "version \"$VERSION\"" "$CASK" && grep -q "sha256 \"$SHA\"" "$CASK"
echo "Cask bumped to $VERSION ($SHA)"
