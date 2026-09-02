import SwiftUI

struct OnboardingLoginFlow: View {
    @State private var showLogin = false
    @State private var loginMode: LoginMode = .cliente

    var body: some View {
        ZStack {
            if showLogin {
                LoginView(mode: $loginMode) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { showLogin = false }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                OnboardingView { mode in
                    loginMode = mode
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { showLogin = true }
                }
                .transition(.opacity)
            }
        }
    }
}

enum LoginMode: String, Hashable { case mama, cliente }

struct OnboardingView: View {
    let onPickMode: (LoginMode) -> Void
    @State private var page = 0
    @State private var showDemo = false
    @State private var showSimulador = false
    private let pages: [OnboardPage] = [
        .init(title: "PanditaCash", subtitle: "Tu prestamista de confianza, ahora en tu bolsillo", accent: "Reimaginado"),
        .init(title: "Sin fricción", subtitle: "Sin filas, sin papeleos, sin drama", accent: "Rápido"),
        .init(title: "100% seguro", subtitle: "Solo tú y mamá. Nada de terceros", accent: "Privado"),
    ]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            content
        }
        .sheet(isPresented: $showDemo) {
            DemoLoginSheet()
        }
        .sheet(isPresented: $showSimulador) {
            SimuladorPublicoView()
        }
    }

    var content: some View {
        VStack {
            Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .fill(Theme.heroPrimary)
                        .frame(width: 220, height: 220)
                    Text("🐼").font(.system(size: 130))
                }

                Spacer(minLength: 30)

                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { i, p in
                        VStack(spacing: 10) {
                            Text(p.accent.uppercased())
                                .font(PType.caption(11))
                                .tracking(2)
                                .foregroundColor(Theme.deepGreen)
                            Text(p.title)
                                .font(PType.title(34))
                                .foregroundColor(Theme.ink)
                                .multilineTextAlignment(.center)
                            Text(p.subtitle)
                                .font(PType.body(15))
                                .foregroundColor(Theme.inkSoft)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 140)

                HStack(spacing: 6) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Capsule()
                            .fill(page == i ? Theme.deepGreen : Theme.hairline)
                            .frame(width: page == i ? 24 : 6, height: 6)
                            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: page)
                    }
                }
                .padding(.vertical, 16)

                VStack(spacing: 10) {
                    DuoButton(title: "Empezar como Cliente", icon: "arrow.right") {
                        onPickMode(.cliente)
                    }
                    Button {
                        Haptics.tap()
                        onPickMode(.mama)
                    } label: {
                        Text("Soy Mamá / Admin")
                            .font(PType.bodyBold(15))
                            .foregroundColor(Theme.inkSoft)
                            .padding(.vertical, 14)
                    }
                    Button {
                        Haptics.tap(); showSimulador = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chart.pie.fill").font(.system(size: 12))
                            Text("Simular un préstamo").font(PType.caption(13))
                        }
                        .foregroundColor(Theme.deepGreen)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Capsule().stroke(Theme.deepGreen, lineWidth: 1.5))
                    }
                    // Botón demo — solo visible en debug/testing
                    Button {
                        Haptics.tap(); showDemo = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.fill").font(.system(size: 12))
                            Text("Acceso rápido demo").font(PType.caption(12))
                        }
                        .foregroundColor(Theme.deepGreen)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(Theme.softPrimary))
                    }
                    .accessibilityIdentifier("demo_login_button")
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
        }
    }
}

struct OnboardPage { let title, subtitle, accent: String }
