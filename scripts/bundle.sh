#!/bin/sh
# Builds a release binary and wraps it in build/UsageWidget.app.
set -eu
cd "$(dirname "$0")/.."

swift build -c release --product UsageWidget
APP=build/UsageWidget.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/UsageWidget "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
codesign --force --sign - "$APP"
echo "Built $APP"
