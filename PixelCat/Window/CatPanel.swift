import AppKit

/// Borderless, transparent, always-on-top floating panel that hosts the cat.
/// Non-activating so clicking the cat never steals focus from your real work.
final class CatPanel: NSPanel {

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        backgroundColor = .clear
        isOpaque = false
        hasShadow = false

        // We move the panel ourselves (walking / dragging); don't let the
        // system drag it by its background.
        isMovableByWindowBackground = false

        // Receive mouse-moved events for hover/petting (Phase 2).
        acceptsMouseMovedEvents = true

        // Stay put through Mission Control / app hiding.
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
    }

    // Non-activating: never become key/main so focus stays with the user's app.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
