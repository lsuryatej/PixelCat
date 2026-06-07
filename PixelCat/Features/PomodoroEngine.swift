import Foundation

/// Drives focus/break cycles and feeds the timer display in `CatState`. The
/// countdown is deadline-based (computed from a target date) so it stays
/// accurate even if a tick is late. The pixel timer in `CatSprite` is just the
/// view of this state.
final class PomodoroEngine {
    private let state: CatState

    /// Called when a phase finishes and the next one begins.
    var onPhaseChange: ((CatState.TimerPhase) -> Void)?

    private var timer: Timer?
    private var deadline: Date?
    private var pausedRemaining: Int

    init(state: CatState) {
        self.state = state
        self.pausedRemaining = Settings.focusMinutes * 60
        state.timerPhase = .focus
        state.timerTotal = Settings.focusMinutes * 60
        state.timerRemaining = pausedRemaining
    }

    var isRunning: Bool { deadline != nil }

    // MARK: Controls

    func startPause() { isRunning ? pause() : start() }

    func start() {
        if pausedRemaining <= 0 { loadPhase(state.timerPhase) }
        deadline = Date().addingTimeInterval(TimeInterval(pausedRemaining))
        state.timerRunning = true
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func pause() {
        pausedRemaining = state.timerRemaining
        deadline = nil
        timer?.invalidate(); timer = nil
        state.timerRunning = false
    }

    func reset() {
        pause()
        state.timerPhase = .focus
        loadPhase(.focus)
    }

    func skipPhase() {
        advance(announce: false)
    }

    /// Re-read durations after the user changes settings.
    func refreshDurations() {
        if !isRunning {
            loadPhase(state.timerPhase)
        }
    }

    // MARK: Internals

    private func tick() {
        guard let deadline else { return }
        let remaining = Int(ceil(deadline.timeIntervalSinceNow))
        if remaining <= 0 {
            advance(announce: true)
        } else {
            state.timerRemaining = remaining
        }
    }

    private func advance(announce: Bool) {
        let next: CatState.TimerPhase = (state.timerPhase == .focus) ? .brk : .focus
        state.timerPhase = next
        loadPhase(next)
        if isRunning {
            deadline = Date().addingTimeInterval(TimeInterval(pausedRemaining))
        }
        if announce { onPhaseChange?(next) }
    }

    private func loadPhase(_ phase: CatState.TimerPhase) {
        let minutes = (phase == .focus) ? Settings.focusMinutes : Settings.breakMinutes
        let seconds = max(1, minutes) * 60
        pausedRemaining = seconds
        state.timerTotal = seconds
        state.timerRemaining = seconds
    }
}
