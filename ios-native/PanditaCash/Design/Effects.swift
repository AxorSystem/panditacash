import SwiftUI
import UIKit

// MARK: - Card blanco/pastel (subtle, natural)

struct GlassCard<Content: View>: View {
    var padding: CGFloat = 20
    var cornerRadius: CGFloat = 24
    var tint: Color = Theme.surfaceLight
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint)
            )
    }
}

// MARK: - Press style con bounce

struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Primary button (verde bosque profundo, radius grande)

struct DuoButton: View {
    let title: String
    var icon: String? = nil
    var color: Color = Theme.deepGreen
    var shadowColor: Color = Color.clear
    var textColor: Color = .white
    var loading: Bool = false
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 10) {
                if loading {
                    ProgressView().tint(textColor)
                } else if let icon {
                    Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                }
                Text(title).font(PType.bodyBold(15))
            }
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(disabled ? AnyShapeStyle(Color(hex: 0xB5C4AC)) : AnyShapeStyle(color))
            )
        }
        .buttonStyle(PressableStyle())
        .disabled(disabled || loading)
    }
}

struct PandaButton: View {
    let title: String
    var icon: String? = nil
    var loading: Bool = false
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        DuoButton(title: title, icon: icon, loading: loading, disabled: disabled, action: action)
    }
}

struct GhostButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void
    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                }
                Text(title).font(PType.bodyBold(14))
            }
            .foregroundColor(Theme.deepGreen)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                Capsule().fill(Theme.surfaceLight)
            )
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Background

struct AuroraBackground: View {
    var body: some View {
        Theme.background.ignoresSafeArea()
    }
}

// MARK: - Hero card oscuro (real estate style)

struct MetallicHeroCard<Content: View>: View {
    var cornerRadius: CGFloat = 32
    var gradient: LinearGradient = Theme.heroPrimary
    var borderColor: Color = .clear
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(gradient)
            )
    }
}

// MARK: - Layered header vacío (para no tocar código existente)

struct LayeredHeader<HeaderContent: View>: View {
    var height: CGFloat = 200
    @ViewBuilder var content: () -> HeaderContent

    var body: some View {
        ZStack(alignment: .top) {
            Theme.background
                .clipShape(BottomRoundedShape(radius: 24))
                .ignoresSafeArea(edges: .top)
            content()
                .padding(.horizontal, 20)
                .padding(.top, 12)
        }
        .frame(height: height)
    }
}

struct BottomRoundedShape: Shape {
    var radius: CGFloat = 24
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - radius))
        path.addQuadCurve(to: CGPoint(x: rect.width - radius, y: rect.height),
                          control: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: radius, y: rect.height))
        path.addQuadCurve(to: CGPoint(x: 0, y: rect.height - radius),
                          control: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

// MARK: - Sparkle

struct Sparkle: View {
    @State private var scale: CGFloat = 0.6
    @State private var opacity: Double = 0.9
    let color: Color
    let size: CGFloat

    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: size, weight: .black))
            .foregroundStyle(color)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.9)) {
                    scale = 1.4
                    opacity = 0
                }
            }
    }
}
