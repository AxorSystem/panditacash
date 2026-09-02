import SwiftUI

struct PrestamoSearchResult: Identifiable {
    let id: Int
    let clienteNombre: String
    let clienteId: Int
    let principal: Double
    let estado: String
    let saldoPendiente: Double
}

@MainActor
final class BusquedaVM: ObservableObject {
    @Published var query = ""
    @Published var resultadosClientes: [ClienteList] = []
    @Published var resultadosPrestamos: [PrestamoSearchResult] = []
    @Published var searching = false
    private var task: Task<Void, Never>?

    var all: [ClienteList] = []
    var allPrestamos: [PrestamoSearchResult] = []

    func loadAll() async {
        all = (try? await APIClient.shared.get("clientes")) ?? []
        // Todos los préstamos: recorre cada cliente y arma resultados desde /clientes/:id
        allPrestamos = await cargarPrestamosDesde(all)
        aplicarFiltro()
    }

    private func cargarPrestamosDesde(_ clientes: [ClienteList]) async -> [PrestamoSearchResult] {
        await withTaskGroup(of: [PrestamoSearchResult].self) { group in
            for c in clientes {
                group.addTask {
                    guard let d: ClienteDetalleResp = try? await APIClient.shared.get("clientes/\(c.id)") else { return [] }
                    return d.prestamos.map { p in
                        PrestamoSearchResult(
                            id: p.id, clienteNombre: d.cliente.nombre, clienteId: d.cliente.id,
                            principal: p.principal, estado: p.estado,
                            saldoPendiente: p.saldoPendiente ?? 0
                        )
                    }
                }
            }
            var out: [PrestamoSearchResult] = []
            for await res in group { out.append(contentsOf: res) }
            return out
        }
    }

    func onQueryChange() {
        task?.cancel()
        task = Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            if Task.isCancelled { return }
            await MainActor.run { aplicarFiltro() }
        }
    }

    private func aplicarFiltro() {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty { resultadosClientes = all; resultadosPrestamos = []; return }
        resultadosClientes = all.filter {
            $0.nombre.lowercased().contains(q) || $0.telefono.contains(q)
        }
        // Préstamos: buscar por id exacto (#123 o 123) o por monto (>= 500 y contiene q)
        let numeric = q.filter { $0.isNumber || $0 == "." }
        if let n = Double(numeric), n > 0 {
            resultadosPrestamos = allPrestamos.filter {
                $0.id == Int(n) || abs($0.principal - n) < 0.01 || String($0.principal).contains(numeric)
            }
        } else {
            resultadosPrestamos = allPrestamos.filter { $0.estado.lowercased().contains(q) }
        }
    }
}

struct BusquedaGlobalView: View {
    @StateObject var vm = BusquedaVM()
    @Environment(\.dismiss) var dismiss
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                VStack(spacing: 12) {
                    searchField
                    contenido
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            .navigationTitle("Buscar cliente")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                        .foregroundColor(Theme.deepGreen)
                }
            }
            .task {
                await vm.loadAll()
                focused = true
            }
        }
    }

    var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.inkMuted)
            TextField("Nombre o teléfono", text: $vm.query)
                .font(PType.body(15))
                .focused($focused)
                .autocorrectionDisabled()
                .onChange(of: vm.query) { _, _ in vm.onQueryChange() }
            if !vm.query.isEmpty {
                Button {
                    vm.query = ""
                    vm.onQueryChange()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.inkMuted)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Capsule().fill(Theme.surfaceLight))
    }

    @ViewBuilder
    var contenido: some View {
        let sinResultados = vm.resultadosClientes.isEmpty && vm.resultadosPrestamos.isEmpty && !vm.query.isEmpty
        if sinResultados {
            VStack(spacing: 10) {
                Image(systemName: "magnifyingglass").font(.system(size: 36)).foregroundColor(Theme.inkMuted)
                Text("Sin coincidencias").font(PType.heading(15)).foregroundColor(Theme.inkSoft)
                Text("Prueba con nombre, teléfono, #préstamo o monto")
                    .font(PType.caption(11)).foregroundColor(Theme.inkMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
            Spacer()
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    if !vm.resultadosPrestamos.isEmpty {
                        sectionHeader("Préstamos (\(vm.resultadosPrestamos.count))")
                        ForEach(vm.resultadosPrestamos) { p in
                            NavigationLink {
                                PrestamoDetalleView(prestamoId: p.id)
                            } label: {
                                prestamoRow(p)
                            }
                            .buttonStyle(PressableStyle(scale: 0.98))
                        }
                    }
                    if !vm.resultadosClientes.isEmpty {
                        sectionHeader("Clientes (\(vm.resultadosClientes.count))")
                        ForEach(vm.resultadosClientes) { c in
                            NavigationLink {
                                ClienteDetalleView(clienteId: c.id, nombre: c.nombre)
                            } label: {
                                ClienteRow(cliente: c)
                            }
                            .buttonStyle(PressableStyle(scale: 0.98))
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }

    private func sectionHeader(_ t: String) -> some View {
        Text(t.uppercased())
            .tracking(1.2)
            .font(PType.caption(10))
            .foregroundColor(Theme.deepGreen)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
    }

    private func prestamoRow(_ p: PrestamoSearchResult) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Theme.softPrimary).frame(width: 40, height: 40)
                Image(systemName: "banknote.fill").foregroundColor(Theme.deepGreen).font(.system(size: 14, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("#\(p.id) · \(p.clienteNombre)").font(PType.bodyBold(14)).foregroundColor(Theme.ink)
                Text("\(MoneyFormat.mxn(p.principal)) · \(p.estado)")
                    .font(PType.caption(11)).foregroundColor(Theme.inkSoft)
            }
            Spacer()
            if p.saldoPendiente > 0 {
                Text(MoneyFormat.mxn(p.saldoPendiente))
                    .font(PType.number(13)).foregroundColor(Theme.ink)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surfaceLight))
    }
}
