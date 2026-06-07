import AppKit
import ApplicationServices

/// EXPERIMENTAL. Claude Desktop exposes no official "thinking / done" signal,
/// so this infers it by inspecting the app's Accessibility tree: while Claude is
/// generating, its composer shows a "stop" control; when idle it shows "send".
/// We poll for a stop-like control and treat its appearance/disappearance as
/// thinking/done.
///
/// This is fragile by nature — if Anthropic restyles the desktop UI, the
/// heuristic in `appearsThinking(in:)` may need re-tuning. Requires Accessibility
/// permission (the same grant the keyboard/scroll features need).
final class ClaudeDesktopWatcher {
    /// Called on a transition. `true` = started thinking, `false` = finished.
    var onThinkingChanged: ((Bool) -> Void)?

    private var timer: Timer?
    private var wasThinking = false

    func start() {
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in self?.poll() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() { timer?.invalidate(); timer = nil }

    private func poll() {
        guard AXIsProcessTrusted(), let pid = claudeDesktopPID() else {
            if wasThinking { wasThinking = false; onThinkingChanged?(false) }
            return
        }
        let app = AXUIElementCreateApplication(pid)
        let thinking = appearsThinking(in: app, depth: 0, budget: Budget())
        if thinking != wasThinking {
            wasThinking = thinking
            onThinkingChanged?(thinking)
        }
    }

    // MARK: App discovery

    private func claudeDesktopPID() -> pid_t? {
        for app in NSWorkspace.shared.runningApplications {
            let bundle = app.bundleIdentifier ?? ""
            let name = app.localizedName ?? ""
            // The desktop app, not this pet and not a terminal "Claude Code".
            if bundle == "com.anthropic.claudefordesktop"
                || (name == "Claude" && bundle != Bundle.main.bundleIdentifier) {
                return app.processIdentifier
            }
        }
        return nil
    }

    // MARK: AX traversal

    private final class Budget { var nodes = 0; let max = 4000 }

    /// Looks for a control that reads like a "stop generating" button.
    private func appearsThinking(in element: AXUIElement, depth: Int, budget: Budget) -> Bool {
        if depth > 16 || budget.nodes > budget.max { return false }
        budget.nodes += 1

        let role = stringAttr(element, kAXRoleAttribute) ?? ""
        if role == kAXButtonRole as String {
            let label = [
                stringAttr(element, kAXTitleAttribute),
                stringAttr(element, kAXDescriptionAttribute),
                stringAttr(element, kAXHelpAttribute),
                stringAttr(element, "AXRoleDescription"),
            ].compactMap { $0 }.joined(separator: " ").lowercased()

            if label.contains("stop") && !label.contains("stopped") {
                return true
            }
        }

        for child in children(of: element) {
            if appearsThinking(in: child, depth: depth + 1, budget: budget) { return true }
        }
        return false
    }

    private func children(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
              let arr = value as? [AXUIElement] else { return [] }
        return arr
    }

    private func stringAttr(_ element: AXUIElement, _ attr: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attr as CFString, &value) == .success else { return nil }
        return value as? String
    }
}
