import Foundation

/// Which parts of a menu bar gauge to draw. An account without its own copy
/// follows the global settings, so changing those still moves it.
struct MenuBarOptions: Codable, Equatable {
    var bars = true
    var percent = true
    var session = true
    var weekly = true

    /// The global toggles; missing keys are on, matching the `@AppStorage`
    /// defaults in the settings UI.
    static func global(_ defaults: UserDefaults = .standard) -> MenuBarOptions {
        MenuBarOptions(
            bars: defaults.flag(Settings.menuBarBars),
            percent: defaults.flag(Settings.menuBarPercent),
            session: defaults.flag(Settings.menuBarSession),
            weekly: defaults.flag(Settings.menuBarWeekly)
        )
    }

    static func resolve(for account: Account, global: MenuBarOptions) -> MenuBarOptions {
        (account.menuBar ?? global).paired
    }

    /// At least one of bars/percent and one of session/weekly, so a gauge is
    /// never blank. The UI disables the last toggle of a pair, but stored or
    /// hand-edited defaults can still be all off.
    var paired: MenuBarOptions {
        var options = self
        if !bars, !percent { options.bars = true; options.percent = true }
        if !session, !weekly { options.session = true; options.weekly = true }
        return options
    }
}

private extension UserDefaults {
    func flag(_ key: String) -> Bool { object(forKey: key) == nil || bool(forKey: key) }
}
