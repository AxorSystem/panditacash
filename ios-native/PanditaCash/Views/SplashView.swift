import SwiftUI

struct SplashView: View {
    @State private var scale: CGFloat = 0.85
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Theme.heroPrimary)
                        .frame(width: 120, height: 120)
                    Text("🐼").font(.system(size: 64))
                }
                .scaleEffect(scale)
                Text("PanditaCash")
                    .font(PType.title(28))
                    .foregroundColor(Theme.ink)
                    .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) {
                scale = 1
                opacity = 1
            }
        }
    }
}
