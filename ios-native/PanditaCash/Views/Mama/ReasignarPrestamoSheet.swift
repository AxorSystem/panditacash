import SwiftUI

@MainActor
final class ReasignarVM: ObservableObject {
    @Published var clientes: [ClienteList] = []
    @Published var query = ""
    @Published var submitting = false

    func load() async {
        clientes = (try? await APIClient.shared.get("clientes")) ?? []
    }

    var filtered: [ClienteList] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty { return clientes }
        return clientes.filter { $0.nombre.lowercased().contains(q) || $0.telefono.contains(q) }
    }

    struct Body: Encodable { let usuario_id: Int }

    func reasignar(prestamoId: Int, aClienteId: Int) async throws {
        submitting = true; defer { submitting = false }
        struct R: Decodable { let ok: Bool }
        let _: R = try await APIClient.shared.patch("prestamos/\(prestamoId)/reasignar", body: Body(usuario_id: aClienteId))
        AppEvent.post(AppEvent.prestamosChanged)
        AppEvent.post(AppEvent.clientesChanged)
    }
}

struct ReasignarPrestamoSheet: View {
    let prestamoId: Int
    let clienteActual: String
    let onDone: () -> Void
    @StateObject var vm = ReasignarVM()
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var toast: ToastCenter
    @State private var confirmSel: ClienteList?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 12) {
                    banner
                    searchField
                    if vm.filtered.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "person.slash").font(.system(size: 32)).foregroundColor(Theme.inkMuted)
                            Text("Sin coincidencias").font(PType.body(13)).foregroundColor(Theme.inkSoft)
                        }
                        .frame(maxWidth: .infinity).padding(.top, 40)
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 8) {
                                ForEach(vm.filtered) { c in
                                    row(c)
                                }
                            }
                            .padding(.bottom, 40)
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.top, 8)
            }
            .navigationTitle("Reasignar préstamo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }.foregroundColor(Theme.deepGreen)
                }
            }
            .task { await vm.load() }
            .alert("¿Reasignar?", isPresented: Binding(get: { confirmSel != nil }, set: { if !$0 { confirmSel = nil } })) {
                Button("Cancelar", role: .cancel) {}
                Button("Reasignar", role: .destructive) {
                    if let c = confirmSel { Task { await hacerlo(c) } }
                }
            } message: {
                Text("El préstamo se moverá de \(clienteActual) a \(confirmSel?.nombre ?? ""). Los pagos y movimientos también.")
            }
        }
    }

    var banner: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.right.arrow.left").foregroundColor(Theme.deepGreen).font(.system(size: 15, weight: .semibold))
            Text("Actualmente asignado a **\(clienteActual)**").font(PType.body(13)).foregroundColor(Theme.ink)
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.softPrimary))
    }

    var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundColor(Theme.inkMuted).font(.system(size: 14))
            TextField("Buscar cliente…", text: $vm.query)
                .font(PType.body(14))
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Capsule().fill(Theme.surfaceLight))
    }

    func row(_ c: ClienteList) -> some View {
        Button {
            Haptics.tap(); confirmSel = c
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Theme.softPrimary).frame(width: 40, height: 40)
                    Text(String(c.nombre.prefix(1).uppercased()))
                        .font(PType.bodyBold(15)).foregroundColor(Theme.deepGreen)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(c.nombre).font(PType.bodyBold(14)).foregroundColor(Theme.ink)
                    Text(c.telefono).font(PType.caption(11)).foregroundColor(Theme.inkSoft)
                }
                Spacer()
                Image(systemName: "arrow.right").font(.system(size: 12, weight: .bold)).foregroundColor(Theme.deepGreen)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18).fill(Theme.surfaceLight))
        }
        .buttonStyle(PressableStyle(scale: 0.98))
    }

    func hacerlo(_ c: ClienteList) async {
        do {
            try await vm.reasignar(prestamoId: prestamoId, aClienteId: c.id)
            Haptics.success()
            toast.show("Reasignado a \(c.nombre)", kind: .success)
            onDone()
            dismiss()
        } catch {
            Haptics.error()
            toast.show((error as? APIError)?.errorDescription ?? "Error", kind: .error)
        }
    }
}
