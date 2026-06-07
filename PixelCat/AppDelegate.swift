import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    private let state = CatState()
    private var panel: CatPanel!
    private var controller: CatController!
    private var statusItem: NSStatusItem!

    private let monitor = GlobalEventMonitor()
    private let agentBridge = AgentBridge()
    private let desktopWatcher = ClaudeDesktopWatcher()
    private var pomodoro: PomodoroEngine!

    private let panelSize = NSSize(width: 134, height: 154)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        state.name = Settings.name
        state.pinnedNote = Settings.pinnedNote

        setupPanel()
        setupStatusItem()

        controller = CatController(state: state, panel: panel)
        (panel.contentView as? CatHostingView)?.controller = controller
        controller.start()

        setupInput()
        setupAgentBridge()
        setupPomodoro()
        panel.orderFrontRegardless()

        // Ask for Accessibility so global keyboard/scroll + the desktop watcher
        // can work. Eye-follow / drag / petting work without it.
        AccessibilityPermission.prompt()
    }

    // MARK: Setup

    private func setupPanel() {
        let rect = NSRect(origin: .zero, size: panelSize)
        panel = CatPanel(contentRect: rect)
        let host = CatHostingView(rootView: CatView(state: state))
        host.frame = rect
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
    }

    private func setupInput() {
        monitor.onKeyDown = { [weak self] in self?.controller.onKeyDown() }
        monitor.onScroll = { [weak self] delta in self?.controller.onScroll(delta) }
        monitor.start()
    }

    private func setupAgentBridge() {
        agentBridge.onStatus = { [weak self] status in self?.controller.setAgentStatus(status) }
        agentBridge.start()

        desktopWatcher.onThinkingChanged = { [weak self] thinking in
            self?.controller.setDesktopThinking(thinking)
        }
        desktopWatcher.start()
    }

    private func setupPomodoro() {
        pomodoro = PomodoroEngine(state: state)
        pomodoro.onPhaseChange = { [weak self] phase in
            guard let self else { return }
            let who = self.state.name.isEmpty ? "" : ", \(self.state.name)"
            switch phase {
            case .focus: self.controller.announce("focus\(who)!", happy: false)
            case .brk:   self.controller.announce("break time\(who)!", happy: true)
            }
        }
        if Settings.timerEnabled { setTimerVisible(true) }
    }

    /// Show/hide the timer shelf. The panel grows taller (upward, bottom stays
    /// on the floor) so the timer sits below the cat.
    private func setTimerVisible(_ on: Bool) {
        state.timerVisible = on
        Settings.timerEnabled = on
        if on { pomodoro.refreshDurations() } else { pomodoro.pause() }

        var frame = panel.frame
        let bottom = frame.minY
        frame.size.height = panelSize.height + (on ? CatSprite.timerStripHeight : 0)
        frame.origin.y = bottom
        panel.setFrame(frame, display: true, animate: true)
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "PixelCat")
            button.image?.isTemplate = true
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    // MARK: Status item

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else {
            toggleVisible()
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: state.visible ? "Hide" : "Show",
                     action: #selector(toggleVisible), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Sleep", action: #selector(sleep), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Wake", action: #selector(wake), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Stretch Now", action: #selector(stretchNow), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Set Name…", action: #selector(setName), keyEquivalent: "").target = self
        menu.addItem(withTitle: state.pinnedNote.isEmpty ? "Pin Note…" : "Edit Note…",
                     action: #selector(pinNote), keyEquivalent: "").target = self
        if !state.pinnedNote.isEmpty {
            menu.addItem(withTitle: "Clear Note", action: #selector(clearNote), keyEquivalent: "").target = self
        }
        menu.addItem(withTitle: "Stretch Interval…", action: #selector(setStretchInterval), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(buildTimerMenu())
        menu.addItem(.separator())
        if !AccessibilityPermission.isTrusted {
            menu.addItem(withTitle: "Enable Keyboard/Scroll Tricks…",
                         action: #selector(requestAccessibility), keyEquivalent: "").target = self
            menu.addItem(.separator())
        }
        menu.addItem(withTitle: "Quit PixelCat", action: #selector(quit), keyEquivalent: "q").target = self

        if let button = statusItem.button {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
        }
    }

    private func buildTimerMenu() -> NSMenuItem {
        let item = NSMenuItem(title: "Pomodoro Timer", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        sub.addItem(withTitle: state.timerVisible ? "Hide Timer" : "Show Timer",
                    action: #selector(toggleTimer), keyEquivalent: "").target = self
        if state.timerVisible {
            sub.addItem(withTitle: pomodoro.isRunning ? "Pause" : "Start",
                        action: #selector(timerStartPause), keyEquivalent: "").target = self
            sub.addItem(withTitle: "Reset", action: #selector(timerReset), keyEquivalent: "").target = self
            sub.addItem(withTitle: "Skip Phase", action: #selector(timerSkip), keyEquivalent: "").target = self
        }
        sub.addItem(.separator())
        sub.addItem(withTitle: "Focus Length… (\(Settings.focusMinutes)m)",
                    action: #selector(setFocusLength), keyEquivalent: "").target = self
        sub.addItem(withTitle: "Break Length… (\(Settings.breakMinutes)m)",
                    action: #selector(setBreakLength), keyEquivalent: "").target = self
        item.submenu = sub
        return item
    }

    @objc private func toggleTimer() { setTimerVisible(!state.timerVisible) }
    @objc private func timerStartPause() { pomodoro.startPause() }
    @objc private func timerReset() { pomodoro.reset() }
    @objc private func timerSkip() { pomodoro.skipPhase() }

    @objc private func setFocusLength() {
        promptText(title: "Focus length", info: "Minutes of focus per cycle.",
                   placeholder: "25", initial: String(Settings.focusMinutes)) { value in
            if let m = Int(value), m > 0 { Settings.focusMinutes = m; self.pomodoro.refreshDurations() }
        }
    }

    @objc private func setBreakLength() {
        promptText(title: "Break length", info: "Minutes of break per cycle.",
                   placeholder: "5", initial: String(Settings.breakMinutes)) { value in
            if let m = Int(value), m > 0 { Settings.breakMinutes = m; self.pomodoro.refreshDurations() }
        }
    }

    @objc private func toggleVisible() { state.visible.toggle() }
    @objc private func sleep() { state.visible = true; controller.setSleeping(true) }
    @objc private func wake() { state.visible = true; controller.setSleeping(false) }
    @objc private func stretchNow() { state.visible = true; controller.triggerStretch() }
    @objc private func requestAccessibility() { AccessibilityPermission.prompt() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func setName() {
        promptText(title: "What's your name?",
                   info: "The cat calls you by name in reminders and when an agent finishes.",
                   placeholder: "Your name",
                   initial: state.name) { value in
            self.state.name = value
            Settings.name = value
        }
    }

    @objc private func pinNote() {
        promptText(title: "Pin a note",
                   info: "Shown in a bubble above the cat until you clear it.",
                   placeholder: "Remember to…",
                   initial: state.pinnedNote) { value in
            self.state.pinnedNote = value
            Settings.pinnedNote = value
        }
    }

    @objc private func clearNote() {
        state.pinnedNote = ""
        Settings.pinnedNote = ""
    }

    @objc private func setStretchInterval() {
        promptText(title: "Stretch reminder",
                   info: "Minutes between stretch reminders.",
                   placeholder: "30",
                   initial: String(Settings.stretchIntervalMinutes)) { value in
            if let minutes = Int(value), minutes > 0 {
                Settings.stretchIntervalMinutes = minutes
                self.controller.scheduleStretchReminder()
            }
        }
    }

    // MARK: Helper

    private func promptText(title: String, info: String, placeholder: String, initial: String, onSave: @escaping (String) -> Void) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = info
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.stringValue = initial
        field.placeholderString = placeholder
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            onSave(field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
