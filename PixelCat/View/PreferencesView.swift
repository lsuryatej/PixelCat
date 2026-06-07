import SwiftUI

// MARK: - Pixel theme

private enum PX {
    static let paper = Color(red: 0.99, green: 0.97, blue: 0.91)
    static let panel = Color(red: 0.96, green: 0.93, blue: 0.85)
    static let ink   = Color(red: 0.27, green: 0.21, blue: 0.19)
    static let sel   = Color(red: 0.96, green: 0.69, blue: 0.69)
    static let field = Color(red: 1.0, green: 0.99, blue: 0.96)

    static func font(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

/// Sharp 2px border with a flat fill — the building block of the pixel look.
private struct PixelBox: ViewModifier {
    var fill: Color
    var line: CGFloat = 2
    func body(content: Content) -> some View {
        content
            .background(Rectangle().fill(fill))
            .overlay(Rectangle().stroke(PX.ink, lineWidth: line))
    }
}

private extension View {
    func pixelBox(_ fill: Color, line: CGFloat = 2) -> some View { modifier(PixelBox(fill: fill, line: line)) }
}

// MARK: - Components

private struct PixelButton: View {
    let title: String
    var selected: Bool = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(PX.font(10))
                .foregroundStyle(PX.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .pixelBox(selected ? PX.sel : PX.paper)
    }
}

private struct PixelNumberField: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var onChange: (Int) -> Void = { _ in }

    var body: some View {
        HStack(spacing: 6) {
            Text(label.uppercased()).font(PX.font(10)).foregroundStyle(PX.ink)
            Spacer(minLength: 4)
            step("–") { set(value - 1) }
            TextField("", value: $value, format: .number)
                .font(PX.font(12))
                .foregroundStyle(PX.ink)
                .tint(PX.ink)
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)
                .frame(width: 40)
                .padding(.vertical, 3)
                .pixelBox(PX.field)
                .onChange(of: value) { _, v in set(v) }
            step("+") { set(value + 1) }
        }
    }

    private func set(_ v: Int) {
        let clamped = min(max(v, range.lowerBound), range.upperBound)
        if clamped != value { value = clamped }
        onChange(clamped)
    }

    private func step(_ t: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t).font(PX.font(14)).foregroundStyle(PX.ink).frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .pixelBox(PX.paper)
    }
}

private struct PixelToggle: View {
    let label: String
    @Binding var isOn: Bool
    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    Rectangle().fill(isOn ? PX.sel : PX.field)
                    if isOn { Text("✕").font(PX.font(11)).foregroundStyle(PX.ink) }
                }
                .frame(width: 18, height: 18)
                .overlay(Rectangle().stroke(PX.ink, lineWidth: 2))
                Text(label.uppercased()).font(PX.font(10)).foregroundStyle(PX.ink)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

private struct PixelTextField: View {
    let placeholder: String
    @Binding var text: String
    var body: some View {
        TextField(placeholder, text: $text)
            .font(PX.font(11, .medium))
            .foregroundStyle(PX.ink)
            .tint(PX.ink)
            .textFieldStyle(.plain)
            .padding(6)
            .pixelBox(PX.field)
    }
}

private struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(PX.font(11))
            .foregroundStyle(PX.ink)
            .padding(.bottom, 2)
            .overlay(Rectangle().fill(PX.ink).frame(height: 2), alignment: .bottom)
    }
}

// MARK: - Window

struct PreferencesView: View {
    var state: CatState
    let pomodoro: PomodoroEngine
    let setTimerVisible: (Bool) -> Void
    let rescheduleStretch: () -> Void
    let onClose: () -> Void

    @State private var preview = CatState()
    @State private var focus = Settings.focusMinutes
    @State private var brk = Settings.breakMinutes
    @State private var stretch = Settings.stretchIntervalMinutes

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                title
                previewBox
                appearanceSection
                timerSection
                youSection
            }
            .padding(16)
        }
        .frame(width: 300, height: 560)
        .background(PX.paper)
        .onAppear { syncPreview() }
        .onChange(of: state.coatColor) { _, _ in syncPreview() }
        .onChange(of: state.coatPattern) { _, _ in syncPreview() }
    }

    private var title: some View {
        HStack(spacing: 8) {
            Image(systemName: "pawprint.fill").foregroundStyle(PX.ink)
            Text("PIXELCAT").font(PX.font(15)).foregroundStyle(PX.ink)
            Spacer()
            Button(action: onClose) {
                Text("✕").font(PX.font(13)).foregroundStyle(PX.ink).frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .pixelBox(PX.paper)
            .help("Close (or right-click the cat)")
        }
    }

    // MARK: Preview (full cat — square canvas so nothing is cropped)

    private var previewBox: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
            Canvas { ctx, size in
                CatSprite.draw(in: &ctx, size: size, state: preview, time: tl.date.timeIntervalSinceReferenceDate)
            }
            .frame(width: 124, height: 132)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .pixelBox(PX.panel)
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
            SectionLabel(text: "Color")
            HStack(spacing: 8) {
                ForEach(CatColor.allCases, id: \.self) { c in
                    ZStack {
                        Rectangle().fill(c.palette.base)
                        if state.coatColor == c {
                            Rectangle().strokeBorder(PX.sel, lineWidth: 3).padding(2)
                        }
                    }
                    .frame(width: 30, height: 30)
                    .overlay(Rectangle().stroke(PX.ink, lineWidth: 2))
                    .contentShape(Rectangle())
                    .onTapGesture { state.coatColor = c; Settings.coatColor = c.rawValue }
                    .help(c.display)
                }
            }

            SectionLabel(text: "Pattern")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(CatPattern.allCases, id: \.self) { p in
                    PixelButton(title: p.display, selected: state.coatPattern == p) {
                        state.coatPattern = p; Settings.coatPattern = p.rawValue
                    }
                }
            }
        }
    }

    // MARK: Timer

    private var timerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Pomodoro Timer")
            PixelToggle(label: "Show below cat", isOn: Binding(
                get: { state.timerVisible }, set: { setTimerVisible($0) }
            ))
            PixelNumberField(label: "Focus min", value: $focus, range: 1...120) { v in
                Settings.focusMinutes = v; pomodoro.refreshDurations()
            }
            PixelNumberField(label: "Break min", value: $brk, range: 1...60) { v in
                Settings.breakMinutes = v; pomodoro.refreshDurations()
            }
            HStack(spacing: 8) {
                PixelButton(title: state.timerRunning ? "Pause" : "Start") { pomodoro.startPause() }
                PixelButton(title: "Reset") { pomodoro.reset() }
                PixelButton(title: "Skip") { pomodoro.skipPhase() }
            }
            .opacity(state.timerVisible ? 1 : 0.4)
            .disabled(!state.timerVisible)
        }
    }

    // MARK: You

    private var youSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "You")
            PixelTextField(placeholder: "Your name", text: Binding(
                get: { state.name }, set: { state.name = $0; Settings.name = $0 }
            ))
            PixelTextField(placeholder: "Pinned note", text: Binding(
                get: { state.pinnedNote }, set: { state.pinnedNote = $0; Settings.pinnedNote = $0 }
            ))
            PixelNumberField(label: "Stretch every", value: $stretch, range: 1...240) { v in
                Settings.stretchIntervalMinutes = v; rescheduleStretch()
            }
        }
    }
}
