import SwiftUI

/// Overlay animado full-screen que muestra checkmark + confetti al terminar acciones exitosas.
struct SuccessCelebration: View {
    let title: String
    let subtitle: String?
    var duration: Double = 2.0
    let onFinish: () -> Void

    @State private var showCheck = false
    @State private var showText = false
    @State private var showConfetti = false
    @State private var ringScale: CGFloat = 0.2
    @State private var ringOpacity: Double = 1

    var body: some View {
        ZStack {
            // Fondo blur con verde
            Theme.deepGreen.opacity(0.96)
                .ignoresSafeArea()
                .transition(.opacity)

            // Rings expanding
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    .frame(width: 200, height: 200)
                    .scaleEffect(ringScale + CGFloat(i) * 0.5)
                    .opacity(ringOpacity - Double(i) * 0.3)
            }

            // Confetti
            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            VStack(spacing: 22) {
                Spacer()

                // Circle con checkmark
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 140, height: 140)
                        .shadow(color: Color.black.opacity(0.25), radius: 25, y: 12)

                    Image(systemName: "checkmark")
                        .font(.system(size: 68, weight: .bold))
                        .foregroundColor(Theme.deepGreen)
                        .scaleEffect(showCheck ? 1.0 : 0.2)
                        .opacity(showCheck ? 1 : 0)
                }
                .scaleEffect(showCheck ? 1.0 : 0.5)
                .opacity(showCheck ? 1 : 0)

                VStack(spacing: 8) {
                    Text(title)
                        .font(PType.title(30))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    if let sub = subtitle {
                        Text(sub)
                            .font(PType.body(15))
                            .foregroundColor(.white.opacity(0.82))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }
                .opacity(showText ? 1 : 0)
                .offset(y: showText ? 0 : 20)

                Spacer()
                Spacer()
            }
        }
        .onAppear { animate() }
    }

    func animate() {
        Haptics.success()

        withAnimation(.spring(response: 0.6, dampingFraction: 0.55)) {
            showCheck = true
        }
        withAnimation(.easeOut(duration: 1.5)) {
            ringScale = 3.5
            ringOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                showText = true
            }
            withAnimation(.easeIn(duration: 0.3)) {
                showConfetti = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            withAnimation(.easeOut(duration: 0.4)) {
                onFinish()
            }
        }
    }
}

// MARK: - Confetti particles

struct ConfettiView: View {
    private let colors: [Color] = [
        Color(hex: 0xFFD166), // amarillo
        Color(hex: 0xEF476F), // rosa
        Color(hex: 0x06D6A0), // menta
        Color(hex: 0x118AB2), // azul
        Color(hex: 0xFF9E00), // naranja
        Color.white,
    ]

    var body: some View {
        GeometryReader { geo in
            ForEach(0..<70, id: \.self) { i in
                ConfettiPiece(
                    color: colors[i % colors.count],
                    startX: CGFloat.random(in: 0...geo.size.width),
                    endX: CGFloat.random(in: 0...geo.size.width),
                    startY: -50,
                    endY: geo.size.height + 100,
                    duration: Double.random(in: 1.8...3.5),
                    delay: Double.random(in: 0...0.9),
                    rotation: Double.random(in: 0...720),
                    scale: CGFloat.random(in: 0.6...1.4)
                )
            }
        }
    }
}

struct ConfettiPiece: View {
    let color: Color
    let startX: CGFloat
    let endX: CGFloat
    let startY: CGFloat
    let endY: CGFloat
    let duration: Double
    let delay: Double
    let rotation: Double
    let scale: CGFloat

    @State private var animated = false

    var body: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(color)
            .frame(width: 10, height: 14)
            .scaleEffect(scale)
            .position(x: animated ? endX : startX, y: animated ? endY : startY)
            .rotationEffect(.degrees(animated ? rotation : 0))
            .opacity(animated ? 0 : 1)
            .onAppear {
                withAnimation(.easeIn(duration: duration).delay(delay)) {
                    animated = true
                }
            }
    }
}
