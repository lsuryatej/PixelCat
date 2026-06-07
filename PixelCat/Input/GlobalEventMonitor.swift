import AppKit

/// Watches global keyboard and scroll events (while other apps are focused).
/// Global keyDown/scrollWheel monitoring requires Accessibility permission;
/// without it these callbacks simply never fire.
final class GlobalEventMonitor {
    var onKeyDown: (() -> Void)?
    var onScroll: ((CGFloat) -> Void)?

    private var keyMonitor: Any?
    private var scrollMonitor: Any?

    func start() {
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] _ in
            self?.onKeyDown?()
        }
        scrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            let dy = event.scrollingDeltaY
            if dy != 0 { self?.onScroll?(dy) }
        }
    }

    func stop() {
        if let k = keyMonitor { NSEvent.removeMonitor(k); keyMonitor = nil }
        if let s = scrollMonitor { NSEvent.removeMonitor(s); scrollMonitor = nil }
    }

    deinit { stop() }
}
