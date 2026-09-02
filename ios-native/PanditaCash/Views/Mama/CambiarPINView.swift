import SwiftUI

@MainActor
final class CambiarPINVM: ObservableObject {
    @Published var pinActual = ""
    @Published var pinNuevo = ""
    @Published var pinConfirm = ""
    @Published var loading = false

    var canSubmit: Bool {
        pinActual.count >= 4 && pinNuevo.count >= 4 && pinNuevo == pinConfirm
    }

    struct Body: Encodable { let pin_actual: String; let pin_nuevo: String }

    func cambiar() async throws {
        loading = true; defer { loading = false }
        let body = Body(pin_actual: pinActual, pin_nuevo: pinNuevo)
        struct R: Decodable { let ok: Bool? }
        let _: R = try await APIClient.shared.post("auth/mama/change-pin", body: body)
    }
}

struct CambiarPINView: View {
    @StateObject var vm = CambiarPINVM()
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var toast: ToastCenter
    @FocusState private var focus: Field?

    enum Field { case actual, nuevo, confirm }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    header
                    formCard
                    Spacer()
                    DuoButton(title: "Cambiar PIN", icon: "arrow.right",
                              loading: vm.loading, disabled: !vm.canSubmit) {
                        Task {
                            do {
                                try await vm.cambiar()
                                Haptics.success()
                                toast.show("PIN actualizado", kind: .success)
                                dismiss()
                            } catch {
                                Haptics.error()
                                toast.show((error as? APIError)?.errorDescription ?? "Error", kind: .error)
                            }
                        }
                    }
                    .padding(.bottom, 12)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
        .navigationTitle("Cambiar PIN")
        .navigationBarTitleDisplayMode(.inline)
    }

    var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(Theme.softPrimary).frame(width: 90, height: 90)
                Image(systemName: "lock.rotation").font(.system(size: 42)).foregroundColor(Theme.deepGreen)
            }
            Text("Nuevo PIN").font(PType.title(24)).foregroundColor(Theme.ink)
            Text("Mínimo 4 dígitos. No lo compartas.")
                .font(PType.body(13)).foregroundColor(Theme.inkSoft)
        }
    }

    var formCard: some View {
        VStack(spacing: 12) {
            InputField(icon: "lock.fill", placeholder: "PIN actual", text: $vm.pinActual, keyboard: .numberPad, secure: true)
                .focused($focus, equals: .actual)
            InputField(icon: "lock.badge.plus", placeholder: "PIN nuevo (mín 4)", text: $vm.pinNuevo, keyboard: .numberPad, secure: true)
                .focused($focus, equals: .nuevo)
            InputField(icon: "checkmark.circle", placeholder: "Confirma PIN nuevo", text: $vm.pinConfirm, keyboard: .numberPad, secure: true)
                .focused($focus, equals: .confirm)
            if !vm.pinConfirm.isEmpty && vm.pinConfirm != vm.pinNuevo {
                Text("Los PIN no coinciden")
                    .font(PType.caption(12)).foregroundColor(Theme.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
