import SwiftUI

struct EditarNotasPrestamoSheet: View {
    let prestamoId: Int
    let notasIniciales: String
    let onSaved: () -> Void
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var toast: ToastCenter
    @State private var draft: String
    @State private var saving = false

    init(prestamoId: Int, notasIniciales: String, onSaved: @escaping () -> Void) {
        self.prestamoId = prestamoId
        self.notasIniciales = notasIniciales
        self.onSaved = onSaved
        _draft = State(initialValue: notasIniciales)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notas del préstamo").font(PType.title(22)).foregroundColor(Theme.ink)
                    Text("Solo tú ves estas notas").font(PType.body(13)).foregroundColor(Theme.inkSoft)
                }
                TextEditor(text: $draft)
                    .font(PType.body(15))
                    .foregroundColor(Theme.ink)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surfaceLight))
                    .frame(minHeight: 200)
                Spacer()
                DuoButton(title: "Guardar notas", icon: "checkmark", loading: saving) {
                    Task { await guardar() }
                }
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 20).padding(.top, 12)
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Theme.background)
        .presentationDragIndicator(.visible)
    }

    struct NotasBody: Encodable { let notas: String }

    func guardar() async {
        saving = true; defer { saving = false }
        do {
            struct R: Decodable {}
            let _: R = try await APIClient.shared.patch("prestamos/\(prestamoId)", body: NotasBody(notas: draft))
            Haptics.success()
            toast.show("Notas guardadas", kind: .success)
            onSaved()
            dismiss()
        } catch {
            Haptics.error()
            toast.show((error as? APIError)?.errorDescription ?? "Error", kind: .error)
        }
    }
}
