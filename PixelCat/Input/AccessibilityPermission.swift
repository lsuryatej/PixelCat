import ApplicationServices

/// Helpers for the Accessibility permission required to monitor global keyboard
/// and scroll events (and to inspect the Claude Desktop window).
enum AccessibilityPermission {

    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Prompts the user (once) to grant Accessibility access. Shows the system
    /// dialog that deep-links into System Settings.
    @discardableResult
    static func prompt() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
