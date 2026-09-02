import SwiftUI

struct EditarNotasClienteSheet: View {
    let clienteId: Int
    let nombre: String
    @Binding var notas: String
    var telefonoActual: String = ""
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var toast: ToastCenter
    @State private var saving = false
    @State private var draftNotas: String
    @State private var draftNombre: String
    @State private var draftTelefono: String

    init(clienteId: Int, nombre: String, notas: Binding<String>, telefono: String = "") {
        self.clienteId = clienteId
        self.nombre = nombre
        self._notas = notas
        self.telefonoActual = telefono
        self._draftNotas = State(initialValue: notas.wrappedValue)
        self._draftNombre = State(initialValue: nombre)
        self._draftTelefono = State(initialValue: telefono)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    nombreField
                    telefonoField
                    notasEditor
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 100)
            }
            VStack {
                Spacer()
                DuoButton(title: "Guardar cambios", icon: "checkmark", loading: saving) {
                    Task { await guardar() }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                .background(Theme.background.opacity(0.95))
            }
        }
        .presentationDetents([.large])
        .presentationBackground(Theme.background)
        .presentationDragIndicator(.visible)
    }

    var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Editar cliente").font(PType.title(22)).foregroundColor(Theme.ink)
            Text("Actualiza los datos de \(nombre)")
                .font(PType.body(13)).foregroundColor(Theme.inkSoft)
        }
    }

    var nombreField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Nombre").font(PType.caption(12)).foregroundColor(Theme.inkSoft)
            HStack {
                Image(systemName: "person.fill").foregroundColor(Theme.inkMuted).font(.system(size: 14))
                TextField("Nombre completo", text: $draftNombre)
                    .font(PType.body(15))
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surfaceLight))
        }
    }

    var telefonoField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Teléfono").font(PType.caption(12)).foregroundColor(Theme.inkSoft)
            HStack {
                Image(systemName: "phone.fill").foregroundColor(Theme.inkMuted).font(.system(size: 14))
                TextField("10 dígitos", text: $draftTelefono)
                    .font(PType.body(15))
                    .keyboardType(.phonePad)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surfaceLight))
        }
    }

    var notasEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Notas privadas").font(PType.caption(12)).foregroundColor(Theme.inkSoft)
            TextEditor(text: $draftNotas)
                .font(PType.body(15))
                .foregroundColor(Theme.ink)
                .scrollContentBackground(.hidden)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surfaceLight))
                .frame(minHeight: 180)
        }
    }

    struct PatchBody: Encodable { let nombre: String?; let telefono: String?; let notas: String? }

    func guardar() async {
        saving = true; defer { saving = false }
        do {
            let body = PatchBody(
                nombre: draftNombre == nombre ? nil : draftNombre,
                telefono: draftTelefono == telefonoActual ? nil : draftTelefono,
                notas: draftNotas
            )
            struct R: Decodable {}
            let _: R = try await APIClient.shared.patch("clientes/\(clienteId)", body: body)
            notas = draftNotas
            Haptics.success()
            toast.show("Cambios guardados", kind: .success)
            AppEvent.post(AppEvent.clientesChanged)
            dismiss()
        } catch {
            Haptics.error()
            toast.show((error as? APIError)?.errorDescription ?? "Error", kind: .error)
        }
    }
}
