-- Lays out the mounted DMG's Finder window: app on the left, Applications on the right,
-- over Resources/dmg-background.tiff. Usage: osascript scripts/dmg-layout.applescript <volume name>
on run argv
    set volumeName to item 1 of argv
    tell application "Finder"
        tell disk volumeName
            open
            set current view of container window to icon view
            set toolbar visible of container window to false
            set statusbar visible of container window to false
            set bounds of container window to {400, 200, 1060, 600}
            set options to icon view options of container window
            set arrangement of options to not arranged
            set icon size of options to 128
            set text size of options to 13
            set background picture of options to file ".background:background.tiff"
            set position of item "Range Anxiety.app" of container window to {165, 175}
            set position of item "Applications" of container window to {495, 175}
            close
            open
            update without registering applications
            delay 2
            close
        end tell
    end tell
end run
