import SwiftUI

struct ResetPINSheet: View {
    let telefonoInicial: String
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var toast: ToastCenter
    @State private var step: Step = .telefono
    @State private var telefono = ""
    @State private var codigo = ""
    @State private var pinNuevo = ""
    @State private var pinConfirm = ""
    @State private var loading = false

    enum Step { case telefono, codigo, listo }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 20) {
                    header
                    Group {
                        switch step {
                        case .telefono: telefonoStep
                        case .codigo: codigoStep
                        case .listo: listoStep
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            .navigationTitle("Recuperar PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }.foregroundColor(Theme.deepGreen)
                }
            }
            .onAppear { if telefono.isEmpty { telefono = telefonoInicial } }
        }
    }

    var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(headerTitulo).font(PType.title(22)).foregroundColor(Theme.ink)
            Text(headerSubtitulo).font(PType.body(13)).foregroundColor(Theme.inkSoft)
        }
    }

    var headerTitulo: String {
        switch step {
        case .telefono: "¿Cuál es tu teléfono?"
        case .codigo: "Ingresa el código"
        case .listo: "PIN restablecido"
        }
    }
    var headerSubtitulo: String {
        switch step {
        case .telefono: "Te enviamos un código por WhatsApp"
        case .codigo: "Revisa tu WhatsApp y define tu nuevo PIN"
        case .listo: "Ya puedes iniciar sesión con tu nuevo PIN"
        }
    }

    var telefonoStep: some View {
        VStack(spacing: 14) {
            InputField(icon: "phone.fill", placeholder: "Teléfono de mamá (10 dígitos)", text: $telefono, keyboard: .phonePad)
            DuoButton(title: "Enviar código", icon: "arrow.right", loading: loading, disabled: telefono.count < 10) {
                Task { await requestOTP() }
            }
        }
    }

    var codigoStep: some View {
        VStack(spacing: 14) {
            OTPField(code: $codigo)
            InputField(icon: "lock.badge.plus", placeholder: "PIN nuevo (mín 4)", text: $pinNuevo, keyboard: .numberPad, secure: true)
            InputField(icon: "checkmark.circle", placeholder: "Confirma PIN", text: $pinConfirm, keyboard: .numberPad, secure: true)
            DuoButton(title: "Restablecer PIN", icon: "checkmark", loading: loading, disabled: !canSubmit) {
                Task { await verifyReset() }
            }
        }
    }

    var listoStep: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Theme.softSuccess).frame(width: 96, height: 96)
                Image(systemName: "checkmark").font(.system(size: 38, weight: .bold)).foregroundColor(Theme.success)
            }
            .padding(.top, 40)
            DuoButton(title: "Iniciar sesión", icon: "arrow.right") { dismiss() }
        }
        .frame(maxWidth: .infinity)
    }

    var canSubmit: Bool {
        codigo.count >= 4 && pinNuevo.count >= 4 && pinNuevo == pinConfirm
    }

    struct RequestBody: Encodable { let telefono: String }
    struct VerifyBody: Encodable { let telefono: String; let codigo: String; let pin_nuevo: String }

    func requestOTP() async {
        loading = true; defer { loading = false }
        do {
            struct R: Decodable { let ok: Bool }
            let _: R = try await APIClient.shared.post("auth/mama/request-pin-reset", body: RequestBody(telefono: telefono))
            Haptics.success()
            toast.show("Código enviado por WhatsApp", kind: .success)
            withAnimation { step = .codigo }
        } catch {
            Haptics.error()
            toast.show((error as? APIError)?.errorDescription ?? "Error", kind: .error)
        }
    }

    func verifyReset() async {
        loading = true; defer { loading = false }
        do {
            struct R: Decodable { let ok: Bool }
            let _: R = try await APIClient.shared.post(
                "auth/mama/verify-pin-reset",
                body: VerifyBody(telefono: telefono, codigo: codigo, pin_nuevo: pinNuevo)
            )
            Haptics.success()
            withAnimation { step = .listo }
        } catch {
            Haptics.error()
            toast.show((error as? APIError)?.errorDescription ?? "Error", kind: .error)
        }
    }
}
