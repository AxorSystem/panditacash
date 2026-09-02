import SwiftUI

@main
struct PanditaCashApp: App {
    @StateObject private var auth = AuthStore()
    @StateObject private var toast = ToastCenter()

    init() {
        Theme.applyGlobalAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(toast)
                // Sigue el modo del sistema (light/dark)
                .task { await auth.restore() }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var auth: AuthStore

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            switch auth.state {
            case .booting:
                SplashView()
                    .transition(.opacity)
            case .signedOut:
                OnboardingLoginFlow()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)))
            case .signedIn(let user):
                if user.esAdmin {
                    MamaRootView()
                        .transition(.opacity.combined(with: .scale(scale: 1.02)))
                } else {
                    ClienteRootView()
                        .transition(.opacity.combined(with: .scale(scale: 1.02)))
                }
            }
        }
        .animation(.smooth(duration: 0.5), value: auth.state)
        .overlay(alignment: .top) { ToastOverlay() }
    }
}
