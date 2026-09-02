import SwiftUI

struct PerfilView: View {
    @EnvironmentObject var auth: AuthStore
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    // Card oscuro con avatar y datos
                    VStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .fill(Theme.heroPrimary)
                                .frame(width: 140, height: 140)
                            Text("🐼").font(.system(size: 76))
                        }
                        if case .signedIn(let u) = auth.state {
                            Text(u.nombre).font(PType.title(26)).foregroundColor(Theme.ink)
                            if let tel = u.telefono, !tel.isEmpty {
                                Text(tel).font(PType.body(14)).foregroundColor(Theme.inkSoft)
                            }
                            HStack(spacing: 6) {
                                Circle().fill(Theme.success).frame(width: 6, height: 6)
                                Text(u.esAdmin ? "Modo administrador" : "Cliente verificado")
                                    .font(PType.caption(12)).foregroundColor(Theme.deepGreen)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(Capsule().fill(Theme.softPrimary))
                        }
                    }
                    .padding(.top, 40)

                    VStack(spacing: 10) {
                        NavigationLink { MamaAnalyticsView() } label: {
                            opcionRowLabel(icon: "chart.line.uptrend.xyaxis", title: "Ganancias y análisis")
                        }
                        .buttonStyle(PressableStyle(scale: 0.98))
                        NavigationLink { ActividadRecienteView() } label: {
                            opcionRowLabel(icon: "clock.badge.checkmark.fill", title: "Actividad reciente")
                        }
                        .buttonStyle(PressableStyle(scale: 0.98))
                        NavigationLink { MamaKYCPendientesView() } label: {
                            opcionRowLabel(icon: "shield.checkered", title: "Validaciones KYC")
                        }
                        .buttonStyle(PressableStyle(scale: 0.98))
                        NavigationLink { CambiarPINView() } label: {
                            opcionRowLabel(icon: "lock.fill", title: "Cambiar PIN")
                        }
                        .buttonStyle(PressableStyle(scale: 0.98))
                        NavigationLink { NotificacionesView() } label: {
                            opcionRowLabel(icon: "bell.fill", title: "Notificaciones")
                        }
                        .buttonStyle(PressableStyle(scale: 0.98))
                        NavigationLink { AyudaSoporteView() } label: {
                            opcionRowLabel(icon: "questionmark.circle.fill", title: "Ayuda y soporte")
                        }
                        .buttonStyle(PressableStyle(scale: 0.98))
                        NavigationLink { TerminosPrivacidadView() } label: {
                            opcionRowLabel(icon: "doc.text.fill", title: "Términos y privacidad")
                        }
                        .buttonStyle(PressableStyle(scale: 0.98))
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 20)

                    DuoButton(title: "Cerrar sesión", icon: "arrow.right.from.line") {
                        auth.signOut()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    Spacer(minLength: 120)
                }
            }
        }
    }

    func opcionRow(icon: String, title: String) -> some View {
        Button { } label: {
            opcionRowLabel(icon: icon, title: title)
        }
        .buttonStyle(PressableStyle(scale: 0.98))
    }

    func opcionRowLabel(icon: String, title: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Theme.softPrimary).frame(width: 42, height: 42)
                Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.deepGreen)
            }
            Text(title).font(PType.bodyBold(15)).foregroundColor(Theme.ink)
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.inkMuted)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surfaceLight))
    }
}

struct PlaceholderScreen: View {
    let title: String
    let subtitle: String
    let icon: String
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle().fill(Theme.softPrimary).frame(width: 160, height: 160)
                    .scaleEffect(pulse ? 1.06 : 1.0)
                    .opacity(pulse ? 0.7 : 1.0)
                Image(systemName: icon)
                    .font(.system(size: 52, weight: .regular))
                    .foregroundColor(Theme.deepGreen)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { pulse.toggle() }
            }
            Text(title).font(PType.title(26)).foregroundColor(Theme.ink)
            Text(subtitle)
                .font(PType.body(14))
                .foregroundColor(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Text("Próximamente")
                .font(PType.caption(11))
                .foregroundColor(Theme.deepGreen)
                .tracking(1.5)
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(Capsule().fill(Theme.softPrimary))
            Spacer()
            Spacer()
        }
    }
}
