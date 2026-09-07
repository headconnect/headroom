import Foundation

/// UserDefaults keys and defaults; read with `@AppStorage(Settings.x, ...)`.
enum Settings {
    static let menuBarBars = "menuBar.bars"          // Bool, true
    static let menuBarPercent = "menuBar.percent"    // Bool, true
    static let menuBarSession = "menuBar.session"    // Bool, true
    static let menuBarWeekly = "menuBar.weekly"      // Bool, true
    static let popoverOpacity = "popover.opacity"    // Double, 0.75
    static let checkForUpdates = "updates.check"     // Bool, false
    static let accounts = "accounts"                 // Data, JSON [Account] in display order

    static let defaultPopoverOpacity = 0.75
    static let minPopoverOpacity = 0.3
}
