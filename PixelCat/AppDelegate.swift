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

    private var prefsWindow: NSWindow?

    private let panelSize = NSSize(width: 134, height: 154)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        state.name = Settings.name
        state.pinnedNote = Settings.pinnedNote
        state.coatColor = CatColor(rawValue: Settings.coatColor) ?? .cream
        state.coatPattern = CatPattern(rawValue: Settings.coatPattern) ?? .solid

        setupPanel()
        setupStatusItem()

        controller = CatController(state: state, panel: panel)
        (panel.contentView as? CatHostingView)?.controller = controller
        controller.start()

        setupInput()
        setupAgentBridge()
        setupPomodoro()
        panel.orderFrontRegardless()

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

    /// Show/hide the timer shelf; the panel grows upward (bottom stays on the
    /// floor) so the timer sits below the cat.
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

    // MARK: Menu (quick actions only — everything configurable lives in Settings…)

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
        menu.addItem(withTitle: state.timerVisible ? "Hide Timer" : "Show Timer",
                     action: #selector(toggleTimer), keyEquivalent: "").target = self
        if state.timerVisible {
            menu.addItem(withTitle: state.timerRunning ? "Pause Timer" : "Start Timer",
                         action: #selector(timerStartPause), keyEquivalent: "").target = self
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        if !AccessibilityPermission.isTrusted {
            menu.addItem(withTitle: "Enable Keyboard/Scroll Tricks…",
                         action: #selector(requestAccessibility), keyEquivalent: "").target = self
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit PixelCat", action: #selector(quit), keyEquivalent: "q").target = self

        if let button = statusItem.button {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
        }
    }

    @objc private func toggleVisible() { state.visible.toggle() }
    @objc private func sleep() { state.visible = true; controller.setSleeping(true) }
    @objc private func wake() { state.visible = true; controller.setSleeping(false) }
    @objc private func stretchNow() { state.visible = true; controller.triggerStretch() }
    @objc private func toggleTimer() { setTimerVisible(!state.timerVisible) }
    @objc private func timerStartPause() { pomodoro.startPause() }
    @objc private func requestAccessibility() { AccessibilityPermission.prompt() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func openSettings() {
        if prefsWindow == nil {
            let view = PreferencesView(
                state: state,
                pomodoro: pomodoro,
                setTimerVisible: { [weak self] on in self?.setTimerVisible(on) },
                rescheduleStretch: { [weak self] in self?.controller.scheduleStretchReminder() }
            )
            let host = NSHostingController(rootView: view)
            let win = NSWindow(contentViewController: host)
            win.title = "PixelCat Settings"
            win.styleMask = [.titled, .closable]
            win.isReleasedWhenClosed = false
            win.level = .floating
            prefsWindow = win
        }
        NSApp.activate(ignoringOtherApps: true)
        prefsWindow?.center()
        prefsWindow?.makeKeyAndOrderFront(nil)
    }
}
