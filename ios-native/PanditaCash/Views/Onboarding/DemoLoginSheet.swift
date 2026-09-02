import SwiftUI

/// Sheet de acceso rápido para demos — login con 1 tap usando credentials pre-configuradas.
struct DemoLoginSheet: View {
    @EnvironmentObject var auth: AuthStore
    @EnvironmentObject var toast: ToastCenter
    @Environment(\.dismiss) var dismiss
    @State private var loading: String?

    struct DemoUser: Identifiable {
        let id: String
        let emoji: String
        let nombre: String
        let telefono: String
        let pin: String?          // Solo mamá tiene PIN
        let esCliente: Bool
        let descripcion: String
    }

    let demoUsers: [DemoUser] = [
        .init(id: "mama", emoji: "👑", nombre: "Mamá Panda",
              telefono: "5215500000000", pin: "1234", esCliente: false,
              descripcion: "Administrador (login PIN 1234)"),
        .init(id: "abdo", emoji: "👤", nombre: "abdo",
              telefono: "527341682051", pin: nil, esCliente: true,
              descripcion: "Cliente con préstamos activos"),
        .init(id: "test", emoji: "🧪", nombre: "Cliente Test Score",
              telefono: "525599887766", pin: nil, esCliente: true,
              descripcion: "Cliente sin préstamos"),
    ]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 20) {
                header
                usersList
                Spacer()
                Text("Modo demo — solo para pruebas")
                    .font(PType.caption(11)).foregroundColor(Theme.inkMuted)
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.background)
    }

    var header: some View {
        VStack(spacing: 6) {
            Text("🚀").font(.system(size: 40))
            Text("Acceso rápido").font(PType.title(22)).foregroundColor(Theme.ink)
            Text("Elige con quién quieres entrar")
                .font(PType.body(13)).foregroundColor(Theme.inkSoft)
        }
    }

    var usersList: some View {
        VStack(spacing: 10) {
            ForEach(demoUsers) { u in
                Button {
                    Task { await login(u) }
                } label: {
                    HStack(spacing: 14) {
                        Text(u.emoji).font(.system(size: 32))
                            .frame(width: 52, height: 52)
                            .background(Circle().fill(Theme.softPrimary))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(u.nombre).font(PType.bodyBold(15)).foregroundColor(Theme.ink)
                            Text(u.descripcion).font(PType.caption(12)).foregroundColor(Theme.inkSoft)
                        }
                        Spacer()
                        if loading == u.id {
                            ProgressView().tint(Theme.deepGreen)
                        } else {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 22)).foregroundColor(Theme.deepGreen)
                        }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
                    .shadow(color: Theme.deepGreen.opacity(0.08), radius: 12, y: 4)
                }
                .buttonStyle(PressableStyle(scale: 0.97))
                .disabled(loading != nil)
                .accessibilityIdentifier("demo_login_\(u.id)")
            }
        }
    }

    func login(_ u: DemoUser) async {
        loading = u.id
        defer { loading = nil }
        do {
            if let pin = u.pin {
                // Login mamá con PIN real
                try await auth.mamaLogin(telefono: u.telefono, pin: pin)
                Haptics.success()
                toast.show("Bienvenida \(u.nombre)", kind: .success)
                dismiss()
            } else {
                // Cliente: request OTP + auto-verify si es cliente demo (skip validación real)
                try await auth.requestOtp(telefono: u.telefono, nombre: nil)
                Haptics.soft()
                toast.show("Código enviado por WhatsApp a \(u.telefono)", kind: .info)
                dismiss()
            }
        } catch {
            Haptics.error()
            toast.show((error as? APIError)?.errorDescription ?? "Error", kind: .error)
        }
    }
}
