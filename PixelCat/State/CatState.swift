import SwiftUI
import Observation

/// Central, observable state for the cat. Holds discrete state set by events
/// (mood, gaze, mochi deform, name) and eased effect intensities. Continuous
/// time-based animation (breathing, blink, tail flick) is driven by the
/// TimelineView clock in `CatView`, not here.
@Observable
final class CatState {

    enum Mood: Equatable {
        case idle
        case walking
        case happy       // brief reaction to a poke / click / agent done
        case dragging
        case hunting     // chasing a fast-moving cursor
        case kneading    // kneading the keyboard while you type
        case stretching  // stretch reminder grow
        case sleeping
        case thinking    // a supported AI agent is working
    }

    // High-level behavior
    var mood: Mood = .idle
    var visible: Bool = true

    /// -1 facing left, +1 facing right.
    var facing: Double = 1

    /// Normalized gaze direction toward the mouse. x,y in roughly [-1, 1].
    /// +y means the mouse is *above* the cat.
    var gaze: CGPoint = .zero

    // Mochi deformation (1 = neutral).
    var scaleX: Double = 1
    var scaleY: Double = 1

    /// Extra vertical lift (points) for hops / drag.
    var lift: Double = 0

    /// Side-to-side wobble angle in radians (decays to 0). Driven by shake.
    var wobble: Double = 0

    // Eased effect intensities (0…1 unless noted)
    var heat: Double = 0        // overheat: red tint + steam
    var hearts: Double = 0      // petting/purr hearts
    var knead: Double = 0       // typing knead intensity
    var paper: Double = 0       // scroll paper-roll unroll amount
    var stretch: Double = 0     // stretch reminder grow (0…~0.45)
    var purring: Bool = false

    // Text bubbles above the head
    var pinnedNote: String = "" // persistent note
    var bubbleText: String = "" // transient (stretch reminder / agent done)

    /// The user's name, used in reminder copy.
    var name: String = ""

    // Appearance
    var coatColor: CatColor = .cream
    var coatPattern: CatPattern = .solid

    // Pomodoro / DeskMinder timer
    enum TimerPhase { case focus, brk }
    var timerVisible = false
    var timerRunning = false
    var timerPhase: TimerPhase = .focus
    var timerRemaining = 0       // seconds left in the current phase
    var timerTotal = 0           // full length of the current phase (for the bar)

    var isInteracting: Bool { mood == .dragging || mood == .happy }
}
