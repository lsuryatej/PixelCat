import Foundation

/// Thin UserDefaults-backed persistence. Keep it tiny; grows in Phase 2
/// (reminder interval, pinned note, etc.).
enum Settings {
    private static let nameKey = "pixelcat.name"
    private static let stretchIntervalKey = "pixelcat.stretchInterval"
    private static let pinnedNoteKey = "pixelcat.pinnedNote"

    static var name: String {
        get { UserDefaults.standard.string(forKey: nameKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: nameKey) }
    }

    /// Minutes between stretch reminders. 0 = disabled. Phase 2.
    static var stretchIntervalMinutes: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: stretchIntervalKey)
            return v == 0 ? 30 : v
        }
        set { UserDefaults.standard.set(newValue, forKey: stretchIntervalKey) }
    }

    /// Pinned note text shown above the cat. Empty = hidden. Phase 2.
    static var pinnedNote: String {
        get { UserDefaults.standard.string(forKey: pinnedNoteKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: pinnedNoteKey) }
    }

    // MARK: Pomodoro timer

    private static let timerEnabledKey = "pixelcat.timerEnabled"
    private static let focusMinutesKey = "pixelcat.focusMinutes"
    private static let breakMinutesKey = "pixelcat.breakMinutes"

    static var timerEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: timerEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: timerEnabledKey) }
    }

    static var focusMinutes: Int {
        get { let v = UserDefaults.standard.integer(forKey: focusMinutesKey); return v == 0 ? 25 : v }
        set { UserDefaults.standard.set(newValue, forKey: focusMinutesKey) }
    }

    static var breakMinutes: Int {
        get { let v = UserDefaults.standard.integer(forKey: breakMinutesKey); return v == 0 ? 5 : v }
        set { UserDefaults.standard.set(newValue, forKey: breakMinutesKey) }
    }
}
