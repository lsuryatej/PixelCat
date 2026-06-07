import AppKit

/// Drives the cat: gaze, idle/walk, poke reactions, mochi drag physics, mouse
/// hunt, petting/purr, keyboard knead + overheat, scroll paper-unroll, stretch
/// reminders, and AI-agent reactions. A single ~60 Hz tick resolves the current
/// mood from a set of flags/timestamps and eases all effect intensities.
final class CatController {
    let state: CatState
    unowned let panel: NSPanel
    private let sound = SoundSynth()

    private var tick: Timer?
    private var lastTick = ProcessInfo.processInfo.systemUptime

    // Idle / walk FSM
    private enum Behavior {
        case resting(until: TimeInterval)
        case walking(targetX: CGFloat)
    }
    private var behavior: Behavior
    private let walkSpeed: CGFloat = 36
    private let huntSpeed: CGFloat = 240

    // Mood flags / timestamps
    private var dragging = false
    private var sleeping = false
    private var happyUntil: TimeInterval = 0
    private var stretchUntil: TimeInterval = 0
    private var kneadUntil: TimeInterval = 0
    private var huntUntil: TimeInterval = 0
    private var huntTargetX: CGFloat = 0
    private var fileThinking = false
    private var axThinking = false

    // Mochi shake
    private var wobbleVel: Double = 0
    private var lastVelSignX = 0
    private var reversalCount = 0
    private var lastReversalTime: TimeInterval = 0

    // Typing / overheat
    private var keyTimes: [TimeInterval] = []

    // Petting
    private var headHover = false
    private var purring = false
    private var pettingUntil: TimeInterval = 0

    // Roaming is bounded to a "home box" centered where the cat sits; only a
    // drag relocates it. roamRadius = half the box width (set in start()).
    private var homeOriginX: CGFloat = 0
    private var roamRadius: CGFloat = 67

    // Bubble
    private var bubbleUntil: TimeInterval = 0

    // Mouse speed (for hunt)
    private var lastMousePos = NSEvent.mouseLocation
    private var lastMouseTime = ProcessInfo.processInfo.systemUptime

    // Stretch reminders
    private var stretchReminder: Timer?

    init(state: CatState, panel: NSPanel) {
        self.state = state
        self.panel = panel
        self.behavior = .resting(until: ProcessInfo.processInfo.systemUptime + 2)
        self.huntTargetX = panel.frame.origin.x
    }

    func start() {
        positionAtBottom()
        homeOriginX = panel.frame.origin.x
        roamRadius = panel.frame.width * 0.5      // box ≈ 2× the cat's width
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.step() }
        RunLoop.main.add(timer, forMode: .common)
        tick = timer
        scheduleStretchReminder()
    }

    // MARK: Reactions from input layer

    func poke() {
        guard !sleeping else { return }
        let now = ProcessInfo.processInfo.systemUptime
        happyUntil = now + 1.1
        state.lift = 16
        sound.meow()
    }

    func beginDrag() {
        guard !sleeping else { return }
        dragging = true
    }

    func dragMove(velocity v: CGVector) {
        guard dragging else { return }
        let speed = hypot(v.dx, v.dy)
        let amt = min(0.55, speed / 900.0)
        if abs(v.dy) >= abs(v.dx) {
            state.scaleY = 1 + amt
            state.scaleX = 1 - amt * 0.55
        } else {
            state.scaleX = 1 + amt
            state.scaleY = 1 - amt * 0.55
        }
        state.lift = 10
        detectShake(velocityX: v.dx, speed: speed)
    }

    func endDrag() {
        dragging = false
        snapToBottom()
    }

    /// Announce something (timer phase change, etc.): bubble + meow, optionally
    /// with a happy hop.
    func announce(_ text: String, happy: Bool) {
        guard !sleeping else { return }
        showBubble(text, seconds: 4)
        if happy {
            happyUntil = ProcessInfo.processInfo.systemUptime + 1.3
            state.lift = 16
        }
        sound.meow()
    }

    func setHeadHover(_ over: Bool) {
        headHover = over
        // Grace window so back-and-forth strokes (and brief exits off the top
        // of the window) keep the purr going.
        if over { pettingUntil = ProcessInfo.processInfo.systemUptime + 0.7 }
    }

    func onKeyDown() {
        guard !sleeping else { return }
        let now = ProcessInfo.processInfo.systemUptime
        keyTimes.append(now)
        kneadUntil = now + 0.5
    }

    func onScroll(_ delta: CGFloat) {
        guard !sleeping else { return }
        state.paper = min(1, state.paper + min(abs(delta), 30) / 40)
    }

    func setSleeping(_ value: Bool) {
        sleeping = value
        if value {
            stopPurr()
            state.scaleX = 1; state.scaleY = 1; state.lift = 0; state.stretch = 0
        } else {
            behavior = .resting(until: ProcessInfo.processInfo.systemUptime + 1.5)
        }
    }

    // MARK: Agent awareness

    func setAgentStatus(_ status: AgentBridge.Status) {
        switch status {
        case .thinking: fileThinking = true
        case .idle:     fileThinking = false
        case .done:     fileThinking = false; agentFinished()
        }
    }

    func setDesktopThinking(_ thinking: Bool) {
        if axThinking && !thinking { agentFinished() }   // thinking → idle edge = done
        axThinking = thinking
    }

    private func agentFinished() {
        guard !sleeping else { return }
        let now = ProcessInfo.processInfo.systemUptime
        happyUntil = now + 1.5
        state.lift = 20
        sound.meow()
        showBubble(state.name.isEmpty ? "done!" : "done, \(state.name)!", seconds: 3)
    }

    // MARK: Stretch reminder

    func scheduleStretchReminder() {
        stretchReminder?.invalidate()
        let minutes = max(1, Settings.stretchIntervalMinutes)
        let interval = TimeInterval(minutes * 60)
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in self?.triggerStretch() }
        RunLoop.main.add(timer, forMode: .common)
        stretchReminder = timer
    }

    func triggerStretch() {
        guard !sleeping else { return }
        let now = ProcessInfo.processInfo.systemUptime
        stretchUntil = now + 2.4
        let who = state.name.isEmpty ? "" : ", \(state.name)"
        showBubble("stretch time\(who)!", seconds: 4)
        sound.meow()
    }

    // MARK: Tick

    private func step() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(max(now - lastTick, 0), 0.1)
        lastTick = now

        updateGaze(now: now)
        integrateWobble(dt: dt)

        // Ease mochi deform + lift back to rest when not dragging.
        if !dragging {
            state.scaleX += (1 - state.scaleX) * min(1, dt * 12)
            state.scaleY += (1 - state.scaleY) * min(1, dt * 12)
            state.lift   += (0 - state.lift)   * min(1, dt * 10)
        }

        easeEffects(now: now, dt: dt)
        updatePurr()
        if !state.bubbleText.isEmpty && now >= bubbleUntil { state.bubbleText = "" }

        let mood = resolveMood(now: now)
        state.mood = mood
        move(mood: mood, now: now, dt: dt)
    }

    private func resolveMood(now: TimeInterval) -> CatState.Mood {
        if dragging { return .dragging }
        if sleeping { return .sleeping }
        if now < stretchUntil { return .stretching }
        if now < happyUntil { return .happy }
        if fileThinking || axThinking { return .thinking }
        if now < kneadUntil { return .kneading }
        if now < huntUntil { return .hunting }
        if case .walking = behavior { return .walking }
        return .idle
    }

    private func move(mood: CatState.Mood, now: TimeInterval, dt: TimeInterval) {
        switch mood {
        case .hunting:
            var origin = panel.frame.origin
            let dx = huntTargetX - origin.x
            state.facing = dx >= 0 ? 1 : -1
            let stepLen = huntSpeed * CGFloat(dt)
            origin.x += abs(dx) <= stepLen ? dx : (dx > 0 ? stepLen : -stepLen)
            origin.x = roamClampX(origin.x)
            panel.setFrameOrigin(origin)
        case .idle, .walking:
            stepBehavior(now: now, dt: dt)
        default:
            break   // frozen in place for dragging/sleeping/stretch/happy/think/knead
        }
    }

    private func stepBehavior(now: TimeInterval, dt: TimeInterval) {
        switch behavior {
        case .resting(let until):
            if now >= until { behavior = .walking(targetX: randomTargetX()) }
        case .walking(let targetX):
            var origin = panel.frame.origin
            let dx = targetX - origin.x
            state.facing = dx >= 0 ? 1 : -1
            let stepLen = walkSpeed * CGFloat(dt)
            if abs(dx) <= stepLen {
                origin.x = targetX
                panel.setFrameOrigin(origin)
                behavior = .resting(until: now + Double.random(in: 2...6))
            } else {
                origin.x += dx > 0 ? stepLen : -stepLen
                panel.setFrameOrigin(origin)
            }
        }
    }

    // MARK: Effects easing

    private func easeEffects(now: TimeInterval, dt: TimeInterval) {
        // Typing rate over the last second.
        keyTimes.removeAll { now - $0 > 2.0 }
        let rate = Double(keyTimes.filter { now - $0 <= 1.0 }.count)

        // Overheat: rises quickly with fast typing, cools slowly.
        let heatTarget = max(0, min(1, (rate - 7) / 9))
        let heatEase = heatTarget > state.heat ? dt * 1.4 : dt * 0.5
        state.heat += (heatTarget - state.heat) * min(1, heatEase)

        // Knead intensity (visual cue strength).
        let kneadTarget = now < kneadUntil ? max(0.4, min(1, rate / 9)) : 0
        state.knead += (kneadTarget - state.knead) * min(1, dt * 10)

        // Hearts while petting / purring.
        let heartsTarget = purring ? 1.0 : 0.0
        state.hearts += (heartsTarget - state.hearts) * min(1, dt * 6)

        // Paper retracts when you stop scrolling.
        state.paper += (0 - state.paper) * min(1, dt * 0.7)
        if state.paper < 0.005 { state.paper = 0 }

        // Stretch grow.
        let stretchTarget = now < stretchUntil ? 0.42 : 0
        state.stretch += (stretchTarget - state.stretch) * min(1, dt * 6)
    }

    private func updatePurr() {
        let now = ProcessInfo.processInfo.systemUptime
        let want = (headHover || now < pettingUntil) && !dragging && !sleeping
        if want && !purring { sound.startPurr(); purring = true }
        if !want && purring { stopPurr() }
        state.purring = purring
    }

    private func stopPurr() {
        if purring { sound.stopPurr(); purring = false }
        state.purring = false
    }

    // MARK: Gaze + hunt

    private func updateGaze(now: TimeInterval) {
        let mouse = NSEvent.mouseLocation
        let frame = panel.frame
        let eye = CGPoint(x: frame.midX, y: frame.minY + frame.height * 0.70)
        state.gaze = CGPoint(x: clamp((mouse.x - eye.x) / 240), y: clamp((mouse.y - eye.y) / 240))

        // Mouse speed → hunt.
        let dt = max(now - lastMouseTime, 1.0 / 240.0)
        let speed = hypot(mouse.x - lastMousePos.x, mouse.y - lastMousePos.y) / dt
        lastMousePos = mouse
        lastMouseTime = now

        if speed > 900 && !headHover && !dragging && !sleeping {
            huntUntil = now + 1.0
            huntTargetX = roamClampX(mouse.x - frame.width / 2)   // lean toward the cursor, within the box
        }
    }

    // MARK: Shake / wobble

    private func detectShake(velocityX vx: CGFloat, speed: CGFloat) {
        guard speed > 350 else { return }
        let sign = vx > 0 ? 1 : -1
        let now = ProcessInfo.processInfo.systemUptime
        if sign != lastVelSignX && lastVelSignX != 0 {
            reversalCount = (now - lastReversalTime < 0.45) ? reversalCount + 1 : 1
            lastReversalTime = now
            if reversalCount >= 3 {
                wobbleVel += Double(sign) * 7
                reversalCount = 0
            }
        }
        lastVelSignX = sign
    }

    private func integrateWobble(dt: TimeInterval) {
        let k = 190.0, c = 13.0
        wobbleVel += (-k * state.wobble - c * wobbleVel) * dt
        state.wobble += wobbleVel * dt
        if abs(state.wobble) < 0.0005 && abs(wobbleVel) < 0.0005 { state.wobble = 0; wobbleVel = 0 }
    }

    // MARK: Bubble

    private func showBubble(_ text: String, seconds: TimeInterval) {
        state.bubbleText = text
        bubbleUntil = ProcessInfo.processInfo.systemUptime + seconds
    }

    // MARK: Positioning

    func positionAtBottom() {
        guard let screen = panel.screen ?? NSScreen.main else { return }
        let vf = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(x: vf.midX - panel.frame.width / 2, y: vf.minY))
    }

    private func snapToBottom() {
        guard let screen = panel.screen ?? NSScreen.main else { return }
        let vf = screen.visibleFrame
        var origin = clampX(panel.frame.origin)
        origin.y = vf.minY
        // Relocate the home box to wherever the cat was dropped.
        homeOriginX = origin.x
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrameOrigin(origin)
        }
    }

    /// Clamp an x-origin to the home box (and then the screen).
    private func roamClampX(_ x: CGFloat) -> CGFloat {
        var v = min(max(x, homeOriginX - roamRadius), homeOriginX + roamRadius)
        if let screen = panel.screen ?? NSScreen.main {
            let vf = screen.visibleFrame
            v = min(max(v, vf.minX + 4), vf.maxX - panel.frame.width - 4)
        }
        return v
    }

    private func clampX(_ point: NSPoint) -> NSPoint {
        guard let screen = panel.screen ?? NSScreen.main else { return point }
        let vf = screen.visibleFrame
        var p = point
        p.x = min(max(p.x, vf.minX + 4), vf.maxX - panel.frame.width - 4)
        return p
    }

    private func randomTargetX() -> CGFloat {
        let lo = homeOriginX - roamRadius
        let hi = homeOriginX + roamRadius
        guard hi > lo else { return homeOriginX }
        return roamClampX(CGFloat.random(in: lo...hi))
    }

    private func clamp(_ v: CGFloat) -> CGFloat { max(-1, min(1, v)) }
}
