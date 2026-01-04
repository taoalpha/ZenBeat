import SwiftUI

struct AppButtonStyle: ButtonStyle {
    var color: Color = .accentColor
    var isDestructive: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isDestructive ? Color.red.opacity(configuration.isPressed ? 0.2 : 0.1) : color.opacity(configuration.isPressed ? 0.2 : 0.1))
            )
            .foregroundStyle(isDestructive ? .red : color)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
            .contentShape(Rectangle())
            .onHover { inside in
                if inside {
                    NSCursor.pointingHand.set()
                } else {
                    NSCursor.arrow.set()
                }
            }
    }
}

struct PointingCursorModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onHover { inside in
                if inside {
                    NSCursor.pointingHand.set()
                } else {
                    NSCursor.arrow.set()
                }
            }
    }
}

extension View {
    func pointingCursor() -> some View {
        self.modifier(PointingCursorModifier())
    }
}
