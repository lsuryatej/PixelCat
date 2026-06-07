import SwiftUI

/// Hosts the SwiftUI `CatView` but takes over mouse handling at the AppKit layer
/// so we can move the borderless panel, distinguish a click (poke) from a drag
/// (mochi lift), measure drag velocity for stretch + shake, and detect hovering
/// over the head for petting.
final class CatHostingView: NSHostingView<CatView> {
    weak var controller: CatController?

    private var grabOffset: NSPoint = .zero
    private var didDrag = false
    private var lastMouse: NSPoint = .zero
    private var lastMoveTime: TimeInterval = 0
    private var trackingAreaRef: NSTrackingArea?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: Tracking area (hover / petting)

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = trackingAreaRef { removeTrackingArea(t) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingAreaRef = area
    }

    override func mouseMoved(with event: NSEvent) {
        updateHover(event.locationInWindow)
    }

    override func mouseExited(with event: NSEvent) {
        controller?.setHeadHover(false)
    }

    private func updateHover(_ p: NSPoint) {
        // locationInWindow: origin bottom-left. The head sits in the upper-
        // center of the window; pet there.
        let overHead = p.y > bounds.height * 0.40
            && p.x > bounds.width * 0.12
            && p.x < bounds.width * 0.88
        controller?.setHeadHover(overHead)
    }

    // MARK: Drag / click

    override func mouseDown(with event: NSEvent) {
        grabOffset = event.locationInWindow
        lastMouse = NSEvent.mouseLocation
        lastMoveTime = ProcessInfo.processInfo.systemUptime
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window = window else { return }
        let mouse = NSEvent.mouseLocation

        if !didDrag {
            didDrag = true
            controller?.beginDrag()
        }

        let newOrigin = NSPoint(x: mouse.x - grabOffset.x, y: mouse.y - grabOffset.y)
        window.setFrameOrigin(newOrigin)

        let now = ProcessInfo.processInfo.systemUptime
        let dt = max(now - lastMoveTime, 1.0 / 240.0)
        let vel = CGVector(dx: (mouse.x - lastMouse.x) / dt, dy: (mouse.y - lastMouse.y) / dt)
        controller?.dragMove(velocity: vel)
        lastMouse = mouse
        lastMoveTime = now
    }

    override func mouseUp(with event: NSEvent) {
        if didDrag {
            controller?.endDrag()
        } else {
            controller?.poke()
        }
        didDrag = false
    }
}
