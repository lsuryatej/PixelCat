import SwiftUI

/// A persistent settings window with a live cat preview. Unlike the menu (which
/// closes on every click), this stays open so you can flip through colors,
/// patterns, and timer options and see them apply instantly.
struct PreferencesView: View {
    var state: CatState
    let pomodoro: PomodoroEngine
    let setTimerVisible: (Bool) -> Void
    let rescheduleStretch: () -> Void

    /// A separate, always-visible, timer-less cat just for the preview, kept in
    /// sync with the chosen color/pattern.
    @State private var preview = CatState()
    @State private var focus = Settings.focusMinutes
    @State private var brk = Settings.breakMinutes
    @State private var stretch = Settings.stretchIntervalMinutes

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            previewBox
            appearanceSection
            Divider()
            timerSection
            Divider()
            youSection
        }
        .padding(18)
        .frame(width: 340)
        .onAppear { syncPreview() }
        .onChange(of: state.coatColor) { _, _ in syncPreview() }
        .onChange(of: state.coatPattern) { _, _ in syncPreview() }
    }

    // MARK: Preview

    private var previewBox: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
            Canvas { ctx, size in
                CatSprite.draw(in: &ctx, size: size, state: preview, time: tl.date.timeIntervalSinceReferenceDate)
            }
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.06)))
    }

    private func syncPreview() {
        preview.coatColor = state.coatColor
        preview.coatPattern = state.coatPattern
        preview.timerVisible = false
        preview.visible = true
    }

    // MARK: Appearance

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            header("Appearance")

            Text("Color").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                ForEach(CatColor.allCases, id: \.self) { c in
                    Circle()
                        .fill(c.palette.base)
                        .frame(width: 26, height: 26)
                        .overlay(
                            Circle().stroke(state.coatColor == c ? Color.accentColor : Color.primary.opacity(0.2),
                                            lineWidth: state.coatColor == c ? 3 : 1)
                        )
                        .contentShape(Circle())
                        .onTapGesture { state.coatColor = c; Settings.coatColor = c.rawValue }
                        .help(c.display)
                }
            }

            Text("Pattern").font(.caption).foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(CatPattern.allCases, id: \.self) { p in
                    Button(p.display) { state.coatPattern = p; Settings.coatPattern = p.rawValue }
                        .buttonStyle(.bordered)
                        .tint(state.coatPattern == p ? .accentColor : .secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: Timer

    private var timerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            header("Pomodoro Timer")

            Toggle("Show timer below cat", isOn: Binding(
                get: { state.timerVisible },
                set: { setTimerVisible($0) }
            ))

            Stepper("Focus: \(focus) min", value: $focus, in: 1...120)
                .onChange(of: focus) { _, v in Settings.focusMinutes = v; pomodoro.refreshDurations() }
            Stepper("Break: \(brk) min", value: $brk, in: 1...60)
                .onChange(of: brk) { _, v in Settings.breakMinutes = v; pomodoro.refreshDurations() }

            HStack {
                Button(state.timerRunning ? "Pause" : "Start") { pomodoro.startPause() }
                Button("Reset") { pomodoro.reset() }
                Button("Skip Phase") { pomodoro.skipPhase() }
            }
            .disabled(!state.timerVisible)
        }
    }

    // MARK: You

    private var youSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            header("You")

            TextField("Your name", text: Binding(
                get: { state.name },
                set: { state.name = $0; Settings.name = $0 }
            ))
            TextField("Pinned note (above the cat)", text: Binding(
                get: { state.pinnedNote },
                set: { state.pinnedNote = $0; Settings.pinnedNote = $0 }
            ))
            Stepper("Stretch reminder: every \(stretch) min", value: $stretch, in: 1...240)
                .onChange(of: stretch) { _, v in Settings.stretchIntervalMinutes = v; rescheduleStretch() }
        }
        .textFieldStyle(.roundedBorder)
    }

    private func header(_ text: String) -> some View {
        Text(text).font(.headline)
    }
}
