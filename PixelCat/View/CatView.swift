import SwiftUI

/// Renders the cat plus its text bubbles. The TimelineView clock drives
/// continuous animation; `CatState` supplies discrete state. All input
/// (drag/click/hover) is handled at the AppKit layer in `CatHostingView`.
struct CatView: View {
    var state: CatState

    private var topText: String {
        !state.bubbleText.isEmpty ? state.bubbleText : state.pinnedNote
    }

    var body: some View {
        ZStack(alignment: .top) {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
                Canvas { context, size in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    CatSprite.draw(in: &context, size: size, state: state, time: t)
                }
            }

            if !topText.isEmpty {
                bubble(topText)
                    .padding(.top, 2)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .opacity(state.visible ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: state.visible)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: topText)
    }

    private func bubble(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color(red: 0.27, green: 0.21, blue: 0.19))
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(red: 0.99, green: 0.98, blue: 0.94))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color(red: 0.27, green: 0.21, blue: 0.19).opacity(0.5), lineWidth: 1)
                    )
            )
            .frame(maxWidth: 120)
    }
}
