import SwiftUI
import UIKit

struct LoginView: View {
    @Binding var mode: LoginMode
    let onClose: () -> Void
    @EnvironmentObject var auth: AuthStore
    @EnvironmentObject var toast: ToastCenter

    @State private var telefono = ""
    @State private var pin = ""
    @State private var otp = ""
    @State private var nombre = ""
    @State private var loading = false
    @State private var otpRequested = false
    @State private var showResetPIN = false
    @FocusState private var focus: Field?

    enum Field { case tel, pin, otp, nombre }

    var body: some View {
        ZStack(alignment: .top) {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 14) {
                            ZStack {
                                Circle().fill(Theme.softPrimary).frame(width: 120, height: 120)
                                Text(mode == .mama ? "👑" : "💬").font(.system(size: 68))
                            }
                            VStack(spacing: 4) {
                                Text(mode == .mama ? "Modo Mamá" : "Modo Cliente")
                                    .font(PType.title(24)).foregroundColor(Theme.ink)
                                Text(mode == .mama ? "Ingresa con teléfono y PIN" : "Iniciar con código de WhatsApp")
                                    .font(PType.body(13)).foregroundColor(Theme.inkSoft)
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 20)

                        // Card blanco con toggle + form
                        VStack(spacing: 20) {
                            modeToggle
                            if mode == .mama {
                                mamaForm
                            } else {
                                clienteForm
                            }
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(Theme.surfaceLight)
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .onTapGesture { focus = nil }
    }

    var header: some View {
        HStack {
            Button {
                Haptics.tap()
                onClose()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.deepGreen)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Theme.surfaceLight))
            }
            .buttonStyle(PressableStyle())
            Spacer()
            Color.clear.frame(width: 42, height: 42)
        }
    }

    var modeToggle: some View {
        HStack(spacing: 4) {
            modeButton(.cliente, label: "Cliente", icon: "person.fill")
            modeButton(.mama, label: "Mamá", icon: "key.fill")
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.backgroundElevated)
        )
    }

    func modeButton(_ target: LoginMode, label: String, icon: String) -> some View {
        Button {
            Haptics.selection()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                mode = target
                otpRequested = false
                pin = ""; otp = ""
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                Text(label).font(PType.bodyBold(14))
            }
            .foregroundColor(mode == target ? .white : Theme.inkSoft)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(mode == target ? AnyShapeStyle(Theme.deepGreen) : AnyShapeStyle(Color.clear))
            )
        }
        .buttonStyle(PressableStyle(scale: 0.98))
    }

    // MARK: Mamá

    var mamaForm: some View {
        VStack(spacing: 14) {
            phoneField
            pinField
            DuoButton(title: "Entrar", icon: "arrow.right", loading: loading, disabled: !canSubmitMama) {
                Task { await doMamaLogin() }
            }
            Button {
                Haptics.tap(); showResetPIN = true
            } label: {
                Text("Olvidé mi PIN")
                    .font(PType.caption(13))
                    .foregroundColor(Theme.deepGreen)
                    .underline()
            }
        }
        .sheet(isPresented: $showResetPIN) {
            ResetPINSheet(telefonoInicial: telefono)
        }
    }

    var canSubmitMama: Bool {
        telefono.count >= 10 && pin.count >= 4
    }

    func doMamaLogin() async {
        focus = nil
        loading = true
        defer { loading = false }
        do {
            try await auth.mamaLogin(telefono: telefono, pin: pin)
            Haptics.success()
        } catch {
            Haptics.error()
            toast.show(errorText(error), kind: .error)
        }
    }

    // MARK: Cliente

    var clienteForm: some View {
        VStack(spacing: 14) {
            if !otpRequested {
                phoneField
                DuoButton(title: "Enviarme código", icon: "arrow.right", loading: loading, disabled: telefono.count < 10) {
                    Task { await doRequestOtp() }
                }
                GhostButton(title: "Abrir WhatsApp con mensaje", icon: "arrow.up.right.square") {
                    openWhatsAppPreload()
                }
            } else {
                otpField
                DuoButton(title: "Verificar código", icon: "checkmark", loading: loading, disabled: otp.count != 6) {
                    Task { await doVerifyOtp() }
                }
                Button {
                    Haptics.tap()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        otpRequested = false; otp = ""
                    }
                } label: {
                    Text("← Cambiar teléfono").font(PType.bodyBold(14)).foregroundColor(Theme.inkSoft)
                }
            }
        }
    }

    func doRequestOtp() async {
        focus = nil
        loading = true
        defer { loading = false }
        do {
            try await auth.requestOtp(telefono: telefono, nombre: nombre.isEmpty ? nil : nombre)
            Haptics.success()
            toast.show("Código enviado", kind: .success)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { otpRequested = true }
            focus = .otp
        } catch {
            Haptics.error()
            toast.show(errorText(error), kind: .error)
        }
    }

    func doVerifyOtp() async {
        focus = nil
        loading = true
        defer { loading = false }
        do {
            try await auth.verifyOtp(telefono: telefono, codigo: otp)
            Haptics.success()
        } catch {
            Haptics.error()
            toast.show(errorText(error), kind: .error)
        }
    }

    var phoneField: some View {
        InputField(icon: "phone.fill", placeholder: "Teléfono (10 dígitos)", text: $telefono, keyboard: .phonePad)
            .focused($focus, equals: .tel)
    }

    var pinField: some View {
        InputField(icon: "lock.fill", placeholder: "PIN", text: $pin, keyboard: .numberPad, secure: true)
            .focused($focus, equals: .pin)
    }

    var otpField: some View {
        OTPField(code: $otp)
            .focused($focus, equals: .otp)
    }

    func openWhatsAppPreload() {
        let tel = "525525034846"
        let normalized = telefono.filter(\.isNumber)
        let msg = "PANDITA-\(normalized)"
        let encoded = msg.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? msg
        if let url = URL(string: "https://wa.me/\(tel)?text=\(encoded)") {
            UIApplication.shared.open(url)
        }
    }

    func errorText(_ e: Error) -> String {
        if let api = e as? APIError { return api.errorDescription ?? "Error" }
        return e.localizedDescription
    }
}

struct InputField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var secure: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.deepGreen)
                .frame(width: 22)
            Group {
                if secure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(PType.bodyBold(15))
            .foregroundColor(Theme.ink)
            .keyboardType(keyboard)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.backgroundElevated)
        )
    }
}

struct OTPField: View {
    @Binding var code: String
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { i in
                    Text(digit(at: i))
                        .font(PType.number(24))
                        .foregroundColor(Theme.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Theme.backgroundElevated)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(focused && code.count == i ? Theme.deepGreen : Color.clear,
                                                lineWidth: 2)
                                )
                        )
                }
            }
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focused)
                .opacity(0.001)
                .onChange(of: code) { _, new in
                    if new.count > 6 { code = String(new.prefix(6)) }
                    code = code.filter(\.isNumber)
                }
        }
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
        .onAppear { focused = true }
    }

    func digit(at index: Int) -> String {
        guard index < code.count else { return " " }
        let i = code.index(code.startIndex, offsetBy: index)
        return String(code[i])
    }
}
